import SwiftUI

struct NotificationListRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.pageOpenPresentation) private var pageOpenPresentation

    let notification: DocmostNotification
    let isUnread: Bool
    let markRead: () -> Void
    let openPage: (PageOpenTarget) -> Void

    var body: some View {
        Group {
            if let target = PageOpenTarget(notification: notification) {
                #if os(macOS)
                Button {
                    if isUnread {
                        markRead()
                    }
                    appState.openPage(target)
                } label: {
                    NotificationRowView(notification: notification, isUnread: isUnread)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("PageOpenLink.\(target.slugId)")
                #else
                Button {
                    if pageOpenPresentation == .stack {
                        openPage(target)
                    } else {
                        appState.openPage(target)
                    }
                    if isUnread {
                        markRead()
                    }
                } label: {
                    HStack {
                        NotificationRowView(notification: notification, isUnread: isUnread)

                        if pageOpenPresentation == .stack {
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("PageOpenLink.\(target.slugId)")
                #endif
            } else {
                NotificationRowView(notification: notification, isUnread: isUnread)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isUnread {
                Button("Mark as Read", systemImage: "checkmark", action: markRead)
                    .tint(.green)
            }
        }
        .contextMenu {
            if isUnread {
                Button("Mark as Read", systemImage: "checkmark", action: markRead)
            }
        }
    }
}
