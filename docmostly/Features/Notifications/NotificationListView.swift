import SwiftUI

struct NotificationListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = NotificationListViewModel()

    var body: some View {
        List {
            Section {
                Picker("Notification Type", selection: $viewModel.selectedType) {
                    ForEach(NotificationListType.displayCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            if viewModel.isLoading {
                ProgressView("Loading notifications")
            }

            Section(header: NotificationSectionHeaderView(unreadCount: viewModel.unreadCount)) {
                ForEach(viewModel.notifications) { notification in
                    Group {
                        if let target = PageOpenTarget(notification: notification) {
                            PageOpenLink(target: target) {
                                NotificationRowView(notification: notification)
                            }
                        } else {
                            NotificationRowView(notification: notification)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if notification.isUnread {
                            Button("Mark Read", systemImage: "checkmark") {
                                Task {
                                    await viewModel.markRead(notification, appState: appState)
                                }
                            }
                            .tint(.green)
                        }
                    }
                }
            }

            if viewModel.notifications.isEmpty && viewModel.isLoading == false {
                ContentUnavailableView("No Notifications", systemImage: "bell")
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }
        }
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Notification Actions", systemImage: "ellipsis.circle") {
                    Button("Mark All Read", systemImage: "checkmark.circle") {
                        Task {
                            await viewModel.markAllRead(appState: appState)
                        }
                    }
                    .disabled(viewModel.unreadCount == 0 || viewModel.isMarkingAllRead)

                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task {
                            await viewModel.load(appState: appState)
                        }
                    }
                }
            }
        }
        .task(id: viewModel.selectedType) {
            await viewModel.load(appState: appState)
        }
        .refreshable {
            await viewModel.load(appState: appState)
        }
        .pageOpenDestination()
    }
}
