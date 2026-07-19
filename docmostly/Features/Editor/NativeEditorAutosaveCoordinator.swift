import Foundation

@MainActor
final class NativeEditorAutosaveCoordinator {
    typealias Operation = @MainActor () async -> Void
    typealias Wait = @MainActor () async throws -> Void

    private let waitForDebounce: Wait
    private var debounceTask: Task<Void, Never>?
    private var persistenceTask: Task<Void, Never>?
    private var requestRevision: UInt = 0
    private var readyRevision: UInt = 0
    private var attemptedRevision: UInt = 0
    private var completedRevision: UInt = 0
    private var pendingOperation: Operation?
    private var readyOperation: Operation?
    private var completionWaiters: [UUID: CompletionWaiter] = [:]

    private struct CompletionWaiter {
        let targetRevision: UInt
        let continuation: CheckedContinuation<Bool, Never>
    }

    init(
        debounceDelay: Duration = .milliseconds(900),
        waitForDebounce: Wait? = nil
    ) {
        self.waitForDebounce = waitForDebounce ?? {
            try await Task.sleep(for: debounceDelay)
        }
    }

    deinit {
        debounceTask?.cancel()
        for waiter in completionWaiters.values {
            waiter.continuation.resume(returning: false)
        }
    }

    func schedule(_ operation: @escaping Operation) {
        let revision = registerRequest(operation)
        debounceTask?.cancel()
        debounceTask = Task { [weak self, waitForDebounce] in
            do {
                try await waitForDebounce()
                try Task.checkCancellation()
            } catch {
                return
            }

            self?.markReady(revision: revision)
        }
    }

    func flush(_ operation: @escaping Operation) {
        let revision = registerRequest(operation)
        debounceTask?.cancel()
        debounceTask = nil
        markReady(revision: revision)
    }

    func waitForCurrentPersistence(timeout: Duration) async -> Bool {
        let targetRevision = requestRevision
        guard targetRevision > completedRevision else { return true }

        let waiterID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: false)
                    return
                }
                if targetRevision <= completedRevision {
                    continuation.resume(returning: true)
                    return
                }

                completionWaiters[waiterID] = CompletionWaiter(
                    targetRevision: targetRevision,
                    continuation: continuation
                )
                Task { [weak self] in
                    try? await Task.sleep(for: timeout)
                    self?.resolveCompletionWaiter(id: waiterID, didComplete: false)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.resolveCompletionWaiter(id: waiterID, didComplete: false)
            }
        }
    }

    private func registerRequest(_ operation: @escaping Operation) -> UInt {
        requestRevision += 1
        pendingOperation = operation
        readyRevision = attemptedRevision
        readyOperation = nil
        return requestRevision
    }

    private func markReady(revision: UInt) {
        guard revision == requestRevision, let pendingOperation else { return }

        readyRevision = revision
        readyOperation = pendingOperation
        self.pendingOperation = nil
        debounceTask = nil
        startPersistenceIfNeeded()
    }

    private func startPersistenceIfNeeded() {
        guard persistenceTask == nil else { return }
        guard readyRevision > attemptedRevision, let readyOperation else { return }

        let revision = readyRevision
        attemptedRevision = revision
        self.readyOperation = nil
        persistenceTask = Task { [weak self, readyOperation] in
            await readyOperation()
            self?.finishPersistence(revision: revision)
        }
    }

    private func finishPersistence(revision: UInt) {
        guard revision == attemptedRevision else { return }

        persistenceTask = nil
        completedRevision = max(completedRevision, revision)
        resolveCompletedWaiters()
        startPersistenceIfNeeded()
    }

    private func resolveCompletedWaiters() {
        let completedWaiterIDs = completionWaiters.compactMap { waiterID, waiter in
            waiter.targetRevision <= completedRevision ? waiterID : nil
        }
        for waiterID in completedWaiterIDs {
            resolveCompletionWaiter(id: waiterID, didComplete: true)
        }
    }

    private func resolveCompletionWaiter(id: UUID, didComplete: Bool) {
        completionWaiters.removeValue(forKey: id)?.continuation.resume(returning: didComplete)
    }
}
