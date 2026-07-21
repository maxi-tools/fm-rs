import Foundation

/// SDK fallback that preserves the C ABI when ContextOptions is absent.
@_cdecl("fm_session_respond_with_reasoning")
public func fm_session_respond_with_reasoning(
    _ sessionPtr: UnsafeMutableRawPointer,
    _ prompt: UnsafePointer<CChar>,
    _ optionsJson: UnsafePointer<CChar>?,
    _ reasoningLevelValue: Int32,
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> UnsafeMutablePointer<CChar>? {
    _ = sessionPtr
    _ = prompt
    _ = optionsJson
    _ = reasoningLevelValue
    errorOut?.pointee = createError(
        "Extended reasoning requires the macOS/iOS 27 SDK and a host running version 27.0 or later",
        code: .unsupportedPlatform
    )
    return nil
}

/// SDK fallback that preserves the timeout C ABI when ContextOptions is absent.
@_cdecl("fm_session_respond_with_reasoning_timeout")
public func fm_session_respond_with_reasoning_timeout(
    _ sessionPtr: UnsafeMutableRawPointer,
    _ prompt: UnsafePointer<CChar>,
    _ optionsJson: UnsafePointer<CChar>?,
    _ reasoningLevelValue: Int32,
    _ timeoutMs: UInt64,
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> UnsafeMutablePointer<CChar>? {
    _ = sessionPtr
    _ = prompt
    _ = optionsJson
    _ = reasoningLevelValue
    _ = timeoutMs
    errorOut?.pointee = createError(
        "Extended reasoning requires the macOS/iOS 27 SDK and a host running version 27.0 or later",
        code: .unsupportedPlatform
    )
    return nil
}
