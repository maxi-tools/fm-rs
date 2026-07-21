import FoundationModels

/// Creates generation options using the Foundation Models 26 SDK spelling.
/// Pre-27 SDKs have no tool-calling mode; the option is ignored.
func makeGenerationOptions(
    sampling: String?,
    temperature: Double?,
    maximumResponseTokens: UInt32?,
    toolCallingMode: String?
) -> GenerationOptions {
    _ = toolCallingMode
    return GenerationOptions(
        sampling: sampling == "greedy" ? .greedy : nil,
        temperature: temperature,
        maximumResponseTokens: maximumResponseTokens.map(Int.init)
    )
}
