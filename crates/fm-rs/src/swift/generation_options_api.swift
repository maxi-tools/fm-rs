import FoundationModels

/// Creates generation options with the nondeprecated Xcode 27 spelling.
func makeGenerationOptions(
    sampling: String?,
    temperature: Double?,
    maximumResponseTokens: UInt32?,
    toolCallingMode: String?
) -> GenerationOptions {
    var options = GenerationOptions(
        samplingMode: sampling == "greedy" ? .greedy : nil,
        temperature: temperature,
        maximumResponseTokens: maximumResponseTokens.map(Int.init)
    )
    if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
        switch toolCallingMode {
        case "allowed":
            options.toolCallingMode = .allowed
        case "required":
            options.toolCallingMode = .required
        case "disallowed":
            options.toolCallingMode = .disallowed
        default:
            break
        }
    }
    return options
}
