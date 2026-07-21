//! Generation options for controlling model output.

use serde::{Deserialize, Serialize};

/// Sampling strategy for token generation.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Sampling {
    /// Greedy sampling: always pick the most likely token.
    Greedy,
    /// Random sampling with temperature.
    #[default]
    Random,
}

/// Extended-reasoning effort for Foundation Models 27 requests.
#[non_exhaustive]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReasoningLevel {
    /// Minimize reasoning latency and compute.
    Light,
    /// Balance reasoning quality with latency.
    Moderate,
    /// Spend the most effort on complex reasoning.
    Deep,
}

impl ReasoningLevel {
    pub(crate) fn as_ffi_code(self) -> i32 {
        match self {
            Self::Light => 1,
            Self::Moderate => 2,
            Self::Deep => 3,
        }
    }
}

/// Controls whether the model may, must, or must not call tools
/// (Foundation Models 27).
#[non_exhaustive]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ToolCallingMode {
    /// The model decides when to call tools (framework default).
    Allowed,
    /// The model must call a tool before responding. Apple warns that this
    /// mode needs an explicit exit condition to avoid unbounded loops.
    Required,
    /// The model must answer from current context without calling tools.
    Disallowed,
}

/// Options that control how the model generates its response.
///
/// Use the builder pattern to configure options:
///
/// ```rust
/// use fm_rs::GenerationOptions;
///
/// let options = GenerationOptions::builder()
///     .temperature(0.7)
///     .max_response_tokens(500)
///     .build();
/// ```
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct GenerationOptions {
    /// Temperature for sampling (0.0-2.0).
    /// Higher values produce more random outputs.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub temperature: Option<f64>,

    /// Sampling strategy.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sampling: Option<Sampling>,

    /// Maximum number of tokens in the response.
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "maximumResponseTokens")]
    pub max_response_tokens: Option<u32>,

    /// Random seed for reproducible generation.
    ///
    /// **Note**: This field is currently not supported by Apple's `GenerationOptions` API
    /// and is ignored. It is included for potential future use.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub seed: Option<u64>,

    /// Tool-calling mode (Foundation Models 27).
    ///
    /// Ignored on pre-27 build SDKs and runtimes, where the framework
    /// behaves as [`ToolCallingMode::Allowed`].
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "toolCallingMode")]
    pub tool_calling_mode: Option<ToolCallingMode>,
}

impl GenerationOptions {
    /// Creates a new builder for configuring generation options.
    pub fn builder() -> GenerationOptionsBuilder {
        GenerationOptionsBuilder::default()
    }

    /// Serializes the options to JSON for FFI.
    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| "{}".to_string())
    }
}

/// Builder for configuring [`GenerationOptions`].
#[derive(Debug, Default)]
pub struct GenerationOptionsBuilder {
    temperature: Option<f64>,
    sampling: Option<Sampling>,
    max_response_tokens: Option<u32>,
    seed: Option<u64>,
    tool_calling_mode: Option<ToolCallingMode>,
}

impl GenerationOptionsBuilder {
    /// Sets the temperature for generation.
    ///
    /// Temperature influences the confidence of the model's response.
    /// Higher values (e.g., 1.5) produce more random outputs.
    /// Lower values (e.g., 0.2) produce more deterministic outputs.
    ///
    /// Valid range: 0.0 to 2.0. Values outside this range are ignored
    /// and the default temperature is used instead.
    pub fn temperature(mut self, temp: f64) -> Self {
        if (0.0..=2.0).contains(&temp) {
            self.temperature = Some(temp);
        }
        self
    }

    /// Sets the temperature, returning an error if out of range.
    ///
    /// This is the fallible version of [`temperature`](Self::temperature).
    /// Use this when you want to catch invalid temperature values at build time.
    ///
    /// # Errors
    ///
    /// Returns an error if `temp` is not in the range 0.0 to 2.0.
    pub fn try_temperature(mut self, temp: f64) -> Result<Self, crate::Error> {
        if (0.0..=2.0).contains(&temp) {
            self.temperature = Some(temp);
            Ok(self)
        } else {
            Err(crate::Error::InvalidInput(format!(
                "Temperature must be between 0.0 and 2.0, got {temp}"
            )))
        }
    }

    /// Sets the sampling strategy.
    pub fn sampling(mut self, sampling: Sampling) -> Self {
        self.sampling = Some(sampling);
        self
    }

    /// Sets the maximum number of tokens in the response.
    ///
    /// Only use this when you need to protect against unexpectedly verbose responses.
    /// Enforcing a strict token limit can lead to malformed or grammatically incorrect output.
    pub fn max_response_tokens(mut self, tokens: u32) -> Self {
        if tokens > 0 {
            self.max_response_tokens = Some(tokens);
        }
        self
    }

    /// Sets the random seed for reproducible generation.
    ///
    /// **Note**: This is currently not supported by Apple's `GenerationOptions` API
    /// and will be ignored. Included for potential future use.
    pub fn seed(mut self, seed: u64) -> Self {
        self.seed = Some(seed);
        self
    }

    /// Sets the tool-calling mode (Foundation Models 27).
    ///
    /// Ignored on pre-27 build SDKs and runtimes.
    pub fn tool_calling_mode(mut self, mode: ToolCallingMode) -> Self {
        self.tool_calling_mode = Some(mode);
        self
    }

    /// Builds the [`GenerationOptions`].
    pub fn build(self) -> GenerationOptions {
        GenerationOptions {
            temperature: self.temperature,
            sampling: self.sampling,
            max_response_tokens: self.max_response_tokens,
            seed: self.seed,
            tool_calling_mode: self.tool_calling_mode,
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::options::{GenerationOptions, ReasoningLevel, Sampling, ToolCallingMode};

    #[test]
    fn test_default_options() {
        let options = GenerationOptions::default();
        assert!(options.temperature.is_none());
        assert!(options.sampling.is_none());
        assert!(options.max_response_tokens.is_none());
    }

    #[test]
    fn test_builder() {
        let options = GenerationOptions::builder()
            .temperature(0.7)
            .sampling(Sampling::Random)
            .max_response_tokens(500)
            .seed(42)
            .build();

        assert_eq!(options.temperature, Some(0.7));
        assert_eq!(options.sampling, Some(Sampling::Random));
        assert_eq!(options.max_response_tokens, Some(500));
        assert_eq!(options.seed, Some(42));
    }

    #[test]
    fn test_temperature_bounds() {
        // Valid temperature
        let options = GenerationOptions::builder().temperature(1.5).build();
        assert_eq!(options.temperature, Some(1.5));

        // Out of bounds (negative)
        let options = GenerationOptions::builder().temperature(-0.5).build();
        assert!(options.temperature.is_none());

        // Out of bounds (too high)
        let options = GenerationOptions::builder().temperature(3.0).build();
        assert!(options.temperature.is_none());
    }

    #[test]
    fn test_json_serialization() {
        let options = GenerationOptions::builder()
            .temperature(0.7)
            .max_response_tokens(100)
            .build();

        let json = options.to_json();
        assert!(json.contains("temperature"));
        assert!(json.contains("0.7"));
    }

    #[test]
    fn tool_calling_mode_serializes_with_stable_names() {
        let options = GenerationOptions::builder()
            .tool_calling_mode(ToolCallingMode::Required)
            .build();
        assert_eq!(options.to_json(), r#"{"toolCallingMode":"required"}"#);

        let options = GenerationOptions::builder()
            .tool_calling_mode(ToolCallingMode::Disallowed)
            .build();
        assert!(options.to_json().contains("disallowed"));
    }

    #[test]
    fn reasoning_levels_have_stable_ffi_codes() {
        assert_eq!(ReasoningLevel::Light.as_ffi_code(), 1);
        assert_eq!(ReasoningLevel::Moderate.as_ffi_code(), 2);
        assert_eq!(ReasoningLevel::Deep.as_ffi_code(), 3);
    }
}
