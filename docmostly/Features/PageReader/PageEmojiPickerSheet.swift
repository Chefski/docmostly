import SwiftUI

struct PageEmojiPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PageEmojiPickerViewModel()
    @FocusState private var isSearchFocused: Bool
    @ScaledMetric(relativeTo: .title2) private var minimumCellSize: CGFloat = 44

    let editorViewModel: NativeRichEditorViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.visibleSections.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    LazyVStack(alignment: .leading) {
                        ForEach(viewModel.visibleSections) { section in
                            PageEmojiPickerSectionView(
                                section: section,
                                selectedEmoji: editorViewModel.icon,
                                minimumCellSize: minimumCellSize,
                                isDisabled: viewModel.isSaving,
                                select: select
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Choose Emoji")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $viewModel.searchText, prompt: "Search emoji")
            .searchFocused($isSearchFocused)
            .defaultFocus($isSearchFocused, true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if viewModel.isSaving {
                    ProgressView("Saving emoji")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .alert("Could Not Change Emoji", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .presentationDetents([.large])
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private func select(_ item: EmojiCatalogItem) {
        guard viewModel.beginSaving() else { return }

        Task {
            do {
                let page = try await appState.updatePageIcon(
                    pageId: editorViewModel.currentPageID,
                    icon: item.emoji
                )
                editorViewModel.icon = page.icon ?? item.emoji
                viewModel.finishSaving()
                dismiss()
            } catch {
                viewModel.finishSaving(error: error)
            }
        }
    }
}

private struct PageEmojiPickerSectionView: View {
    let section: EmojiCatalogSection
    let selectedEmoji: String?
    let minimumCellSize: CGFloat
    let isDisabled: Bool
    let select: (EmojiCatalogItem) -> Void

    var body: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumCellSize))]) {
                ForEach(section.items) { item in
                    Button {
                        select(item)
                    } label: {
                        Text(item.emoji)
                            .font(.title)
                            .frame(maxWidth: .infinity, minHeight: minimumCellSize)
                            .background(
                                selectedEmoji == item.emoji ? Color.accentColor.opacity(0.16) : .clear,
                                in: .rect(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    .accessibilityLabel(item.name)
                    .accessibilityAddTraits(selectedEmoji == item.emoji ? .isSelected : [])
                }
            }
        } header: {
            Text(section.name)
                .font(.headline)
                .padding(.top)
        }
    }
}
