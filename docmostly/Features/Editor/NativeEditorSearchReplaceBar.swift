import SwiftUI

struct NativeEditorSearchReplaceBar: View {
    @Bindable var viewModel: NativeRichEditorViewModel

    var body: some View {
        HStack(spacing: 8) {
            TextField("Find", text: $viewModel.searchQuery)
                .docmostlyTextInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            Text(viewModel.searchMatchSummary)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 48)

            Button("Previous", systemImage: "chevron.up", action: viewModel.selectPreviousSearchMatch)
                .labelStyle(.iconOnly)

            Button("Next", systemImage: "chevron.down", action: viewModel.selectNextSearchMatch)
                .labelStyle(.iconOnly)

            TextField("Replace", text: $viewModel.replacementText)
                .docmostlyTextInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            Button("Replace", systemImage: "arrow.triangle.2.circlepath", action: viewModel.replaceCurrentSearchMatch)
                .labelStyle(.iconOnly)

            Button("All", systemImage: "text.badge.checkmark", action: viewModel.replaceAllSearchMatches)
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 10)
    }
}
