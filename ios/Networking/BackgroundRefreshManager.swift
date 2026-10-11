import BackgroundTasks
import Foundation
import SwiftData

/// Safety net that doesn't need a paid Apple Developer account (unlike real
/// push, see Faza 3 w planie): periodically wakes the app in the background
/// to sync announcements/calendar for watched companies and fire local
/// notifications for anything new, so the user isn't only getting updates
/// when they happen to open the app.
final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    static let taskIdentifier = "com.dominikkowalski.gpwcommandcenter.refresh"

    private static let refreshInterval: TimeInterval = 20 * 60

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(task: refreshTask)
        }
    }

    func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.refreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(task: BGAppRefreshTask) {
        scheduleNext()

        let work = Task {
            do {
                try await performSync()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            work.cancel()
        }
    }

    private func performSync() async throws {
        let container = try ModelContainer(for: Company.self, Announcement.self, CalendarEvent.self)
        let context = ModelContext(container)

        let watched = try context.fetch(FetchDescriptor<Company>(predicate: #Predicate { $0.isWatched }))
        let tickers = watched.map(\.ticker)
        guard !tickers.isEmpty else { return }
        let mutedTickers = Set(watched.filter(\.isMuted).map(\.ticker))

        try await SyncService.syncAnnouncements(context: context, watchedTickers: tickers, mutedTickers: mutedTickers)
        try await SyncService.syncCalendarEvents(context: context, watchedTickers: tickers)
    }
}
