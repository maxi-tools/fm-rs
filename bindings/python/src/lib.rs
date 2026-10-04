//! Python bindings for fm-rs (Apple FoundationModels.framework).
//!
//! This module provides Python bindings for fm-rs, enabling on-device AI
//! via Apple Intelligence from Python.
//!
//! # Platform Requirements
//!
//! - macOS 26.0+, iOS 26.0+, iPadOS 26.0+, visionOS 26.0+, tvOS 26.0+, watchOS 26.0+
//! - Apple Intelligence must be enabled on the device
//! - Device must support Apple Intelligence
//!
//! # Example
//!
//! ```python
//! import fm
//!
//! model = fm.SystemLanguageModel()
//! session = fm.Session(model, instructions="You are helpful.")
//! response = session.respond("Hello!")
//! print(response.content)
//! ```

// `#[pyclass(from_py_object)]` expands to an impl that clones the wrapped
// value. On classes that derive `Copy` that trips `clippy::clone_on_copy`,
// which fails the `-D warnings` clippy lanes. The clone is emitted by the
// pyo3 macro, not written here, so an item-level `#[allow]` does not cover it.
// Fixed upstream in pyo3 0.29.3 (PyO3#6309); not backported to the 0.28.x
// line this crate depends on.
#![allow(clippy::clone_on_copy)]

mod context;
mod error;
mod model;
mod options;
mod response;
mod schema;
mod session;
mod tool;

use pyo3::prelude::*;

/// Python module for Apple FoundationModels.framework bindings.
#[pymodule]
fn fm(m: &Bound<'_, PyModule>) -> PyResult<()> {
    // Register exceptions
    error::register(m)?;

    // Register classes
    m.add_class::<options::Sampling>()?;
    m.add_class::<options::GenerationOptions>()?;
    m.add_class::<response::Response>()?;
    m.add_class::<response::SessionUsage>()?;
    m.add_class::<model::ModelAvailability>()?;
    m.add_class::<model::SystemLanguageModel>()?;
    m.add_class::<session::Session>()?;
    m.add_class::<session::Attachment>()?;
    m.add_class::<tool::ToolOutput>()?;
    m.add_class::<context::ContextLimit>()?;
    m.add_class::<context::ContextUsage>()?;
    m.add_class::<schema::Schema>()?;

    // Register functions
    m.add_function(wrap_pyfunction!(context::estimate_tokens, m)?)?;
    m.add_function(wrap_pyfunction!(context::context_usage_from_transcript, m)?)?;
    m.add_function(wrap_pyfunction!(context::transcript_to_text, m)?)?;
    m.add_function(wrap_pyfunction!(context::compact_transcript, m)?)?;

    // Register constants
    m.add("DEFAULT_CONTEXT_TOKENS", context::DEFAULT_CONTEXT_TOKENS)?;

    // Module version
    m.add("__version__", env!("CARGO_PKG_VERSION"))?;

    Ok(())
}
