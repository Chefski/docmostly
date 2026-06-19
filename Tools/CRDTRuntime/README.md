# Docmostly CRDT Runtime

This package builds `docmostly/DocmostlyCRDTRuntime.js`, the JavaScriptCore runtime used by the native editor to speak Docmost's existing Yjs/Hocuspocus document protocol.

Dependency rationale:

- `yjs` `13.6.30`, MIT: provides the CRDT document, state vectors, update encoding, update application, and relative positions used by Docmost `/collab`.
- `y-prosemirror` `1.3.7`, MIT: converts between ProseMirror JSON and Yjs XML fragments and performs ProseMirror-aware Yjs fragment updates. This avoids inventing a merge layer.
- `@tiptap/pm` `3.20.4`, MIT: provides the ProseMirror schema/model primitives needed by `y-prosemirror`; version aligned with Docmost web's Tiptap stack.
- `esbuild` `0.27.1`, MIT: build-time bundler only. It creates the single JavaScript file that iOS loads through JavaScriptCore.

Build:

```sh
npm install
npm run build
```

The generated runtime is committed as an app resource so the iOS target does not need Node.js at build or runtime.
