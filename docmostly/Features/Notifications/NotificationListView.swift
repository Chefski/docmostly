import SwiftUI

struct NotificationListView: View {
    @Environment(AppState.self) private var appState
    @Environment(NotificationStore.self) private var notificationStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = NotificationListViewModel()
    @State private var selectedPageTarget: PageOpenTarget?

    var body: some View {
        List {
            NotificationListControlsView(viewModel: viewModel)

            if viewModel.isLoading && viewModel.notifications.isEmpty {
                ProgressView("Loading notifications")
                    .frame(maxWidth: .infinity)
            } else if let errorMessage = viewModel.errorMessage, viewModel.notifications.isEmpty {
                ContentUnavailableView {
                    Label("Couldn’t Load Notifications", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again", systemImage: "arrow.clockwise", action: retry)
                }
            } else if viewModel.visibleNotifications.isEmpty {
                ContentUnavailableView(
                    viewModel.selectedFilter == .unread ? "No Unread Notifications" : "No Notifications",
                    systemImage: "bell.slash",
                    description: Text(emptyDescription)
                )
            } else {
                ForEach(viewModel.sections) { group in
                    Section(group.section.title) {
                        ForEach(group.notifications) { notification in
                            NotificationListRow(
                                notification: notification,
                                isUnread: viewModel.isUnread(notification),
                                markRead: { markRead(notification) },
                                openPage: { selectedPageTarget = $0 }
                            )
                        }
                    }
                }
            }

            if viewModel.hasNextPage {
                NotificationPaginationView(
                    isLoading: viewModel.isLoadingNextPage,
                    errorMessage: viewModel.nextPageErrorMessage,
                    loadNextPage: loadNextPage
                )
            }

            if let errorMessage = viewModel.errorMessage, viewModel.notifications.isEmpty == false {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }
        }
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Notification Actions", systemImage: "ellipsis.circle") {
                    Button("Mark All as Read", systemImage: "checkmark.circle") {
                        Task {
                            await viewModel.markAllRead(appState: appState, store: notificationStore)
                        }
                    }
                    .disabled(notificationStore.unreadCount == 0 || viewModel.isMarkingAllRead)

                    Button("Refresh", systemImage: "arrow.clockwise", action: retry)
                }
            }
        }
        .task(id: viewModel.selectedType) {
            await viewModel.load(appState: appState, store: notificationStore)
        }
        .task(id: notificationStore.contentRevision) {
            guard notificationStore.contentRevision > 0 else { return }
            await viewModel.load(appState: appState, store: notificationStore)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            retry()
        }
        .refreshable {
            await viewModel.load(appState: appState, store: notificationStore)
        }
        #if os(iOS)
        .navigationDestination(item: $selectedPageTarget) { target in
            PageOpenDestinationView(target: target)
        }
        #endif
    }

    private var emptyDescription: String {
        if viewModel.selectedFilter == .unread {
            return viewModel.hasNextPage
                ? "Load more to continue checking older notifications."
                : "You’re all caught up."
        }
        return "Workspace activity and mentions will appear here."
    }

    private func retry() {
        Task {
            await viewModel.load(appState: appState, store: notificationStore)
        }
    }

    private func loadNextPage() {
        Task {
            await viewModel.loadNextPage(appState: appState)
        }
    }

    private func markRead(_ notification: DocmostNotification) {
        Task {
            await viewModel.markRead(notification, appState: appState, store: notificationStore)
        }
    }
}
