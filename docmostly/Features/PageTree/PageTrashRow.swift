import SwiftUI

struct PageTrashRow: View {
    @Environment(AppState.self) private var appState

    let page: DocmostPage
    let viewModel: PageTreeViewModel

    var body: some View {
        HStack {
            Text(page.icon?.isEmpty == false ? page.icon ?? "" : "📄")
            VStack(alignment: .leading) {
                Text(page.title.isEmpty ? "Untitled" : page.title)
                if let deletedAt = page.deletedAt {
                    Text(deletedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Menu("Actions", systemImage: "ellipsis.circle") {
                Button("Restore", systemImage: "arrow.uturn.backward") {
                    restore()
                }
                Button("Delete Forever", systemImage: "trash", role: .destructive) {
                    permanentlyDelete()
                }
            }
            .labelStyle(.iconOnly)
        }
    }

    private func restore() {
        Task {
            await viewModel.restorePage(page, appState: appState)
        }
    }

    private func permanentlyDelete() {
        Task {
            await viewModel.permanentlyDeletePage(page, appState: appState)
        }
    }
}
