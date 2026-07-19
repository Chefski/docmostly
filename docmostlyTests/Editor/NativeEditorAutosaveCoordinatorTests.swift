import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorAutosaveCoordinatorTests {
    @Test func debounceCoalescesRapidEditRequests() async {
        let delay = ControlledAutosaveDelay()
        let coordinator = NativeEditorAutosaveCoordinator(waitForDebounce: delay.wait)
        var operationCount = 0

        coordinator.schedule {
            operationCount += 1
        }
        await delay.waitForWaiterCount(1)
        coordinator.schedule {
            operationCount += 1
        }
        await delay.waitForWaiterCount(2)
        coordinator.schedule {
            operationCount += 1
        }
        await delay.waitForWaiterCount(3)

        delay.resumeAll()
        await waitUntil { operationCount == 1 }

        #expect(operationCount == 1)
    }

    @Test func inFlightPersistenceIsNotCancelledAndRunsOneFollowUp() async {
        let delay = ControlledAutosaveDelay()
        let saver = ControlledAutosaveSaver()
        let coordinator = NativeEditorAutosaveCoordinator(waitForDebounce: delay.wait)

        coordinator.schedule {
            await saver.save()
        }
        await delay.waitForWaiterCount(1)
        delay.resumeAll()
        await saver.waitForInvocationCount(1)

        coordinator.schedule {
            await saver.save()
        }
        await delay.waitForWaiterCount(1)
        coordinator.schedule {
            await saver.save()
        }
        await delay.waitForWaiterCount(2)
        delay.resumeAll()
        await Task.yield()

        #expect(saver.invocationCount == 1)
        #expect(saver.cancellationAtStart == [false])

        saver.completeNext()
        await saver.waitForInvocationCount(2)

        #expect(saver.invocationCount == 2)
        #expect(saver.cancellationAtStart == [false, false])
        #expect(saver.cancellationAtCompletion == [false])

        saver.completeNext()
        await waitUntil { saver.cancellationAtCompletion.count == 2 }
        #expect(saver.cancellationAtCompletion == [false, false])
    }

    @Test func flushStartsImmediatelyAndInvalidatesPendingDebounce() async {
        let delay = ControlledAutosaveDelay()
        let coordinator = NativeEditorAutosaveCoordinator(waitForDebounce: delay.wait)
        var operationCount = 0

        coordinator.schedule {
            operationCount += 1
        }
        await delay.waitForWaiterCount(1)
        coordinator.flush {
            operationCount += 1
        }
        await waitUntil { operationCount == 1 }

        delay.resumeAll()
        await Task.yield()

        #expect(operationCount == 1)
    }

    @Test func boundedWaitCompletesWithPersistence() async {
        let saver = ControlledAutosaveSaver()
        let coordinator = NativeEditorAutosaveCoordinator()

        coordinator.flush {
            await saver.save()
        }
        await saver.waitForInvocationCount(1)
        let waitTask = Task {
            await coordinator.waitForCurrentPersistence(timeout: .seconds(60))
        }

        saver.completeNext()

        #expect(await waitTask.value)
    }

    @Test func cancellingBoundedWaitDoesNotCancelPersistence() async {
        let saver = ControlledAutosaveSaver()
        let coordinator = NativeEditorAutosaveCoordinator()

        coordinator.flush {
            await saver.save()
        }
        await saver.waitForInvocationCount(1)
        let waitTask = Task {
            await coordinator.waitForCurrentPersistence(timeout: .seconds(60))
        }
        await Task.yield()

        waitTask.cancel()

        #expect(await waitTask.value == false)
        #expect(saver.invocationCount == 1)
        #expect(saver.cancellationAtStart == [false])
        saver.completeNext()
        await waitUntil { saver.cancellationAtCompletion.count == 1 }
        #expect(saver.cancellationAtCompletion == [false])
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<100 where condition() == false {
            await Task.yield()
        }
    }
}

@MainActor
private final class ControlledAutosaveDelay {
    private(set) var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async throws {
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForWaiterCount(_ count: Int) async {
        for _ in 0..<100 where continuations.count < count {
            await Task.yield()
        }
    }

    func resumeAll() {
        let pendingContinuations = continuations
        continuations.removeAll()
        for continuation in pendingContinuations {
            continuation.resume()
        }
    }
}

@MainActor
private final class ControlledAutosaveSaver {
    private(set) var invocationCount = 0
    private(set) var cancellationAtStart: [Bool] = []
    private(set) var cancellationAtCompletion: [Bool] = []
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func save() async {
        invocationCount += 1
        cancellationAtStart.append(Task.isCancelled)
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
        cancellationAtCompletion.append(Task.isCancelled)
    }

    func waitForInvocationCount(_ count: Int) async {
        for _ in 0..<100 where invocationCount < count {
            await Task.yield()
        }
    }

    func completeNext() {
        guard continuations.isEmpty == false else { return }
        continuations.removeFirst().resume()
    }
}
