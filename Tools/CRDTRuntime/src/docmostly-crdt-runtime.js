import * as Y from "yjs";
import {
  absolutePositionToRelativePosition,
  initProseMirrorDoc,
  relativePositionToAbsolutePosition,
  updateYFragment,
  yDocToProsemirrorJSON
} from "y-prosemirror";
import { Schema } from "@tiptap/pm/model";

const fragmentName = "default";
const seedClientID = 1;

const schema = new Schema({
  nodes: {
    doc: { content: "block+" },
    text: { group: "inline" },
    paragraph: {
      group: "block",
      content: "inline*",
      attrs: { textAlign: { default: null } }
    },
    heading: {
      group: "block",
      content: "inline*",
      attrs: { level: { default: 1 }, textAlign: { default: null } }
    },
    blockquote: { group: "block", content: "block+" },
    codeBlock: {
      group: "block",
      content: "text*",
      marks: "",
      attrs: { language: { default: null } }
    },
    hardBreak: { inline: true, group: "inline", selectable: false },
    bulletList: { group: "block", content: "listItem+" },
    orderedList: {
      group: "block",
      content: "listItem+",
      attrs: { start: { default: 1 } }
    },
    listItem: { content: "paragraph block*" },
    taskList: { group: "block", content: "taskItem+" },
    taskItem: {
      content: "paragraph block*",
      attrs: { checked: { default: false } }
    },
    horizontalRule: { group: "block" },
    table: { group: "block", content: "tableRow+" },
    tableRow: { content: "(tableCell | tableHeader)+" },
    tableCell: {
      content: "block+",
      attrs: cellAttrs()
    },
    tableHeader: {
      content: "block+",
      attrs: cellAttrs()
    },
    callout: {
      group: "block",
      content: "block*",
      attrs: {
        type: { default: "info" },
        icon: { default: null }
      }
    },
    details: {
      group: "block",
      content: "detailsSummary detailsContent",
      attrs: { open: { default: false } }
    },
    detailsSummary: { content: "inline*" },
    detailsContent: { content: "block*" },
    columns: {
      group: "block",
      content: "column+",
      attrs: {
        layout: { default: "two_equal" },
        widthMode: { default: "normal" }
      }
    },
    column: { content: "block+" },
    image: mediaNodeAttrs(),
    video: mediaNodeAttrs(),
    audio: mediaNodeAttrs(),
    pdf: leafBlockAttrs({
      src: { default: null },
      name: { default: null },
      attachmentId: { default: null },
      size: { default: null },
      width: { default: null },
      height: { default: null }
    }),
    attachment: leafBlockAttrs({
      url: { default: null },
      name: { default: null },
      mime: { default: null },
      size: { default: null },
      attachmentId: { default: null }
    }),
    pageBreak: leafBlockAttrs(),
    subpages: leafBlockAttrs(),
    embed: embedAttrs(),
    youtube: embedAttrs(),
    drawio: diagramAttrs(),
    excalidraw: diagramAttrs(),
    mathBlock: leafBlockAttrs({ text: { default: null } }),
    transclusionSource: {
      group: "block",
      content: "block*",
      attrs: { id: { default: null } }
    },
    transclusionReference: leafBlockAttrs({
      sourcePageId: { default: null },
      transclusionId: { default: null }
    }),
    mention: inlineAtomAttrs({
      id: { default: null },
      label: { default: null },
      entityType: { default: null },
      entityId: { default: null },
      slugId: { default: null },
      creatorId: { default: null },
      anchorId: { default: null }
    }),
    status: inlineAtomAttrs({
      text: { default: "" },
      color: { default: "gray" }
    }),
    mathInline: inlineAtomAttrs({ text: { default: "" } })
  },
  marks: {
    bold: {},
    italic: {},
    underline: {},
    strike: {},
    code: {},
    subscript: {},
    superscript: {},
    link: { attrs: { href: { default: null }, target: { default: null } } },
    highlight: {
      attrs: {
        color: { default: null },
        colorName: { default: null }
      }
    },
    textStyle: { attrs: { color: { default: null } } },
    comment: {
      attrs: {
        commentId: { default: null },
        resolved: { default: false }
      }
    }
  }
});

function leafBlockAttrs(attrs = {}) {
  return { group: "block", atom: true, attrs };
}

function inlineAtomAttrs(attrs = {}) {
  return { inline: true, group: "inline", atom: true, attrs };
}

function cellAttrs() {
  return {
    colspan: { default: 1 },
    rowspan: { default: 1 },
    colwidth: { default: null },
    backgroundColorName: { default: null }
  };
}

function mediaNodeAttrs() {
  return leafBlockAttrs({
    src: { default: null },
    alt: { default: null },
    attachmentId: { default: null },
    size: { default: null },
    width: { default: null },
    height: { default: null },
    aspectRatio: { default: null },
    align: { default: null }
  });
}

function embedAttrs() {
  return leafBlockAttrs({
    src: { default: null },
    provider: { default: null },
    align: { default: null },
    width: { default: null },
    height: { default: null }
  });
}

function diagramAttrs() {
  return leafBlockAttrs({
    src: { default: null },
    title: { default: null },
    alt: { default: null },
    attachmentId: { default: null },
    size: { default: null },
    width: { default: null },
    height: { default: null },
    aspectRatio: { default: null },
    align: { default: null }
  });
}

globalThis.docmostlyCRDT = {
  createDocument(seed) {
    return new DocmostlyCRDTDocument(seed);
  }
};

class DocmostlyCRDTDocument {
  constructor(seed) {
    this.title = seed.title;
    this.localOrigin = {};
    this.remoteOrigin = {};
    this.localUpdates = [];
    this.snapshots = [];
    this.ydoc = new Y.Doc();
    this.fragment = this.ydoc.getXmlFragment(fragmentName);
    this.applySeedDocument(seed.title, seed.document);
    this.ydoc.on("update", (update, origin) => {
      if (origin === this.localOrigin) {
        this.localUpdates.push(base64FromBytes(update));
      }
    });
  }

  encodeStateVector() {
    return base64FromBytes(Y.encodeStateVector(this.ydoc));
  }

  encodeStateAsUpdate(stateVector) {
    return base64FromBytes(Y.encodeStateAsUpdate(this.ydoc, bytesFromBase64(stateVector)));
  }

  applyRemoteUpdate(update) {
    Y.applyUpdate(this.ydoc, bytesFromBase64(update), this.remoteOrigin);
    this.enqueueSnapshot();
  }

  integrateLocalChange(change) {
    this.applyDocument(change.after.title, change.after.document, this.localOrigin);
  }

  flushPendingLocalChanges(title, document) {
    this.applyDocument(title, document, this.localOrigin);
    return {
      title: this.title,
      updatedAt: null
    };
  }

  resolveRemoteCursor(cursor) {
    const mappingState = this.mappingState();
    const anchor = absoluteTextPosition(
      this.ydoc,
      this.fragment,
      cursor.cursor?.anchor,
      mappingState
    );
    const head = absoluteTextPosition(
      this.ydoc,
      this.fragment,
      cursor.cursor?.head,
      mappingState
    );
    if (!anchor || !head) return null;

    return {
      id: cursor.id,
      name: cursor.name,
      colorName: cursor.colorName,
      anchor,
      head
    };
  }

  encodeLocalAwarenessCursor(selection) {
    const mappingState = this.mappingState();
    const anchorPosition = absolutePositionFromTextPosition(selection.anchor, mappingState.textBlocks);
    const headPosition = absolutePositionFromTextPosition(selection.head, mappingState.textBlocks);
    if (anchorPosition === null || headPosition === null) return null;

    return {
      anchor: absolutePositionToRelativePosition(anchorPosition, this.fragment, mappingState.mapping),
      head: absolutePositionToRelativePosition(headPosition, this.fragment, mappingState.mapping)
    };
  }

  encodeInlineCommentSelection(selection) {
    const cursor = this.encodeLocalAwarenessCursor(selection);
    if (!cursor?.anchor || !cursor?.head) return null;

    return {
      anchor: selectionPositionFromRelativePosition(cursor.anchor),
      head: selectionPositionFromRelativePosition(cursor.head)
    };
  }

  drainLocalUpdates() {
    const updates = this.localUpdates;
    this.localUpdates = [];
    return updates;
  }

  drainDocumentSnapshots() {
    const snapshots = this.snapshots;
    this.snapshots = [];
    return snapshots;
  }

  applySeedDocument(title, document) {
    this.title = title;
    const seedDoc = new Y.Doc();
    seedDoc.clientID = seedClientID;
    const seedFragment = seedDoc.getXmlFragment(fragmentName);
    const nextDoc = schema.nodeFromJSON(normalizedDocument(document));
    const transactionTarget = {
      transact: (operation) => seedDoc.transact(operation, this.remoteOrigin)
    };
    updateYFragment(transactionTarget, seedFragment, nextDoc, mappingStateFor(seedFragment));
    Y.applyUpdate(this.ydoc, Y.encodeStateAsUpdate(seedDoc), this.remoteOrigin);
  }

  applyDocument(title, document, origin) {
    this.title = title;
    const nextDoc = schema.nodeFromJSON(normalizedDocument(document));
    const transactionTarget = {
      transact: (operation) => this.ydoc.transact(operation, origin)
    };
    updateYFragment(transactionTarget, this.fragment, nextDoc, this.mappingState());
  }

  enqueueSnapshot() {
    this.snapshots.push({
      title: this.title,
      document: yDocToProsemirrorJSON(this.ydoc, fragmentName),
      updatedAt: null
    });
  }

  mappingState() {
    return mappingStateFor(this.fragment);
  }
}

function mappingStateFor(fragment) {
  const state = initProseMirrorDoc(fragment, schema);
  return {
    mapping: state.mapping,
    isOMark: state.meta.isOMark,
    textBlocks: textBlocks(state.doc)
  };
}

function normalizedDocument(document) {
  if (!document || typeof document !== "object") {
    return { type: "doc", content: [{ type: "paragraph" }] };
  }
  if (document.type === "doc") {
    return document;
  }
  return { ...document, type: "doc" };
}

function textBlocks(inDocument) {
  const blocks = [];
  inDocument.descendants((node, position) => {
    if (isNativeTextBlock(node)) {
      blocks.push({
        start: position + 1,
        end: position + 1 + node.textContent.length
      });
      return false;
    }
    return true;
  });
  return blocks;
}

function isNativeTextBlock(node) {
  return node.type.name === "paragraph" ||
    node.type.name === "heading" ||
    node.type.name === "codeBlock";
}

function absolutePositionFromTextPosition(position, blocks) {
  if (!position) return null;
  const block = blocks[position.blockIndex];
  if (!block) return null;
  const offset = Math.max(0, Math.min(position.characterOffset, block.end - block.start));
  return block.start + offset;
}

function absoluteTextPosition(ydoc, fragment, relativePosition, mappingState) {
  if (!relativePosition) return null;
  const position = relativePositionToAbsolutePosition(
    ydoc,
    fragment,
    relativePosition,
    mappingState.mapping
  );
  if (position === null) return null;

  for (let index = 0; index < mappingState.textBlocks.length; index += 1) {
    const block = mappingState.textBlocks[index];
    if (position >= block.start && position <= block.end) {
      return {
        blockIndex: index,
        characterOffset: position - block.start
      };
    }
  }

  return null;
}

function selectionPositionFromRelativePosition(position) {
  return {
    type: requiredYID(position.type),
    tname: position.tname ?? fragmentName,
    item: optionalYID(position.item),
    assoc: position.assoc ?? 0
  };
}

function requiredYID(value) {
  const id = optionalYID(value);
  if (id) return id;
  return { client: 0, clock: 0 };
}

function optionalYID(value) {
  if (!value || typeof value.client !== "number" || typeof value.clock !== "number") {
    return null;
  }
  return {
    client: value.client,
    clock: value.clock
  };
}

function bytesFromBase64(base64) {
  if (!base64) return new Uint8Array();
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const cleaned = String(base64).replace(/=+$/, "");
  const bytes = [];
  let buffer = 0;
  let bits = 0;

  for (const char of cleaned) {
    const value = chars.indexOf(char);
    if (value < 0) continue;
    buffer = (buffer << 6) | value;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      bytes.push((buffer >> bits) & 0xff);
    }
  }

  return new Uint8Array(bytes);
}

function base64FromBytes(bytes) {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  let output = "";

  for (let index = 0; index < bytes.length; index += 3) {
    const first = bytes[index];
    const second = index + 1 < bytes.length ? bytes[index + 1] : 0;
    const third = index + 2 < bytes.length ? bytes[index + 2] : 0;
    const combined = (first << 16) | (second << 8) | third;

    output += chars[(combined >> 18) & 63];
    output += chars[(combined >> 12) & 63];
    output += index + 1 < bytes.length ? chars[(combined >> 6) & 63] : "=";
    output += index + 2 < bytes.length ? chars[combined & 63] : "=";
  }

  return output;
}
