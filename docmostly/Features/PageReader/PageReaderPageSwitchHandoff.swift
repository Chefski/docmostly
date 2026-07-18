import Foundation

@MainActor
enum PageReaderPageSwitchHandoff {
    enum FlushResult: Equatable {
        case completed
        case retry
        case failed
    }

    enum Outcome: Equatable {
        case completed
        case outgoingFlushFailed
        case cancelled
        case outgoingChanged
    }

    static func perform(
        requiresInitialOutgoingFlush: Bool = false,
        hasOutgoingChanges: () -> Bool,
        flushOutgoing: () async -> FlushResult,
        detachOutgoing: () -> Bool,
        loadIncoming: () async -> Void
    ) async -> Outcome {
        var requiresOutgoingFlush = requiresInitialOutgoingFlush
        while requiresOutgoingFlush || hasOutgoingChanges() {
            let flushResult = await flushOutgoing()
            if Task.isCancelled {
                return .cancelled
            }
            switch flushResult {
            case .completed:
                requiresOutgoingFlush = false
            case .retry:
                continue
            case .failed:
                return .outgoingFlushFailed
            }
        }

        guard Task.isCancelled == false else {
            return .cancelled
        }
        guard detachOutgoing() else {
            return .outgoingChanged
        }

        await loadIncoming()
        return Task.isCancelled ? .cancelled : .completed
    }
}
