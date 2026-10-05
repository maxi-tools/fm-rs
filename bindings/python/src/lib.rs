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

// `clippy::clone_on_copy` is allowed crate-wide here, and only here.
//
// pyo3 0.28's `from_py_object` expands to a conversion that clones the source
// value. On a type that also derives `Copy`, clippy reports `clone_on_copy`
// against the expansion and maps the span back to the `#[pyclass(...)]`
// attribute, so its "remove the clone" help text points at a call we do not
// write and cannot edit. ModelAvailability, Sampling and SessionUsage are the
// three that trip it.
//
// Two narrower placements were tried on CI and do not work:
//   - `#[allow(clippy::clone_on_copy)]` on each affected type: the lint is
//     attributed to the expansion rather than to the annotated item, so the
//     allow never reaches it (fm-rs PR #2, run 37212318944).
//   - `[lints.clippy] clone_on_copy = "allow"` in this package's Cargo.toml:
//     cargo refuses the manifest outright -- "cannot override `workspace.lints`
//     in `lints`" -- because the package already says `lints.workspace = true`
//     (run 37212722436).
//
// So this inner attribute is the narrowest placement that actually compiles and
// suppresses. It is scoped to this crate's ten source files, all of them PyO3
// glue; the alternative that would also "work" is the workspace level in the
// root Cargo.toml, which would silence a genuine clone-on-copy in every crate
// in the workspace including the two that have no PyO3 in them at all.
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
