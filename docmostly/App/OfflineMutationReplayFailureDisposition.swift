import Foundation

nonisolated enum OfflineMutationReplayFailureDisposition: Equatable {
    case stopWithoutMutation
    case dropRecord
    case retainForRetry

    init(error: any Error, payload: OfflineMutationPayload? = nil) {
        if error is CancellationError {
            self = .stopWithoutMutation
            return
        }

        guard let apiError = error as? APIError else {
            self = .retainForRetry
            return
        }

        switch apiError {
        case .httpStatus(let status, _)
            where status >= 400 && status < 500 && status != 401 && status != 403 && status != 408 && status != 429:
            self = payload?.canDropAfterPermanentClientFailure == true ? .dropRecord : .retainForRetry
        case .connectionFailed,
                .invalidResponse,
                .httpStatus,
                .missingData,
                .decodingFailed,
                .responseTooLarge:
            self = .retainForRetry
        }
    }
}
