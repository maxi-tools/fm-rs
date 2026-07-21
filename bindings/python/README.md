# fm-rs - Python bindings for Apple FoundationModels

Python bindings for [fm-rs](https://github.com/blacktop/fm-rs), enabling on-device AI via Apple Intelligence.

## Requirements

- **macOS 26.0+** (Tahoe) on **Apple Silicon (ARM64)**
- **Apple Intelligence enabled** in System Settings
- **Python 3.10+**

## Installation

```bash
pip install fm-rs
```

### From Source

```bash
# Requires Rust toolchain
cd bindings/python
uv sync
uv run maturin develop
```

## Quick Start

```python
import fm

# Create the default system language model
model = fm.SystemLanguageModel()

# Check availability
if not model.is_available:
    print("Apple Intelligence is not available")
    exit(1)

# Create a session
session = fm.Session(model, instructions="You are a helpful assistant.")

# Send a prompt
response = session.respond("What is the capital of France?")
print(response.content)
```

## Streaming

```python
import fm

model = fm.SystemLanguageModel()
session = fm.Session(model)

# Stream the response
session.stream_response(
    "Tell me a short story",
    lambda chunk: print(chunk, end="", flush=True)
)
print()  # newline at end
```

## Structured Generation

```python
import fm

model = fm.SystemLanguageModel()
session = fm.Session(model)

# Using a dict schema
schema = {
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer"}
    },
    "required": ["name", "age"]
}

person = session.respond_structured("Generate a fictional person", schema)
print(f"Name: {person['name']}, Age: {person['age']}")

# Using the Schema builder
schema = (fm.Schema.object()
    .property("name", fm.Schema.string(), required=True)
    .property("age", fm.Schema.integer().minimum(0), required=True))

person = session.respond_structured("Generate a fictional person", schema.to_dict())
```

## Tool Calling

Tools allow the model to call external functions during generation.

```python
import fm

class WeatherTool:
    name = "get_weather"
    description = "Gets the current weather for a location"
    arguments_schema = {
        "type": "object",
        "properties": {
            "city": {"type": "string", "description": "The city name"}
        },
        "required": ["city"]
    }

    def call(self, args):
        city = args.get("city", "Unknown")
        return f"Sunny, 72°F in {city}"

model = fm.SystemLanguageModel()
session = fm.Session(model, tools=[WeatherTool()])

response = session.respond("What's the weather in Paris?")
print(response.content)
```

## Context Management

```python
import fm

model = fm.SystemLanguageModel()
session = fm.Session(model)

# After some conversation...
limit = fm.ContextLimit.default_on_device()
usage = session.context_usage(limit)

print(f"Tokens used: {usage.estimated_tokens}/{usage.max_tokens}")
print(f"Utilization: {usage.utilization:.1%}")

if usage.over_limit:
    # Compact the conversation
    transcript = session.transcript_json
    summary = fm.compact_transcript(model, transcript)
    print(f"Summary: {summary}")
```

## macOS 27 Capabilities

On macOS/iOS 27+, sessions support image attachments, Apple's built-in
tools, exact token accounting, and transcript controls. These raise
`UnsupportedPlatformError` on older build SDKs or runtimes.

```python
import fm

model = fm.SystemLanguageModel()
print(model.context_size())  # model-reported context window (26.4+ SDK)

session = fm.Session(
    model,
    instructions="Describe images and read any text in them.",
    system_tools=["ocr"],  # also: "barcode_reader", "spotlight_search"
)

response = session.respond_with_attachments(
    "What does this receipt say?",
    [fm.Attachment.file("receipt.png", label="receipt")],
    fm.GenerationOptions(tool_calling_mode="allowed"),
)
print(response.content)
print(response.usage)  # per-response token usage, or None

usage = session.usage()  # exact cumulative session usage
print(usage.input_tokens, usage.cached_input_tokens,
      usage.output_tokens, usage.reasoning_tokens)

session.set_transcript_error_handling_policy("revert")  # or "preserve", None
```

Failures surface as typed exceptions on macOS 26 and 27 runtimes alike:
`ContextSizeExceededError`, `RateLimitedError`, `GuardrailViolationError`,
`RefusalError`, `AssetsUnavailableError`, `ConcurrentRequestsError`, and the
`Unsupported*Error` family. Private Cloud Compute is currently Rust-only.

## Error Handling

```python
import fm

try:
    model = fm.SystemLanguageModel()
    model.ensure_available()
except fm.DeviceNotEligibleError:
    print("This device doesn't support Apple Intelligence")
except fm.AppleIntelligenceNotEnabledError:
    print("Please enable Apple Intelligence in Settings")
except fm.ModelNotReadyError:
    print("Model is still downloading, try again later")
except fm.ModelNotAvailableError:
    print("Model not available for unknown reason")
```

## API Reference

### Classes

- `SystemLanguageModel` - Entry point for on-device AI
- `Session` - Maintains conversation context
- `GenerationOptions` - Controls generation (temperature, max_tokens, tool_calling_mode, etc.)
- `Response` - Model output, with per-response `usage` on macOS/iOS 27+
- `SessionUsage` - Exact token usage counters (macOS/iOS 27+)
- `Attachment` - Image input for multimodal prompting (macOS/iOS 27+)
- `ToolOutput` - Tool invocation result
- `ContextLimit` - Context window configuration
- `ContextUsage` - Estimated token usage
- `Schema` - JSON Schema builder

### Enums

- `Sampling` - `Greedy` or `Random`
- `ModelAvailability` - `Available`, `DeviceNotEligible`, `AppleIntelligenceNotEnabled`, `ModelNotReady`, `Unknown`

### Functions

- `estimate_tokens(text, chars_per_token=4)` - Estimate token count
- `context_usage_from_transcript(json, limit)` - Get context usage
- `transcript_to_text(json)` - Extract text from transcript
- `compact_transcript(model, json)` - Summarize conversation

### Exceptions

- `FmError` - Base exception
- `ModelNotAvailableError`
- `DeviceNotEligibleError`
- `AppleIntelligenceNotEnabledError`
- `ModelNotReadyError`
- `GenerationError`
- `ToolCallError`
- `JsonError`
- `UnsupportedPlatformError` - API needs a newer Apple platform or SDK
- `ContextSizeExceededError`, `RateLimitedError`, `GuardrailViolationError`,
  `RefusalError`, `AssetsUnavailableError`, `ConcurrentRequestsError`
- `UnsupportedCapabilityError`, `UnsupportedTranscriptContentError`,
  `UnsupportedGenerationGuideError`, `UnsupportedLanguageOrLocaleError`
- `NetworkFailureError`, `QuotaLimitReachedError`, `ServiceUnavailableError`
  (Private Cloud Compute)

## Notes

- **Apple Silicon only**: Wheels are built for macOS ARM64 only (Apple Silicon Macs)
- **Tool callbacks**: May be invoked from non-main threads; avoid UI work in callbacks
- **Blocking calls**: All calls block until completion; use streaming for long responses
- **GIL**: Callbacks run under the GIL; keep them short

## Development

```bash
cd bindings/python
uv sync
uv run maturin develop
uv run pytest tests/
```

## License

MIT
