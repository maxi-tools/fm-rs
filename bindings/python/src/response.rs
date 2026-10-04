//! Python wrappers for Response and `SessionUsage`.

use pyo3::prelude::*;

use crate::error::to_py_err;

/// Exact token usage reported by Foundation Models 27.
#[pyclass(module = "fm", from_py_object)]
#[derive(Debug, Clone, Copy)]
pub struct SessionUsage {
    inner: fm_rs::SessionUsage,
}

#[pymethods]
impl SessionUsage {
    /// Total input tokens.
    #[getter]
    fn input_tokens(&self) -> u64 {
        self.inner.input_tokens
    }

    /// Input tokens served from the prompt cache.
    #[getter]
    fn cached_input_tokens(&self) -> u64 {
        self.inner.cached_input_tokens
    }

    /// Total output tokens.
    #[getter]
    fn output_tokens(&self) -> u64 {
        self.inner.output_tokens
    }

    /// Output tokens spent on extended reasoning.
    #[getter]
    fn reasoning_tokens(&self) -> u64 {
        self.inner.reasoning_tokens
    }

    /// Returns the usage consumed since an earlier snapshot of this session.
    ///
    /// Raises:
    ///     `ValueError`: If any counter went backwards (snapshots from
    ///         different sessions or taken out of order).
    fn delta_since(&self, earlier: &SessionUsage) -> PyResult<SessionUsage> {
        self.inner
            .delta_since(&earlier.inner)
            .map(|inner| Self { inner })
            .map_err(to_py_err)
    }

    fn __repr__(&self) -> String {
        format!(
            "SessionUsage(input_tokens={}, cached_input_tokens={}, output_tokens={}, reasoning_tokens={})",
            self.inner.input_tokens,
            self.inner.cached_input_tokens,
            self.inner.output_tokens,
            self.inner.reasoning_tokens
        )
    }
}

impl SessionUsage {
    /// Wraps an fm-rs `SessionUsage`.
    pub fn from_inner(inner: fm_rs::SessionUsage) -> Self {
        Self { inner }
    }
}

/// Response returned by the model.
#[pyclass(module = "fm", from_py_object)]
#[derive(Debug, Clone)]
pub struct Response {
    content: String,
    usage: Option<SessionUsage>,
}

#[pymethods]
impl Response {
    /// Gets the text content of the response.
    #[getter]
    fn content(&self) -> &str {
        &self.content
    }

    /// Exact token usage for this response (macOS/iOS 27+), or None.
    #[getter]
    fn usage(&self) -> Option<SessionUsage> {
        self.usage
    }

    fn __repr__(&self) -> String {
        let preview: String = self.content.chars().take(50).collect();
        let preview = if self.content.chars().count() > 50 {
            format!("{preview}...")
        } else {
            preview
        };
        format!("Response(content={preview:?})")
    }

    fn __str__(&self) -> &str {
        &self.content
    }

    fn __len__(&self) -> usize {
        self.content.chars().count()
    }
}

impl Response {
    /// Creates a new Response from an fm-rs Response.
    pub fn from_inner(inner: fm_rs::Response) -> Self {
        Self {
            usage: inner.usage().map(SessionUsage::from_inner),
            content: inner.into_content(),
        }
    }

    /// Creates a new Response from a string.
    pub fn from_string(content: String) -> Self {
        Self {
            content,
            usage: None,
        }
    }
}
