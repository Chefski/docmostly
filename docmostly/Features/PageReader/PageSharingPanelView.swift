import SwiftUI

struct PageSharingPanelView: View {
    @Bindable var viewModel: PageReaderViewModel

    let canEdit: Bool
    let hasPageRestriction: Bool
    let workspaceSharingDisabled: Bool
    let spaceSharingDisabled: Bool
    let publicShareURL: URL?
    let setPublicSharing: (Bool) async -> Void
    let updateShareOptions: (Bool?, Bool?) async -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                publicSharingSection
                restrictionSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var publicSharingSection: some View {
        DocmostlyGlassPanel(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Public Sharing", systemImage: publicSharingIcon)
                    .font(.headline)

                Text(publicSharingDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let share = viewModel.pageShare, share.isInheritedShare {
                    inheritedShareView(share)
                } else {
                    Toggle("Shared to web", isOn: publicSharingBinding)
                        .disabled(publicSharingToggleDisabled)

                    if let publicShareURL, viewModel.pageShare?.isDirectShare == true {
                        Link(destination: publicShareURL) {
                            Label("Open public page", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)

                        Toggle("Include sub-pages", isOn: includeSubPagesBinding)
                            .disabled(viewModel.isUpdatingShare || canEdit == false)

                        Toggle("Search engine indexing", isOn: searchIndexingBinding)
                            .disabled(viewModel.isUpdatingShare || canEdit == false)
                    }
                }

                if viewModel.isUpdatingShare || viewModel.isLoadingSharingState {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(14)
        }
    }

    private var restrictionSection: some View {
        DocmostlyGlassPanel(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Page Access", systemImage: restrictionIcon)
                    .font(.headline)

                Text(restrictionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let inheritedFrom = viewModel.pageRestrictionInfo?.inheritedFrom {
                    LabeledContent(
                        "Inherited from",
                        value: inheritedFrom.title.isEmpty ? "Untitled" : inheritedFrom.title
                    )
                }

                if viewModel.pagePermissionMembers.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("People and groups")
                            .font(.subheadline)
                            .bold()

                        ForEach(viewModel.pagePermissionMembers) { member in
                            PagePermissionMemberRow(member: member)
                        }
                    }
                }

                if viewModel.pageRestrictionInfo == nil, hasPageRestriction {
                    Text("""
                    Detailed page permission data is unavailable from this server, \
                    but Docmost reports that this page is restricted.
                    """)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
    }

    private func inheritedShareView(_ share: DocmostPageShare) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Inherits public sharing from")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(share.sharedPage?.title ?? "Ancestor page", systemImage: "arrow.triangle.branch")
                .font(.subheadline)

            if let publicShareURL {
                Link(destination: publicShareURL) {
                    Label("Open public page", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var publicSharingBinding: Binding<Bool> {
        Binding {
            viewModel.pageShare != nil
        } set: { isEnabled in
            Task {
                await setPublicSharing(isEnabled)
            }
        }
    }

    private var includeSubPagesBinding: Binding<Bool> {
        Binding {
            viewModel.pageShare?.includeSubPages == true
        } set: { value in
            Task {
                await updateShareOptions(value, nil)
            }
        }
    }

    private var searchIndexingBinding: Binding<Bool> {
        Binding {
            viewModel.pageShare?.searchIndexing == true
        } set: { value in
            Task {
                await updateShareOptions(nil, value)
            }
        }
    }

    private var publicSharingToggleDisabled: Bool {
        canEdit == false ||
            hasPageRestriction ||
            workspaceSharingDisabled ||
            spaceSharingDisabled ||
            viewModel.isUpdatingShare ||
            viewModel.pageShare?.isInheritedShare == true
    }

    private var publicSharingIcon: String {
        viewModel.pageShare == nil ? "globe.badge.chevron.backward" : "globe"
    }

    private var publicSharingDescription: String {
        if workspaceSharingDisabled {
            return "Public sharing is disabled at the workspace level."
        }
        if spaceSharingDisabled {
            return "Public sharing is disabled for this space."
        }
        if hasPageRestriction {
            return "Restricted pages cannot be shared publicly."
        }
        if canEdit == false {
            return "You can view sharing state, but Docmost does not allow you to change it."
        }
        if viewModel.pageShare?.isInheritedShare == true {
            return "Anyone with the inherited public link can view this page."
        }
        return viewModel.pageShare == nil
            ? "Make this page publicly accessible with a Docmost share link."
            : "Anyone with the link can view this page."
    }

    private var restrictionIcon: String {
        hasPageRestriction ? "lock.shield" : "lock.open"
    }

    private var restrictionDescription: String {
        guard let info = viewModel.pageRestrictionInfo else {
            return hasPageRestriction
                ? "This page has Docmost restrictions."
                : "Everyone with space access can view this page."
        }

        if info.hasDirectRestriction {
            return info.userAccess.canManage
                ? """
                This page has direct access restrictions. Manage them in Docmost web until the server \
                exposes stable native routes.
                """
                : "This page has direct access restrictions."
        }

        if info.hasInheritedRestriction {
            return "Access is limited by an ancestor page."
        }

        return "Everyone with space access can view this page."
    }
}

private struct PagePermissionMemberRow: View {
    let member: DocmostPagePermissionMember

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: member.type == .group ? "person.3" : "person")
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline)

                Text(memberSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(member.role.rawValue.capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: .capsule)
        }
    }

    private var memberSubtitle: String {
        if let email = member.email {
            return email
        }
        if let memberCount = member.memberCount {
            return "\(memberCount.formatted()) members"
        }
        return member.type.rawValue.capitalized
    }
}
