# Collaboration Layer Remaining Work

## Current checkpoint

- Native Socket.IO page/comment event handling and Hocuspocus awareness protocol work has progressed in prior commits.
- Current WIP adds CRDT-backed handling for Socket.IO `updateOne` page title metadata so remote title updates do not force a document snapshot reload when a CRDT engine is active.
- `xcodebuild build-for-testing` passed for the current tree on the configured iPhone 17 simulator.

## Verification gap

- Simulator test execution is currently blocked by the test host launch path.
- `mcp__xcodebuildmcp.test_sim` timed out twice.
- Direct `xcodebuild test` hung during simulator launch and later reported `NSMachErrorDomain Code=-308`, `(ipc/mig) server died`.
- A focused `xcodebuild test-without-building` attempt also reached the watchdog timeout.

## Remaining implementation work

1. Re-run the focused Swift Testing coverage once the simulator test host launch path is healthy:
   - `docmostlyTests/NativeCRDTStatelessEventTests/crdtBackedRealtimeTitleUpdatePreservesLocalDocumentDraft`
   - `docmostlyTests/NativeCRDTStatelessEventTests/crdtBackedRealtimeTitleUpdateDefersWhenLocalTitleIsDirty`
2. Continue live web/iOS verification against `https://notes.withjumpseat.com`.
3. Complete true character-by-character collaborative editing by bundling or otherwise providing a Docmost-compatible Yjs runtime for the native editor.
4. Before adding the CRDT runtime, document and approve each dependency, including:
   - package name
   - license
   - why it is needed
   - what risk or complexity it removes
5. Ensure the native runtime uses Docmost's existing Yjs/Hocuspocus CRDT document stream and does not introduce a custom merge system.

## Known boundary

The app can speak parts of the Hocuspocus transport and awareness protocol today, but true conflict-free editing is not complete until the native editor can apply, emit, and render Docmost-compatible Yjs document updates using the same schema as the web editor.
