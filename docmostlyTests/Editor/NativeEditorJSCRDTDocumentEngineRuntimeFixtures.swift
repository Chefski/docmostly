extension NativeEditorJSCRDTEngineTests {
    func requiredRuntimeSource(missing omittedFunction: String) -> String {
        let functions = [
            "encodeStateVector": "encodeStateVector() { return \"\"; }",
            "encodeStateAsUpdate": "encodeStateAsUpdate() { return \"\"; }",
            "applyRemoteUpdate": "applyRemoteUpdate() {}",
            "integrateLocalChange": "integrateLocalChange() {}",
            "flushPendingLocalChanges": "flushPendingLocalChanges() { return { title: null, updatedAt: null }; }",
            "resolveRemoteCursor": "resolveRemoteCursor() { return null; }",
            "encodeLocalAwarenessCursor": "encodeLocalAwarenessCursor() { return null; }",
            "encodeInlineCommentSelection": "encodeInlineCommentSelection() { return null; }",
            "drainLocalUpdates": "drainLocalUpdates() { return []; }",
            "drainDocumentSnapshots": "drainDocumentSnapshots() { return []; }"
        ]
        let runtimeFunctions = functions
            .filter { key, _ in key != omittedFunction }
            .sorted { $0.key < $1.key }
            .map(\.value)
            .joined(separator: ",\n")

        return """
        globalThis.docmostlyCRDT = {
          createDocument() {
            return {
              \(runtimeFunctions)
            };
          }
        };
        """
    }

    static let runtimeSource = """
    globalThis.docmostlyCRDT = {
      createDocument(seed) {
        return {
          encodeStateVector() {
            if (
              seed.pageID === "page-1" &&
              seed.title === "Page" &&
              seed.document.content[0].content[0].text === "Seed"
            ) {
              return "AQID";
            }
            return "";
          },
          encodeStateAsUpdate(stateVector) {
            if (stateVector === "CQg=") {
              return "BwYF";
            }
            return "";
          },
          applyRemoteUpdate(update) {
            if (update === "CAc=") {
              this.snapshots.push({
                title: "Remote",
                updatedAt: "1970-01-01T00:00:20Z",
                document: {
                  type: "doc",
                  content: [{
                    type: "paragraph",
                    content: [{ type: "text", text: "Merged" }]
                  }]
                }
              });
            }
          },
          integrateLocalChange(change) {
            if (
              change.before.document.content[0].content[0].text === "Seed" &&
              change.after.document.content[0].content[0].text === "Edited"
            ) {
              this.localUpdates.push("BAUG");
            }
          },
          flushPendingLocalChanges(title, document) {
            return {
              title: title.trim(),
              updatedAt: "1970-01-01T00:00:30Z"
            };
          },
          resolveRemoteCursor(cursor) {
            if (cursor.id === "user-2" && cursor.cursor.anchor === null) {
              return {
                id: cursor.id,
                name: cursor.name,
                colorName: cursor.colorName,
                anchor: { blockIndex: 1, characterOffset: 2 },
                head: { blockIndex: 1, characterOffset: 6 }
              };
            }
            return null;
          },
          encodeLocalAwarenessCursor(selection) {
            if (selection.anchor.characterOffset === 1 && selection.head.characterOffset === 3) {
              return {
                anchor: { type: "text", tname: "default", item: { client: 1, clock: 10 }, assoc: 0 },
                head: { type: "text", tname: "default", item: { client: 1, clock: 12 }, assoc: 0 }
              };
            }
            return null;
          },
          encodeInlineCommentSelection(selection) {
            if (selection.anchor.characterOffset === 2 && selection.head.characterOffset === 5) {
              return {
                anchor: { type: { client: 1, clock: 20 }, tname: "default", item: null, assoc: 0 },
                head: { type: { client: 1, clock: 25 }, tname: "default", item: null, assoc: 0 }
              };
            }
            return null;
          },
          drainLocalUpdates() {
            const updates = this.localUpdates;
            this.localUpdates = [];
            return updates;
          },
          drainDocumentSnapshots() {
            const snapshots = this.snapshots;
            this.snapshots = [];
            return snapshots;
          },
          localUpdates: [],
          snapshots: []
        };
      }
    };
    """
}
