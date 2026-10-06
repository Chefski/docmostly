import Foundation

extension AppState {
    func restoreIfNeeded() async {
        if let restoreTask {
            await restoreTask.value
            return
        }

        guard phase == .restoring else { return }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.restore()
        }
        restoreTask = task
        await task.value
        restoreTask = nil
    }
}
