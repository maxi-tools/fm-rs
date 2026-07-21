import Foundation
import FoundationModels

private let privateCloudComputeRequirement =
    "Private Cloud Compute requires macOS 27.0, iOS 27.0, visionOS 27.0, or later"

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
private func privateCloudComputeAvailabilityCode(
    _ model: PrivateCloudComputeLanguageModel
) -> Int32 {
    switch model.availability {
    case .available:
        return 0
    case .unavailable(let reason):
        switch reason {
        case .deviceNotEligible:
            return 1
        case .systemNotReady:
            return 5
        @unknown default:
            return 4
        }
    }
}

private struct QuotaUsageDTO: Encodable {
    let status: String
    let isApproachingLimit: Bool?
    let resetDate: Double?
    let hasLimitIncreaseSuggestion: Bool
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
private func quotaUsageJson(for model: PrivateCloudComputeLanguageModel) -> String? {
    let usage = model.quotaUsage
    let status: String
    let isApproachingLimit: Bool?
    switch usage.status {
    case .belowLimit(let details):
        status = "belowLimit"
        isApproachingLimit = details.isApproachingLimit
    case .limitReached:
        status = "limitReached"
        isApproachingLimit = nil
    @unknown default:
        status = "unknown"
        isApproachingLimit = nil
    }

    let dto = QuotaUsageDTO(
        status: status,
        isApproachingLimit: isApproachingLimit,
        resetDate: usage.resetDate?.timeIntervalSince1970,
        hasLimitIncreaseSuggestion: usage.limitIncreaseSuggestion != nil
    )
    guard let data = try? JSONEncoder().encode(dto) else { return nil }
    return String(data: data, encoding: .utf8)
}

/// Maps Foundation Models 27 PCC failures onto stable FFI error codes.
func classifyPrivateCloudComputeError(_ error: Error) -> (FFIErrorCode, String)? {
    guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else {
        return nil
    }
    guard let pccError = error as? PrivateCloudComputeLanguageModel.Error else {
        return nil
    }

    switch pccError {
    case .networkFailure(let details):
        return (.networkFailure, pccError.errorDescription ?? details.debugDescription)
    case .quotaLimitReached(let details):
        var message = pccError.errorDescription ?? details.debugDescription
        if let resetDate = details.resetDate {
            message += " (quota resets \(ISO8601DateFormatter().string(from: resetDate)))"
        }
        return (.quotaLimitReached, message)
    case .serviceUnavailable(let details):
        return (.serviceUnavailable, pccError.errorDescription ?? details.debugDescription)
    @unknown default:
        return (.generationFailed, pccError.localizedDescription)
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
private func makePrivateCloudComputeLanguageModelBox() -> LanguageModelBox {
    let model = PrivateCloudComputeLanguageModel()
    return LanguageModelBox(
        isAvailable: { model.isAvailable },
        availability: { privateCloudComputeAvailabilityCode(model) },
        makeSession: { tools, instructions in
            LanguageModelSession(model: model, tools: tools, instructions: instructions)
        },
        makeTranscriptSession: { tools, transcript in
            LanguageModelSession(model: model, tools: tools, transcript: transcript)
        },
        quotaUsageJson: { quotaUsageJson(for: model) },
        contextSize: {
            try AsyncWaiter.wait {
                Int64(try await model.contextSize)
            }
        }
    )
}

/// Creates the Foundation Models 27 Private Cloud Compute model.
@_cdecl("fm_model_private_cloud_compute")
public func fm_model_private_cloud_compute(
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> UnsafeMutableRawPointer? {
    guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else {
        errorOut?.pointee = createError(
            privateCloudComputeRequirement,
            code: .unsupportedPlatform
        )
        return nil
    }

    let model = makePrivateCloudComputeLanguageModelBox()
    return Unmanaged.passRetained(model as AnyObject).toOpaque()
}
