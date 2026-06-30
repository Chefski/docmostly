import Foundation

enum NativeEditorBasicFixtures {
    static var docmostBlocks: Data {
        Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "heading",
              "attrs": { "level": 2, "textAlign": "center" },
              "content": [
                { "type": "text", "text": "Plan", "marks": [{ "type": "bold" }] }
              ]
            },
            {
              "type": "paragraph",
              "content": [
                { "type": "text", "text": "Visit ", "marks": [{ "type": "italic" }] },
                {
                  "type": "text",
                  "text": "Docmost",
                  "marks": [
                    { "type": "link", "attrs": { "href": "https://docmost.com" } }
                  ]
                }
              ]
            },
            {
              "type": "bulletList",
              "content": [
                {
                  "type": "listItem",
                  "content": [
                    {
                      "type": "paragraph",
                      "content": [{ "type": "text", "text": "First" }]
                    }
                  ]
                }
              ]
            },
            { "type": "table", "content": [] }
          ]
        }
        """.utf8)
    }
}

enum NativeEditorRichBlockFixtures {
    static var richBlocks: Data {
        Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "table",
              "content": [
                {
                  "type": "tableRow",
                  "content": [
                    {
                      "type": "tableHeader",
                      "attrs": { "colwidth": [210] },
                      "content": [
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Feature" }]
                        }
                      ]
                    },
                    {
                      "type": "tableHeader",
                      "attrs": { "colwidth": [240] },
                      "content": [
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Status" }]
                        }
                      ]
                    }
                  ]
                },
                {
                  "type": "tableRow",
                  "content": [
                    {
                      "type": "tableCell",
                      "attrs": { "backgroundColorName": "gray", "colwidth": [210] },
                      "content": [
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Native editor" }]
                        }
                      ]
                    },
                    {
                      "type": "tableCell",
                      "attrs": { "colwidth": [240] },
                      "content": [
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "In progress" }]
                        }
                      ]
                    }
                  ]
                }
              ]
            },
            {
              "type": "image",
              "attrs": {
                "src": "/files/image.png",
                "alt": "Architecture",
                "width": "75%",
                "height": 320,
                "align": "center",
                "attachmentId": "image-1",
                "size": 2048,
                "aspectRatio": 1.6
              }
            },
            {
              "type": "video",
              "attrs": {
                "src": "/files/video.mp4",
                "alt": "Demo",
                "title": "Launch demo.mp4",
                "attachmentId": "video-1",
                "size": 4096,
                "align": "left"
              }
            },
            {
              "type": "audio",
              "attrs": {
                "src": "/files/audio.m4a",
                "attachmentId": "audio-1",
                "size": 1024
              }
            },
            {
              "type": "pdf",
              "attrs": {
                "src": "/files/spec.pdf",
                "name": "Spec.pdf",
                "attachmentId": "pdf-1",
                "size": 8192,
                "width": 800,
                "height": 600
              }
            },
            {
              "type": "attachment",
              "attrs": {
                "url": "/files/archive.zip",
                "name": "Archive.zip",
                "mime": "application/zip",
                "size": 512,
                "attachmentId": "file-1"
              }
            },
            {
              "type": "callout",
              "attrs": { "type": "warning", "icon": "triangle-alert" },
              "content": [
                {
                  "type": "paragraph",
                  "content": [{ "type": "text", "text": "Check migration plan" }]
                }
              ]
            },
            {
              "type": "details",
              "attrs": { "open": true },
              "content": [
                {
                  "type": "detailsSummary",
                  "content": [{ "type": "text", "text": "Release checklist" }]
                },
                {
                  "type": "detailsContent",
                  "content": [
                    {
                      "type": "paragraph",
                      "content": [{ "type": "text", "text": "QA on simulator" }]
                    }
                  ]
                }
              ]
            },
            { "type": "pageBreak" },
            { "type": "horizontalRule" },
            {
              "type": "columns",
              "attrs": { "layout": "two_equal", "widthMode": "wide" },
              "content": [
                {
                  "type": "column",
                  "attrs": { "width": 1 },
                  "content": [
                    {
                      "type": "paragraph",
                      "content": [{ "type": "text", "text": "Left" }]
                    }
                  ]
                },
                {
                  "type": "column",
                  "attrs": { "width": 1 },
                  "content": [
                    {
                      "type": "paragraph",
                      "content": [{ "type": "text", "text": "Right" }]
                    }
                  ]
                }
              ]
            },
            { "type": "subpages" },
            {
              "type": "transclusionSource",
              "attrs": { "id": "sync-1" },
              "content": [
                {
                  "type": "paragraph",
                  "content": [{ "type": "text", "text": "Shared" }]
                }
              ]
            },
            {
              "type": "transclusionReference",
              "attrs": { "sourcePageId": "page-1", "transclusionId": "sync-1" }
            },
            {
              "type": "embed",
              "attrs": {
                "src": "https://youtube.com/watch?v=abc",
                "provider": "YouTube",
                "align": "center",
                "width": 800,
                "height": 450
              }
            },
            {
              "type": "drawio",
              "attrs": {
                "src": "/files/flow.drawio.svg",
                "title": "Flow",
                "alt": "Flow diagram",
                "attachmentId": "draw-1",
                "width": "80%",
                "height": 420,
                "align": "center"
              }
            },
            {
              "type": "excalidraw",
              "attrs": {
                "src": "/files/sketch.svg",
                "title": "Sketch",
                "alt": "Sketch",
                "attachmentId": "exc-1",
                "width": "70%",
                "height": 360,
                "align": "right"
              }
            },
            { "type": "mathBlock", "attrs": { "text": "E = mc^2" } },
            {
              "type": "codeBlock",
              "attrs": { "language": "mermaid" },
              "content": [{ "type": "text", "text": "graph TD; A-->B" }]
            }
          ]
        }
        """.utf8)
    }
}

enum NativeEditorInlineFixtures {
    static var richInline: Data {
        Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "paragraph",
              "attrs": { "id": "richinlineid" },
              "content": [
                {
                  "type": "text",
                  "text": "Styled",
                  "marks": [
                    { "type": "underline" },
                    {
                      "type": "highlight",
                      "attrs": { "color": "#faf594", "colorName": "yellow" }
                    },
                    { "type": "textStyle", "attrs": { "color": "#2563EB" } },
                    {
                      "type": "comment",
                      "attrs": { "commentId": "comment-1", "resolved": false }
                    }
                  ]
                },
                { "type": "text", "text": " " },
                {
                  "type": "mention",
                  "attrs": {
                    "id": "mention-1",
                    "label": "Roadmap",
                    "entityType": "page",
                    "entityId": "page-1",
                    "slugId": "roadmap-abc",
                    "creatorId": "user-1",
                    "anchorId": "heading-1"
                  }
                },
                { "type": "text", "text": " " },
                { "type": "status", "attrs": { "text": "Ship", "color": "green" } },
                { "type": "text", "text": " " },
                { "type": "mathInline", "attrs": { "text": "x^2" } }
              ]
            }
          ]
        }
        """.utf8)
    }
}

enum NativeEditorNestedListFixtures {
    static var nestedBulletList: Data {
        Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "bulletList",
              "content": [
                {
                  "type": "listItem",
                  "content": [
                    {
                      "type": "paragraph",
                      "attrs": { "id": "parentnodeid" },
                      "content": [{ "type": "text", "text": "Parent" }]
                    },
                    {
                      "type": "bulletList",
                      "content": [
                        {
                          "type": "listItem",
                          "content": [
                            {
                              "type": "paragraph",
                              "attrs": { "id": "childnodeidx" },
                              "content": [{ "type": "text", "text": "Child" }]
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.utf8)
    }
}
