import SwiftUI

struct NotificationRowView: View {
    let notification: DocmostNotification

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: notification.isUnread ? "bell.badge" : "bell")
                .foregroundStyle(notification.isUnread ? DocmostlyTheme.primary : .secondary)
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
        }
    }
}
