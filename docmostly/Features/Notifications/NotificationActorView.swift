import SwiftUI

struct NotificationActorView: View {
    let notification: DocmostNotification
    let isUnread: Bool

    var body: some View {
        if let actor = notification.actor {
            Text(actor.name.first.map(String.init) ?? "?")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.quaternary, in: .circle)
                .accessibilityLabel(actor.name)
        } else {
            Image(systemName: isUnread ? "bell.badge" : "bell")
                .foregroundStyle(isUnread ? DocmostlyTheme.primary : .secondary)
        }
    }
}
