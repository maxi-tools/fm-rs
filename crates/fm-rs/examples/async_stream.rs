//! Stream a response as an async `Stream` instead of a blocking callback.
//!
//! Run with:  cargo run --features async --example async_stream
use fm_rs::{GenerationOptions, Session, SystemLanguageModel};
use futures_util::StreamExt;

#[tokio::main]
async fn main() -> Result<(), fm_rs::Error> {
    let model = SystemLanguageModel::new()?;
    if !model.is_available() {
        println!("Foundation Models unavailable on this machine");
        return Ok(());
    }

    let session = Session::new(&model)?;
    let mut stream = session.into_response_stream(
        "Explain virtual memory paging.",
        &GenerationOptions::default(),
    );

    // Items are cumulative snapshots, so keep the last rather than concatenating.
    let mut snapshots = 0usize;
    let mut latest = String::new();
    while let Some(snapshot) = stream.next().await {
        latest = snapshot?;
        snapshots += 1;
    }
    println!("{latest}");
    println!(
        "\n[{snapshots} snapshots, {} chars]",
        latest.chars().count()
    );

    // The session comes back, so the next turn can reuse it.
    let session = stream.into_session().expect("stream finished");
    println!("[session recovered: {}]", !session.is_responding());
    Ok(())
}
