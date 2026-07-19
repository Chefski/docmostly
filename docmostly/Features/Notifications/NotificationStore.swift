import Foundation
import Observation

@MainActor
@Observable
final class NotificationStore {
    private(set) var unreadCount = 0
    private(set) var contentRevision = 0
    private(set) var isRefreshingUnreadCount = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let socketClient = NotificationSocketClient()

    func refreshUnreadCount(appState: AppState) async {
        guard isRefreshingUnreadCount == false else { return }
        isRefreshingUnreadCount = true
        defer { isRefreshingUnreadCount = false }

        do {
            unreadCount = try await appState.loadUnreadNotificationCount()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reconcile(unreadCount: Int) {
        self.unreadCount = max(unreadCount, 0)
        errorMessage = nil
    }

    @discardableResult
    func applyOptimisticRead(count: Int = 1) -> Int {
        let previousCount = unreadCount
        unreadCount = max(unreadCount - count, 0)
        return previousCount
    }

    @discardableResult
    func applyOptimisticMarkAllRead() -> Int {
        let previousCount = unreadCount
        unreadCount = 0
        return previousCount
    }

    func restoreUnreadCount(_ count: Int) {
        unreadCount = max(count, 0)
    }

    func recordRefreshError(_ message: String) {
        errorMessage = message
    }

    func pollUnreadCount(appState: AppState) async {
        while Task.isCancelled == false {
            await refreshUnreadCount(appState: appState)
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                return
            }
        }
    }

    func monitorRealtime(appState: AppState) async {
        var reconnectPolicy = NativeEditorRealtimeReconnectPolicy()

        while Task.isCancelled == false {
            do {
                let url = try appState.realtimeEventWebSocketURL()
                let cookies = await appState.activeSessionCookies(for: url)
                let events = await socketClient.events(url: url, cookies: cookies)

                for try await event in events {
                    guard Task.isCancelled == false else { return }
                    switch event {
                    case .connected:
                        reconnectPolicy.reset()
                    case .notification:
                        contentRevision &+= 1
                        await refreshUnreadCount(appState: appState)
                    case .disconnected:
                        break
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }

            do {
                try await Task.sleep(for: .seconds(reconnectPolicy.nextDelaySeconds()))
            } catch {
                return
            }
        }
    }
}
