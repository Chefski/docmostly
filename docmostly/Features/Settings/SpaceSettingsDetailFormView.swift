import SwiftUI

struct SpaceSettingsDetailFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SpaceSettingsViewModel
    let canManage: Bool
    let showsCloseButton: Bool
    @State private var selectedTab = SpaceSettingsTab.settings
    @State private var memberSearchText = ""
    @State private var isConfirmingDelete = false
    @State private var isShowingAddMembers = false

    var body: some View {
        VStack(spacing: 0) {
            SpaceSettingsTabBar(selection: $selectedTab)

            Divider()

            selectedTabContent
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(viewModel.space.name)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", action: close)
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark", action: save)
                    .disabled(viewModel.canSave == false || viewModel.isSaving || canManage == false)
            }
        }
        .task(id: viewModel.space.id) {
            await viewModel.loadMembers(appState: appState)
            await viewModel.loadWatchStatus(appState: appState)
        }
        .confirmationDialog("Delete Space", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive, action: deleteSpace)
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $isShowingAddMembers) {
            SpaceAddMembersSheet(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .settings:
            settingsTab
        case .members:
            membersTab
        case .security:
            securityTab
        }
    }

    private var settingsTab: some View {
        SpaceSettingsPanelScrollView {
            VStack(alignment: .leading, spacing: SpaceSettingsDialogMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: SpaceSettingsDialogMetrics.rowSpacing) {
                    Text("Details")
                        .font(.headline)

                    SpaceSettingsLabeledRow(title: "Icon") {
                        SpaceIconView(space: viewModel.space, size: 44)
                    }

                    SpaceSettingsLabeledRow(title: "Name") {
                        TextField("Name", text: $viewModel.draft.name)
                            .docmostlyTextInputAutocapitalization(.words)
                            .onChange(of: viewModel.draft.name) { _, newValue in
                                viewModel.draft.setName(newValue)
                            }
                    }

                    SpaceSettingsLabeledRow(title: "Slug") {
                        TextField("Slug", text: $viewModel.draft.slug)
                            .docmostlyTextInputAutocapitalization(.never)
                    }

                    SpaceSettingsLabeledRow(title: "Description") {
                        TextField("Description", text: $viewModel.draft.description, axis: .vertical)
                            .lineLimit(2...)
                    }
                }
                .disabled(canManage == false)

                Divider()

                VStack(alignment: .leading, spacing: SpaceSettingsDialogMetrics.rowSpacing) {
                    Text("Notifications")
                        .font(.headline)

                    Toggle("Watch this space", isOn: watchingSpaceBinding)
                        .disabled(viewModel.isLoadingWatchStatus || viewModel.isTogglingWatch)

                    if viewModel.isLoadingWatchStatus || viewModel.isTogglingWatch {
                        ProgressView(viewModel.isLoadingWatchStatus ? "Loading watch status" : "Updating watch status")
                    }
                }

                statusMessageView

                if canManage {
                    Divider()

                    Button("Delete Space", systemImage: "trash", role: .destructive, action: confirmDelete)
                }
            }
        }
    }

    private var membersTab: some View {
        SpaceSettingsPanelScrollView(maxHeight: 420) {
            VStack(alignment: .leading, spacing: SpaceSettingsDialogMetrics.rowSpacing) {
                HStack {
                    TextField("Search members", text: $memberSearchText)
                        .docmostlyTextInputAutocapitalization(.never)

                    Spacer(minLength: 12)

                    Button("Add Members", systemImage: "person.badge.plus", action: showAddMembers)
                        .disabled(canManage == false)
                }

                if viewModel.isLoading {
                    ProgressView("Loading members")
                }

                VStack(spacing: 0) {
                    ForEach(viewModel.filteredMembers(query: memberSearchText)) { member in
                        SpaceMemberRowView(
                            member: member,
                            canManage: canManage,
                            changeRole: changeRole,
                            remove: removeMember
                        )
                        .padding(.vertical, 8)

                        Divider()
                    }

                    if viewModel.members.isEmpty, viewModel.isLoading == false {
                        Label("No Members", systemImage: "person.2")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                }

                statusMessageView
            }
        }
    }

    private var securityTab: some View {
        SpaceSettingsPanelScrollView {
            VStack(alignment: .leading, spacing: SpaceSettingsDialogMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: SpaceSettingsDialogMetrics.sectionSpacing) {
                    Toggle(isOn: $viewModel.draft.disablePublicSharing) {
                        VStack(alignment: .leading) {
                            Text("Disable public sharing")
                            Text("Prevent pages in this space from being shared publicly.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $viewModel.draft.allowViewerComments) {
                        VStack(alignment: .leading) {
                            Text("Allow viewers to comment")
                            Text("Allow viewers to add comments on pages in this space.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(canManage == false)

                statusMessageView
            }
        }
    }

    @ViewBuilder
    private var statusMessageView: some View {
        if let message = viewModel.errorMessage {
            SettingsStatusMessageView(message: message, isError: true)
        } else if let message = viewModel.statusMessage {
            SettingsStatusMessageView(message: message, isError: false)
        }
    }

    private func save() {
        Task {
            _ = await viewModel.save(appState: appState)
        }
    }

    private func close() {
        dismiss()
    }

    private var watchingSpaceBinding: Binding<Bool> {
        Binding {
            viewModel.isWatchingSpace
        } set: { shouldWatch in
            Task {
                await viewModel.setWatchingSpace(shouldWatch, appState: appState)
            }
        }
    }

    private func changeRole(_ member: DocmostSpaceMember, _ role: String) {
        Task {
            await viewModel.changeMemberRole(member, role: role, appState: appState)
        }
    }

    private func removeMember(_ member: DocmostSpaceMember) {
        Task {
            await viewModel.removeMember(member, appState: appState)
        }
    }

    private func showAddMembers() {
        isShowingAddMembers = true
    }

    private func confirmDelete() {
        isConfirmingDelete = true
    }

    private func deleteSpace() {
        Task {
            let deleted = await viewModel.delete(appState: appState)
            if deleted {
                dismiss()
            }
        }
    }
}

private enum SpaceSettingsTab: CaseIterable, Identifiable {
    case settings
    case members
    case security

    var id: Self { self }

    var title: String {
        switch self {
        case .settings:
            "Settings"
        case .members:
            "Members"
        case .security:
            "Security"
        }
    }
}

private struct SpaceSettingsTabBar: View {
    @Binding var selection: SpaceSettingsTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SpaceSettingsTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Text(tab.title)
                        .font(selection == tab ? .headline : .body)
                        .frame(minWidth: 96)
                        .padding(.vertical, 11)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == tab ? .primary : .secondary)
                .overlay(alignment: .bottom) {
                    if selection == tab {
                        Rectangle()
                            .fill(.primary)
                            .frame(height: 2)
                    }
                }
                .accessibilityValue(selection == tab ? "Selected" : "")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.top, 22)
    }
}

private struct SpaceSettingsPanelScrollView<Content: View>: View {
    let maxHeight: CGFloat?
    @ViewBuilder let content: Content

    init(maxHeight: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.maxHeight = maxHeight
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 32)
                .padding(.top, 18)
                .padding(.bottom, 24)
        }
        .frame(maxHeight: maxHeight)
        .fixedSize(horizontal: false, vertical: maxHeight == nil)
    }
}

private struct SpaceSettingsLabeledRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .frame(width: SpaceSettingsDialogMetrics.labelWidth, alignment: .trailing)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum SpaceSettingsDialogMetrics {
    static let labelWidth: CGFloat = 104
    static let rowSpacing: CGFloat = 10
    static let sectionSpacing: CGFloat = 16
}
