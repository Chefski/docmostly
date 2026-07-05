import SwiftUI

struct PageHistoryVersionHeader: View {
    let version: DocmostPageHistory
    let canRestore: Bool
    let isRestoring: Bool
    let restore: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            DocmostlyGlassPanel(cornerRadius: 16) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(version.title.isEmpty ? "Untitled" : version.title)
                            .font(.title3)
                            .bold()
                            .lineLimit(2)

                        Text(versionSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Restore", systemImage: "arrow.counterclockwise", action: restore)
                        .buttonStyle(.glassProminent)
                        .disabled(canRestore == false || isRestoring)
                }
                .padding()
            }
        }
    }

    private var versionSubtitle: String {
        let editor = version.lastUpdatedBy?.name ?? "Unknown editor"
        guard let createdAt = version.createdAt else {
            return "\(version.versionLabel) by \(editor)"
        }

        let savedAt = createdAt.formatted(date: .abbreviated, time: .shortened)
        return "\(version.versionLabel) by \(editor) on \(savedAt)"
    }
}
