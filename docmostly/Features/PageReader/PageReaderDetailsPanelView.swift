import SwiftUI

struct PageReaderDetailsPanelView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: PageReaderViewModel
    let editorViewModel: NativeRichEditorViewModel
    let pageID: String
    let canEdit: Bool

    @State private var isShowingLabelEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageDetailsPeopleSection(
                    creator: editorViewModel.creator,
                    lastUpdatedBy: editorViewModel.lastUpdatedBy
                )

                Divider()

                PageDetailsStatsSection(
                    stats: PageReaderDetailStats.stats(in: editorViewModel.document),
                    createdAt: editorViewModel.createdAt,
                    updatedAt: editorViewModel.updatedAt
                )

                Divider()

                PageDetailsBacklinksSection(
                    counts: viewModel.backlinkCounts
                )

                Divider()

                PageDetailsLabelsSection(
                    labels: viewModel.labels,
                    canEdit: canEdit,
                    showLabelEditor: { isShowingLabelEditor = true }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $isShowingLabelEditor) {
            PageLabelEditorSheet(pageID: pageID, viewModel: viewModel)
        }
        .navigationDestination(for: DocmostBacklinkDirection.self) { direction in
            PageReaderBacklinksListView(
                viewModel: viewModel,
                pageID: pageID,
                direction: direction,
                selectPage: selectBacklinkPage
            )
            .navigationTitle(direction.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private func selectBacklinkPage(_ page: DocmostBacklinkPage) {
        appState.selectPage(id: page.slugId, spaceID: page.spaceId, revealSpaceInSidebar: true)
    }
}

private struct PageDetailsPeopleSection: View {
    let creator: DocmostPagePerson?
    let lastUpdatedBy: DocmostPagePerson?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageDetailsPersonRow(label: "Created by", person: creator)
            PageDetailsPersonRow(label: "Last updated by", person: lastUpdatedBy)
        }
    }
}

private struct PageDetailsPersonRow: View {
    let label: String
    let person: DocmostPagePerson?

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if let person {
                HStack(spacing: 6) {
                    PageDetailsAvatarView(name: person.name)
                    Text(person.name)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            } else {
                Text("Unknown")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct PageDetailsAvatarView: View {
    let name: String

    var body: some View {
        ZStack {
            DocmostlyTheme.primary.opacity(0.12)
            Text(initials)
                .font(.caption2)
                .bold()
                .foregroundStyle(DocmostlyTheme.primary)
        }
        .frame(width: 22, height: 22)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private var initials: String {
        let parts = name
            .split { $0.isWhitespace || $0.isNewline }
            .prefix(2)
            .compactMap(\.first)
        let value = String(parts).uppercased()
        return value.isEmpty ? "?" : value
    }
}

private struct PageDetailsStatsSection: View {
    let stats: PageReaderDetailStats
    let createdAt: Date?
    let updatedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageDetailsSectionTitle("Stats")
            PageDetailsValueRow(label: "Word count", value: stats.wordCount.formatted(.number))
            PageDetailsValueRow(label: "Characters", value: stats.characterCount.formatted(.number))
            PageDetailsValueRow(label: "Created", value: formattedDate(createdAt))
            PageDetailsValueRow(label: "Last updated", value: formattedDate(updatedAt))
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Unknown" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct PageDetailsBacklinksSection: View {
    let counts: DocmostBacklinkCounts

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PageDetailsSectionTitle("Backlinks")
            PageDetailsBacklinkRow(label: "Incoming links", count: counts.incoming, direction: .incoming)
            PageDetailsBacklinkRow(label: "Outgoing links", count: counts.outgoing, direction: .outgoing)
        }
    }
}

private struct PageDetailsBacklinkRow: View {
    let label: String
    let count: Int
    let direction: DocmostBacklinkDirection

    var body: some View {
        NavigationLink(value: direction) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(count.formatted(.number))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct PageDetailsLabelsSection: View {
    let labels: [DocmostLabel]
    let canEdit: Bool
    let showLabelEditor: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PageDetailsSectionTitle("Labels")
                Spacer(minLength: 0)
                if canEdit {
                    Button(labels.isEmpty ? "Add label" : "Add", systemImage: "plus", action: showLabelEditor)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            if labels.isEmpty {
                Text("No labels yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(labels) { label in
                        Text(label.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: .rect(cornerRadius: 6))
                    }
                }
            }
        }
    }
}

private struct PageDetailsValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct PageDetailsSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption)
            .bold()
            .foregroundStyle(.secondary)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > 0, origin.x + size.width > width {
                origin.x = 0
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: origin.y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct PageReaderBacklinksListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: PageReaderViewModel
    let pageID: String
    let direction: DocmostBacklinkDirection
    let selectPage: (DocmostBacklinkPage) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if isLoadingInitial {
                    ProgressView("Loading links")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if pages.isEmpty {
                    Text(direction.emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    ForEach(pages) { page in
                        Button {
                            selectPage(page)
                            dismiss()
                        } label: {
                            PageReaderBacklinkRow(page: page)
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.backlinkHasNextPageByDirection[direction] == true {
                        Button("Load more", systemImage: "arrow.down.circle") {
                            Task {
                                await viewModel.loadMoreBacklinks(
                                    pageID: pageID,
                                    direction: direction,
                                    appState: appState
                                )
                            }
                        }
                        .disabled(viewModel.loadingBacklinkDirections.contains(direction))
                        .frame(maxWidth: .infinity)
                    }
                }

                if let errorMessage = viewModel.backlinkErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: direction) {
            await viewModel.loadBacklinks(pageID: pageID, direction: direction, appState: appState, reset: true)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var pages: [DocmostBacklinkPage] {
        viewModel.backlinkPagesByDirection[direction] ?? []
    }

    private var isLoadingInitial: Bool {
        pages.isEmpty && viewModel.loadingBacklinkDirections.contains(direction)
    }
}

private struct PageReaderBacklinkRow: View {
    let page: DocmostBacklinkPage

    var body: some View {
        HStack(spacing: 10) {
            Text(page.icon?.isEmpty == false ? page.icon ?? "📄" : "📄")
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(page.title?.isEmpty == false ? page.title ?? "Untitled" : "Untitled")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let spaceName = page.space?.name, spaceName.isEmpty == false {
                    Text(spaceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }
}
