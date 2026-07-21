import Foundation

/// Fallback: the PCC feature or a 27 SDK is absent, so no PCC error types exist.
func classifyPrivateCloudComputeError(_ error: Error) -> (FFIErrorCode, String)? {
    _ = error
    return nil
}

/// SDK fallback that preserves the C ABI when Foundation Models 27 is absent.
@_cdecl("fm_model_private_cloud_compute")
public func fm_model_private_cloud_compute(
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> UnsafeMutableRawPointer? {
    errorOut?.pointee = createError(
        "Private Cloud Compute requires the macOS/iOS 27 SDK and a host running version 27.0 or later",
        code: .unsupportedPlatform
    )
    return nil
}
