import assert from "node:assert/strict";
import test from "node:test";
import * as Y from "yjs";
import { yDocToProsemirrorJSON } from "y-prosemirror";
import "../src/docmostly-crdt-runtime.js";

const fragmentName = "default";

test("seeds the initial document into Yjs state without broadcasting it as a local update", () => {
  const document = globalThis.docmostlyCRDT.createDocument({
    pageID: "page-1",
    title: "Page",
    document: paragraphDocument("Seed")
  });

  assert.deepEqual(document.drainLocalUpdates(), []);

  const emptyStateVector = base64FromBytes(Y.encodeStateVector(new Y.Doc()));
  const update = document.encodeStateAsUpdate(emptyStateVector);
  const ydoc = new Y.Doc();
  Y.applyUpdate(ydoc, bytesFromBase64(update));

  assert.deepEqual(yDocToProsemirrorJSON(ydoc, fragmentName), paragraphDocument("Seed"));
});

test("seeds independent documents with shared Yjs state so later updates replace the seed", () => {
  const firstDocument = globalThis.docmostlyCRDT.createDocument({
    pageID: "page-1",
    title: "Page",
    document: paragraphDocument("Seed")
  });
  const secondDocument = globalThis.docmostlyCRDT.createDocument({
    pageID: "page-1",
    title: "Page",
    document: paragraphDocument("Seed")
  });

  firstDocument.integrateLocalChange({
    after: {
      title: "Page",
      document: paragraphDocument("Shared edit")
    }
  });
  const [update] = firstDocument.drainLocalUpdates();

  secondDocument.applyRemoteUpdate(update);

  assert.deepEqual(secondDocument.drainDocumentSnapshots(), [{
    title: "Page",
    document: paragraphDocument("Shared edit"),
    updatedAt: null
  }]);
});

function paragraphDocument(text) {
  return {
    type: "doc",
    content: [{
      type: "paragraph",
      content: [{ type: "text", text }]
    }]
  };
}

function bytesFromBase64(base64) {
  if (!base64) return new Uint8Array();
  return Uint8Array.from(Buffer.from(base64, "base64"));
}

function base64FromBytes(bytes) {
  return Buffer.from(bytes).toString("base64");
}
