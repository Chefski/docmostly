import SwiftUI

struct NotificationRowView: View {
    let notification: DocmostNotification
    let isUnread: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            NotificationActorView(notification: notification, isUnread: isUnread)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(notification.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let createdAt = notification.createdAt {
                    Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            if isUnread {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(DocmostlyTheme.primary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isUnread ? "Unread" : "Read")
    }
}
