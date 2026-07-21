// SDK fallback for Foundation Models 27 session APIs.
// Selected by build.rs when the build SDK is older than 27.0.

import Foundation
import FoundationModels

private let foundationModels27SdkRequirement =
    "This API requires the macOS/iOS 27 SDK and a host running version 27.0 or later"

/// SDK fallback: pre-27 SDKs define no `LanguageModelError`.
func classifyLanguageModelError(_ error: Error) -> (FFIErrorCode, String)? {
    _ = error
    return nil
}

/// SDK fallback: built-in system tools need the 27 SDK overlays.
func makeBuiltinTools(
    _ names: [String],
    errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> [any Tool]? {
    guard !names.isEmpty else { return [] }
    errorOut?.pointee = createError(foundationModels27SdkRequirement, code: .unsupportedPlatform)
    return nil
}

/// SDK fallback: pre-27 SDKs report no per-response usage.
func responseUsageJson<Content>(_ response: LanguageModelSession.Response<Content>) -> String? {
    _ = response
    return nil
}

/// SDK fallback that preserves the session-usage C ABI.
@_cdecl("fm_session_usage")
public func fm_session_usage(
    _ sessionPtr: UnsafeMutableRawPointer,
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> UnsafeMutablePointer<CChar>? {
    _ = sessionPtr
    errorOut?.pointee = createError(foundationModels27SdkRequirement, code: .unsupportedPlatform)
    return nil
}

/// SDK fallback that preserves the transcript-replacement C ABI.
@_cdecl("fm_session_set_transcript")
public func fm_session_set_transcript(
    _ sessionPtr: UnsafeMutableRawPointer,
    _ transcriptJson: UnsafePointer<CChar>,
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Bool {
    _ = sessionPtr
    _ = transcriptJson
    errorOut?.pointee = createError(foundationModels27SdkRequirement, code: .unsupportedPlatform)
    return false
}

/// SDK fallback that preserves the transcript-policy C ABI.
@_cdecl("fm_session_set_transcript_error_policy")
public func fm_session_set_transcript_error_policy(
    _ sessionPtr: UnsafeMutableRawPointer,
    _ policy: Int32,
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Bool {
    _ = sessionPtr
    _ = policy
    errorOut?.pointee = createError(foundationModels27SdkRequirement, code: .unsupportedPlatform)
    return false
}

/// SDK fallback that preserves the multimodal-respond C ABI.
@_cdecl("fm_session_respond_with_attachments")
public func fm_session_respond_with_attachments(
    _ sessionPtr: UnsafeMutableRawPointer,
    _ prompt: UnsafePointer<CChar>,
    _ optionsJson: UnsafePointer<CChar>?,
    _ attachmentsJson: UnsafePointer<CChar>,
    _ buffers: UnsafePointer<UnsafePointer<UInt8>?>?,
    _ bufferLens: UnsafePointer<UInt>?,
    _ bufferCount: Int32,
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> UnsafeMutablePointer<CChar>? {
    _ = sessionPtr
    _ = prompt
    _ = optionsJson
    _ = attachmentsJson
    _ = buffers
    _ = bufferLens
    _ = bufferCount
    errorOut?.pointee = createError(foundationModels27SdkRequirement, code: .unsupportedPlatform)
    return nil
}
