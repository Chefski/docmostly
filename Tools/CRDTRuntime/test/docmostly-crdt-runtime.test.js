import assert from "node:assert/strict";
import test from "node:test";
import * as Y from "yjs";
import {
  initProseMirrorDoc,
  updateYFragment,
  yDocToProsemirrorJSON
} from "y-prosemirror";
import { Schema } from "@tiptap/pm/model";
import "../src/docmostly-crdt-runtime.js";

const fragmentName = "default";
const schema = new Schema({
  nodes: {
    doc: { content: "block+" },
    text: { group: "inline" },
    paragraph: {
      group: "block",
      content: "inline*",
      attrs: {
        id: { default: null },
        indent: { default: 0 },
        textAlign: { default: null }
      }
    }
  },
  marks: {}
});

test("starts with empty Yjs state without broadcasting fetched page content", () => {
  const document = globalThis.docmostlyCRDT.createDocument({
    pageID: "page-1",
    title: "Page",
    document: paragraphDocument("Seed")
  });

  assert.deepEqual(document.drainLocalUpdates(), []);

  assert.equal(
    document.encodeStateVector(),
    base64FromBytes(Y.encodeStateVector(new Y.Doc()))
  );
});

test("applies remote document update to empty native state", () => {
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
    title: null,
    document: paragraphDocument("Shared edit"),
    updatedAt: null
  }]);
});

test("preserves Docmost block identity and indentation in Yjs projections", () => {
  const source = globalThis.docmostlyCRDT.createDocument({
    pageID: "page-1",
    title: "Page",
    document: paragraphDocument("Seed")
  });
  const target = globalThis.docmostlyCRDT.createDocument({
    pageID: "page-1",
    title: "Page",
    document: paragraphDocument("Seed")
  });
  const identifiedDocument = {
    type: "doc",
    content: [{
      type: "paragraph",
      attrs: {
        id: "stableanchor",
        indent: 2
      },
      content: [{ type: "text", text: "Shared edit" }]
    }]
  };

  source.integrateLocalChange({
    after: {
      title: "Page",
      document: identifiedDocument
    }
  });
  const [update] = source.drainLocalUpdates();
  target.applyRemoteUpdate(update);

  assert.deepEqual(target.drainDocumentSnapshots(), [{
    title: null,
    document: identifiedDocument,
    updatedAt: null
  }]);
});

test("does not duplicate content when syncing with server-converted ydoc", () => {
  const nativeDocument = globalThis.docmostlyCRDT.createDocument({
    pageID: "page-1",
    title: "Page",
    document: paragraphDocument("Seed")
  });
  const serverDocument = serverYDocFromJSON(paragraphDocument("Seed"));

  const serverUpdate = base64FromBytes(Y.encodeStateAsUpdate(
    serverDocument,
    bytesFromBase64(nativeDocument.encodeStateVector())
  ));
  nativeDocument.applyRemoteUpdate(serverUpdate);

  assert.deepEqual(nativeDocument.drainDocumentSnapshots(), [{
    title: null,
    document: paragraphDocument("Seed"),
    updatedAt: null
  }]);
});

test("restores a cached full document update into an empty native document", () => {
  const cachedDocument = serverYDocFromJSON(paragraphDocument("Cached offline base"));
  const cachedState = base64FromBytes(Y.encodeStateAsUpdate(cachedDocument));
  const restoredDocument = globalThis.docmostlyCRDT.createDocument({
    pageID: "page-1",
    title: "Page",
    document: paragraphDocument("Stale REST projection")
  });

  restoredDocument.applyRemoteUpdate(cachedState);

  assert.deepEqual(restoredDocument.drainDocumentSnapshots(), [{
    title: null,
    document: paragraphDocument("Cached offline base"),
    updatedAt: null
  }]);
});

test("validates an update without mutating the live document", () => {
  const source = serverYDocFromJSON(paragraphDocument("Validated"));
  const update = base64FromBytes(Y.encodeStateAsUpdate(source));
  const document = globalThis.docmostlyCRDT.createDocument({
    pageID: "page-1",
    title: "Page",
    document: paragraphDocument("Stale projection")
  });

  assert.equal(document.validateUpdate(update), true);
  assert.deepEqual(document.currentSnapshot(), {
    title: null,
    document: { type: "doc", content: [] },
    updatedAt: null
  });
  assert.deepEqual(document.drainDocumentSnapshots(), []);
});

test("rejects corrupt updates during validation", () => {
  const document = globalThis.docmostlyCRDT.createDocument({
    pageID: "page-1",
    title: "Page",
    document: paragraphDocument("Seed")
  });

  assert.throws(() => document.validateUpdate("AQIDBA=="));
  assert.deepEqual(document.drainDocumentSnapshots(), []);
});

test("merges non-overlapping edits from two offline native documents", () => {
  const baseDocument = paragraphsDocument("First", "Second");
  const serverDocument = serverYDocFromJSON(baseDocument);
  const baseState = base64FromBytes(Y.encodeStateAsUpdate(serverDocument));
  const firstEditor = offlineDocument(baseState, baseDocument);
  const secondEditor = offlineDocument(baseState, baseDocument);

  firstEditor.integrateLocalChange({
    after: { title: "Page", document: paragraphsDocument("First by A", "Second") }
  });
  secondEditor.integrateLocalChange({
    after: { title: "Page", document: paragraphsDocument("First", "Second by B") }
  });

  const mergedDocument = new Y.Doc();
  Y.applyUpdate(mergedDocument, bytesFromBase64(baseState));
  for (const update of [
    ...firstEditor.drainLocalUpdates(),
    ...secondEditor.drainLocalUpdates()
  ]) {
    Y.applyUpdate(mergedDocument, bytesFromBase64(update));
  }

  assert.deepEqual(
    yDocToProsemirrorJSON(mergedDocument, fragmentName),
    paragraphsDocument("First by A", "Second by B")
  );
});

test("two live native editors converge after exchanging concurrent updates", () => {
  const baseDocument = paragraphsDocument("First", "Second");
  const serverDocument = serverYDocFromJSON(baseDocument);
  const baseState = base64FromBytes(Y.encodeStateAsUpdate(serverDocument));
  const firstEditor = offlineDocument(baseState, baseDocument);
  const secondEditor = offlineDocument(baseState, baseDocument);

  firstEditor.integrateLocalChange({
    after: { title: "Page", document: paragraphsDocument("First by A", "Second") }
  });
  secondEditor.integrateLocalChange({
    after: { title: "Page", document: paragraphsDocument("First", "Second by B") }
  });
  const firstUpdates = firstEditor.drainLocalUpdates();
  const secondUpdates = secondEditor.drainLocalUpdates();

  for (const update of secondUpdates) {
    firstEditor.applyRemoteUpdate(update);
  }
  for (const update of firstUpdates) {
    secondEditor.applyRemoteUpdate(update);
  }

  const expectedDocument = paragraphsDocument("First by A", "Second by B");
  assert.deepEqual(firstEditor.currentSnapshot().document, expectedDocument);
  assert.deepEqual(secondEditor.currentSnapshot().document, expectedDocument);
});

function paragraphDocument(text) {
  return paragraphsDocument(text);
}

function paragraphsDocument(...texts) {
  const blockIDs = ["firstblockid", "secondblocki"];
  return {
    type: "doc",
    content: texts.map((text, index) => ({
      type: "paragraph",
      attrs: {
        id: blockIDs[index] ?? `fallbackblock${index}`,
        indent: 0
      },
      content: [{ type: "text", text }]
    }))
  };
}

function offlineDocument(baseState, document) {
  const offline = globalThis.docmostlyCRDT.createDocument({
    pageID: "page-1",
    title: "Page",
    document
  });
  offline.applyRemoteUpdate(baseState);
  offline.drainDocumentSnapshots();
  return offline;
}

function serverYDocFromJSON(document) {
  const ydoc = new Y.Doc();
  const fragment = ydoc.getXmlFragment(fragmentName);
  const nextDoc = schema.nodeFromJSON(document);
  const transactionTarget = {
    transact: (operation) => ydoc.transact(operation)
  };
  updateYFragment(transactionTarget, fragment, nextDoc, mappingStateFor(fragment));
  return ydoc;
}

function mappingStateFor(fragment) {
  const state = initProseMirrorDoc(fragment, schema);
  return {
    mapping: state.mapping,
    isOMark: state.meta.isOMark
  };
}

function bytesFromBase64(base64) {
  if (!base64) return new Uint8Array();
  return Uint8Array.from(Buffer.from(base64, "base64"));
}

function base64FromBytes(bytes) {
  return Buffer.from(bytes).toString("base64");
}
