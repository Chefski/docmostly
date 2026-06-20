import Foundation
import Observation

@MainActor
@Observable
final class SpaceSettingsViewModel {
    var space: DocmostSpace
    var draft: SpaceSettingsDraft
    var members: [DocmostSpaceMember] = []
    var isLoading = false
    var isSaving = false
    var isDeleting = false
    var errorMessage: String?
    var statusMessage: String?

    init(space: DocmostSpace) {
        self.space = space
        draft = SpaceSettingsDraft(space: space)
    }

    var canSave: Bool {
        draft.validationMessage == nil && draft.hasChanges(comparedTo: space)
    }

    func loadMembers(appState: AppState) async {
        isLoading = true
        clearMessages()
        defer { isLoading = false }

        do {
            members = try await appState.loadSpaceMembers(spaceId: space.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(appState: AppState) async -> Bool {
        if let validationMessage = draft.validationMessage {
            errorMessage = validationMessage
            return false
        }

        let update = draft.updateValues(comparedTo: space)
        guard update.hasChanges else { return true }

        isSaving = true
        clearMessages()
        defer { isSaving = false }

        do {
            let updated = try await appState.updateSpace(
                spaceId: space.id,
                update: update
            )
            space = updated
            draft = SpaceSettingsDraft(space: updated)
            statusMessage = "Space updated."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(appState: AppState) async -> Bool {
        isDeleting = true
        clearMessages()
        defer { isDeleting = false }

        do {
            try await appState.deleteSpace(spaceId: space.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func changeMemberRole(_ member: DocmostSpaceMember, role: String, appState: AppState) async {
        guard role != member.role else { return }

        await saveMemberChange(appState: appState, successMessage: "Member role updated.") {
            try await appState.changeSpaceMemberRole(
                spaceId: space.id,
                role: role,
                userId: member.type == "user" ? member.id : nil,
                groupId: member.type == "group" ? member.id : nil
            )
        }
    }

    func removeMember(_ member: DocmostSpaceMember, appState: AppState) async {
        await saveMemberChange(appState: appState, successMessage: "Member removed.") {
            try await appState.removeSpaceMember(
                spaceId: space.id,
                userId: member.type == "user" ? member.id : nil,
                groupId: member.type == "group" ? member.id : nil
            )
        }
    }

    func addMembers(role: String, userIds: [String], groupIds: [String], appState: AppState) async -> Bool {
        guard userIds.isEmpty == false || groupIds.isEmpty == false else {
            errorMessage = "Select at least one user or group."
            return false
        }

        isSaving = true
        clearMessages()
        defer { isSaving = false }

        do {
            try await appState.addSpaceMembers(spaceId: space.id, role: role, userIds: userIds, groupIds: groupIds)
            members = try await appState.loadSpaceMembers(spaceId: space.id)
            statusMessage = "Members added."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func filteredMembers(query: String) -> [DocmostSpaceMember] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return members }
        return members.filter { member in
            member.name.localizedStandardContains(trimmed) ||
            (member.email?.localizedStandardContains(trimmed) ?? false)
        }
    }

    private func saveMemberChange(
        appState: AppState,
        successMessage: String,
        operation: () async throws -> Void
    ) async {
        isSaving = true
        clearMessages()
        defer { isSaving = false }

        do {
            try await operation()
            members = try await appState.loadSpaceMembers(spaceId: space.id)
            statusMessage = successMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearMessages() {
        errorMessage = nil
        statusMessage = nil
    }
}
