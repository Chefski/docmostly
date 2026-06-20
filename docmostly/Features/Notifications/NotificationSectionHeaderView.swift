import SwiftUI

struct NotificationSectionHeaderView: View {
    let unreadCount: Int

    var body: some View {
        HStack {
            Text("Notifications")
            Spacer()
            if unreadCount > 0 {
                Text("\(unreadCount) unread")
            }
        }
    }
}
