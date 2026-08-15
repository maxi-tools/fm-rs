//! Async bridge over the blocking streaming API.
//!
//! [`Session::stream_response`](crate::Session::stream_response) blocks the
//! calling thread for the whole generation and delivers chunks through a
//! callback. That is the wrong shape for async code, which wants to `.await`
//! chunks and interleave other work.
//!
//! [`ResponseStream`] runs the blocking call on its own thread and forwards
//! chunks through a channel, implementing [`futures_core::Stream`].
//!
//! # Why it takes the session by value
//!
//! [`Session`](crate::Session) is `Send` but **not** `Sync`, so it cannot be
//! shared with a worker thread behind an `Arc` — `Arc<Session>` is not `Send`
//! when `Session: !Sync`. Moving it is the only sound option. The session is
//! handed back when the stream completes, so multi-turn use is still possible:
//!
//! ```rust,no_run
//! # use fm_rs::{GenerationOptions, Session, SystemLanguageModel};
//! # use futures_util::StreamExt;
//! # async fn example() -> Result<(), fm_rs::Error> {
//! let model = SystemLanguageModel::new()?;
//! let session = Session::new(&model)?;
//!
//! let mut stream = session.into_response_stream("Explain paging.", &GenerationOptions::default());
//! let mut latest = String::new();
//! while let Some(snapshot) = stream.next().await {
//!     latest = snapshot?; // cumulative: each item is the whole response so far
//! }
//! println!("{latest}");
//! // Reuse the session for the next turn.
//! let session = stream.into_session().expect("stream finished");
//! # Ok(())
//! # }
//! ```

use std::pin::Pin;
use std::task::{Context, Poll};

use futures_core::Stream;
use tokio::sync::mpsc;

use crate::error::Result;
use crate::options::GenerationOptions;
use crate::session::Session;

/// An async stream of response chunks.
///
/// Each item is a **cumulative snapshot**, not a delta: Apple's
/// `streamResponse` yields `PartiallyGenerated` values whose `content` is the
/// whole response so far, and `fm_session_stream` forwards that verbatim. The
/// last `Ok` item is the complete response; concatenating them would produce
/// quadratic garbage. Diff successive snapshots if you need deltas.
///
/// Dropping the stream early closes the channel. The worker thread notices on
/// its next chunk and stops forwarding, but generation itself runs to
/// completion inside Swift: the framework offers no cancellation hook the
/// blocking call can observe. Expect the session to remain busy briefly after
/// an early drop.
pub struct ResponseStream {
    rx: mpsc::UnboundedReceiver<Result<String>>,
    /// Joined once the channel closes, yielding the session back.
    worker: Option<std::thread::JoinHandle<Session>>,
    session: Option<Session>,
}

impl ResponseStream {
    pub(crate) fn spawn(session: Session, prompt: &str, options: &GenerationOptions) -> Self {
        let (tx, rx) = mpsc::unbounded_channel();
        let prompt = prompt.to_owned();
        let options = options.clone();

        let worker = std::thread::spawn(move || {
            {
                let tx_chunk = tx.clone();
                // Borrowed, not moved: the relaxed bound on `stream_response`
                // means this closure does not need to be `'static`.
                let result = session.stream_response(&prompt, &options, |chunk| {
                    // A send failure means the consumer dropped the stream.
                    // Nothing to do but keep draining; Swift owns the loop.
                    let _ = tx_chunk.send(Ok(chunk.to_owned()));
                });
                if let Err(e) = result {
                    let _ = tx.send(Err(e));
                }
            }
            // Dropping `tx` here closes the channel, which is what tells the
            // consumer the stream ended.
            session
        });

        Self {
            rx,
            worker: Some(worker),
            session: None,
        }
    }

    /// Recovers the session once the stream has finished.
    ///
    /// Returns `None` while chunks may still arrive — drive the stream to
    /// completion first. A worker that panicked also yields `None`.
    pub fn into_session(mut self) -> Option<Session> {
        if let Some(session) = self.session.take() {
            return Some(session);
        }
        // Only join once the channel is closed, or this blocks the caller for
        // the rest of the generation.
        if !self.rx.is_closed() {
            return None;
        }
        self.worker.take()?.join().ok()
    }
}

impl Stream for ResponseStream {
    type Item = Result<String>;

    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        let poll = self.rx.poll_recv(cx);
        if matches!(poll, Poll::Ready(None)) {
            // Reap the worker so `into_session` is cheap and the thread does
            // not outlive the stream.
            if let Some(handle) = self.worker.take() {
                self.session = handle.join().ok();
            }
        }
        poll
    }
}

impl Session {
    /// Streams a response as an async [`Stream`] of chunk deltas.
    ///
    /// Takes the session by value because `Session` is `!Sync` and the blocking
    /// call has to run on another thread; [`ResponseStream::into_session`]
    /// hands it back when the stream completes.
    ///
    /// Requires the `async` feature.
    pub fn into_response_stream(self, prompt: &str, options: &GenerationOptions) -> ResponseStream {
        ResponseStream::spawn(self, prompt, options)
    }
}

/// Drives a stream to completion and returns the final response.
///
/// Keeps the last snapshot rather than concatenating: items are cumulative, so
/// the final one already contains everything.
///
/// Convenience for callers who want streaming's time-to-first-token but a whole
/// response at the end.
pub async fn collect_stream<S>(mut stream: S) -> Result<String>
where
    S: Stream<Item = Result<String>> + Unpin,
{
    use futures_util::StreamExt;

    let mut latest = String::new();
    while let Some(snapshot) = stream.next().await {
        latest = snapshot?;
    }
    Ok(latest)
}
