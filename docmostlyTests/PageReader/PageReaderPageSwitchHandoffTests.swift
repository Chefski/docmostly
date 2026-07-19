import Foundation
import Testing
@testable import docmostly

@MainActor
struct PageReaderPageSwitchHandoffTests {
    @Test func flushesOutgoingBeforeDetachAndIncomingLoad() async {
        var events: [String] = []
        var hasOutgoingChanges = true

        let outcome = await PageReaderPageSwitchHandoff.perform(
            hasOutgoingChanges: {
                hasOutgoingChanges
            },
            flushOutgoing: {
                events.append("flush")
                hasOutgoingChanges = false
                return .completed
            },
            detachOutgoing: {
                events.append("detach")
                return true
            },
            loadIncoming: {
                events.append("load")
            }
        )

        #expect(outcome == .completed)
        #expect(events == ["flush", "detach", "load"])
    }

    @Test func flushesAgainWhenAnEditArrivesDuringPersistence() async {
        var events: [String] = []
        var remainingFlushes = 2

        let outcome = await PageReaderPageSwitchHandoff.perform(
            hasOutgoingChanges: {
                remainingFlushes > 0
            },
            flushOutgoing: {
                events.append("flush-\(remainingFlushes)")
                remainingFlushes -= 1
                return .completed
            },
            detachOutgoing: {
                events.append("detach")
                return true
            },
            loadIncoming: {
                events.append("load")
            }
        )

        #expect(outcome == .completed)
        #expect(events == ["flush-2", "flush-1", "detach", "load"])
    }

    @Test func cleanOutgoingStillDrainsOutstandingPersistenceBeforeLoad() async {
        var events: [String] = []

        let outcome = await PageReaderPageSwitchHandoff.perform(
            requiresInitialOutgoingFlush: true,
            hasOutgoingChanges: {
                false
            },
            flushOutgoing: {
                events.append("wait-for-persistence")
                return .completed
            },
            detachOutgoing: {
                events.append("detach")
                return true
            },
            loadIncoming: {
                events.append("load")
            }
        )

        #expect(outcome == .completed)
        #expect(events == ["wait-for-persistence", "detach", "load"])
    }

    @Test func durablyQueuedDeferredConflictDoesNotBusyLoopBeforeDetach() async {
        let editor = NativeRichEditorViewModel(pageID: "page-1")
        editor.isDirty = true
        editor.hasDurablyPersistedLocalCRDTDraft = true
        var flushCount = 0
        var didDetach = false

        let outcome = await PageReaderPageSwitchHandoff.perform(
            requiresInitialOutgoingFlush: true,
            hasOutgoingChanges: {
                editor.hasOutgoingChangesRequiringPersistence
            },
            flushOutgoing: {
                flushCount += 1
                return .completed
            },
            detachOutgoing: {
                didDetach = true
                return true
            },
            loadIncoming: { }
        )

        #expect(outcome == .completed)
        #expect(flushCount == 1)
        #expect(didDetach)
        #expect(editor.isDirty)
    }

    @Test func failedFlushKeepsOutgoingAttachedAndDoesNotLoadIncoming() async {
        var didDetach = false
        var didLoad = false

        let outcome = await PageReaderPageSwitchHandoff.perform(
            hasOutgoingChanges: {
                true
            },
            flushOutgoing: {
                .failed
            },
            detachOutgoing: {
                didDetach = true
                return true
            },
            loadIncoming: {
                didLoad = true
            }
        )

        #expect(outcome == .outgoingFlushFailed)
        #expect(didDetach == false)
        #expect(didLoad == false)
    }

    @Test func persistenceTimeoutRetriesUntilTheOutgoingDraftIsDurable() async {
        var events: [String] = []
        var flushAttempts = 0
        var hasOutgoingChanges = true

        let outcome = await PageReaderPageSwitchHandoff.perform(
            hasOutgoingChanges: {
                hasOutgoingChanges
            },
            flushOutgoing: {
                flushAttempts += 1
                events.append("wait-\(flushAttempts)")
                if flushAttempts == 1 {
                    return .retry
                }
                hasOutgoingChanges = false
                return .completed
            },
            detachOutgoing: {
                events.append("detach")
                return true
            },
            loadIncoming: {
                events.append("load")
            }
        )

        #expect(outcome == .completed)
        #expect(events == ["wait-1", "wait-2", "detach", "load"])
    }

    @Test func rapidAToBToCNavigationLoadsOnlyTheLatestRequestAfterPersistence() async {
        let persistence = SharedPageSwitchPersistence()
        var events: [String] = []
        let requestB = makeLatestRequestHandoffTask(
            destination: "B",
            persistence: persistence,
            events: { events.append($0) }
        )
        await persistence.waitUntilStarted(count: 1)

        requestB.cancel()
        let requestC = makeLatestRequestHandoffTask(
            destination: "C",
            persistence: persistence,
            events: { events.append($0) }
        )
        await persistence.waitUntilStarted(count: 2)
        persistence.complete()

        #expect(await requestB.value == .cancelled)
        #expect(await requestC.value == .completed)
        #expect(events == ["detach-C", "load-C"])
    }

    @Test func replacedOutgoingEditorDoesNotStartIncomingLoad() async {
        var didLoad = false

        let outcome = await PageReaderPageSwitchHandoff.perform(
            hasOutgoingChanges: {
                false
            },
            flushOutgoing: {
                .completed
            },
            detachOutgoing: {
                false
            },
            loadIncoming: {
                didLoad = true
            }
        )

        #expect(outcome == .outgoingChanged)
        #expect(didLoad == false)
    }

    @Test func cancellationDuringFlushDoesNotDetachOrLoad() async {
        let flush = ControlledPageSwitchFlush()
        var didDetach = false
        var didLoad = false

        let task = Task { @MainActor in
            await PageReaderPageSwitchHandoff.perform(
                hasOutgoingChanges: {
                    true
                },
                flushOutgoing: {
                    await flush.run() ? .completed : .failed
                },
                detachOutgoing: {
                    didDetach = true
                    return true
                },
                loadIncoming: {
                    didLoad = true
                }
            )
        }

        await flush.waitUntilStarted()
        task.cancel()
        flush.complete(with: true)
        let outcome = await task.value

        #expect(outcome == .cancelled)
        #expect(didDetach == false)
        #expect(didLoad == false)
    }

    @Test func outgoingEditorLifetimeExtendsThroughSuspendedFlush() async throws {
        let flush = ControlledPageSwitchFlush()
        var outgoingEditor: PageSwitchLifetimeProbe? = PageSwitchLifetimeProbe()
        let weakOutgoingEditor = WeakPageSwitchLifetimeProbe(outgoingEditor)
        let task = makeLifetimeHandoffTask(
            outgoingEditor: try #require(outgoingEditor),
            flush: flush
        )
        outgoingEditor = nil

        await flush.waitUntilStarted()
        #expect(weakOutgoingEditor.value != nil)

        flush.complete(with: true)
        #expect(await task.value == .completed)
    }

    private func makeLifetimeHandoffTask(
        outgoingEditor: PageSwitchLifetimeProbe,
        flush: ControlledPageSwitchFlush
    ) -> Task<PageReaderPageSwitchHandoff.Outcome, Never> {
        Task { @MainActor [outgoingEditor] in
            var hasChanges = true
            return await PageReaderPageSwitchHandoff.perform(
                hasOutgoingChanges: {
                    _ = outgoingEditor.id
                    return hasChanges
                },
                flushOutgoing: {
                    let didFlush = await flush.run()
                    hasChanges = false
                    return didFlush ? .completed : .failed
                },
                detachOutgoing: {
                    _ = outgoingEditor.id
                    return true
                },
                loadIncoming: {
                    _ = outgoingEditor.id
                }
            )
        }
    }

    private func makeLatestRequestHandoffTask(
        destination: String,
        persistence: SharedPageSwitchPersistence,
        events: @escaping @MainActor (String) -> Void
    ) -> Task<PageReaderPageSwitchHandoff.Outcome, Never> {
        Task { @MainActor in
            var hasChanges = true
            return await PageReaderPageSwitchHandoff.perform(
                hasOutgoingChanges: {
                    hasChanges
                },
                flushOutgoing: {
                    let result = await persistence.waitForCompletion()
                    hasChanges = false
                    return result
                },
                detachOutgoing: {
                    events("detach-\(destination)")
                    return true
                },
                loadIncoming: {
                    events("load-\(destination)")
                }
            )
        }
    }
}

@MainActor
private final class ControlledPageSwitchFlush {
    private var isStarted = false
    private var continuation: CheckedContinuation<Bool, Never>?

    func run() async -> Bool {
        isStarted = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilStarted() async {
        for _ in 0..<100 where isStarted == false {
            await Task.yield()
        }
    }

    func complete(with result: Bool) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

@MainActor
private final class SharedPageSwitchPersistence {
    private var startCount = 0
    private var isComplete = false
    private var continuations: [CheckedContinuation<PageReaderPageSwitchHandoff.FlushResult, Never>] = []

    func waitForCompletion() async -> PageReaderPageSwitchHandoff.FlushResult {
        startCount += 1
        guard isComplete == false else { return .completed }

        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitUntilStarted(count: Int) async {
        for _ in 0..<100 where startCount < count {
            await Task.yield()
        }
    }

    func complete() {
        isComplete = true
        let pendingContinuations = continuations
        continuations.removeAll()
        for continuation in pendingContinuations {
            continuation.resume(returning: .completed)
        }
    }
}

@MainActor
private final class PageSwitchLifetimeProbe {
    let id = UUID()
}

@MainActor
private final class WeakPageSwitchLifetimeProbe {
    weak var value: PageSwitchLifetimeProbe?

    init(_ value: PageSwitchLifetimeProbe?) {
        self.value = value
    }
}
