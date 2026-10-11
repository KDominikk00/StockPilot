import Foundation
import SwiftData

enum SyncService {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Warsaw")
        return formatter
    }()

    /// Local-notification stand-in: until remote push works (needs a paid
    /// Apple Developer account, see Faza 3 w planie), a manual/background
    /// refresh that finds new announcements fires a notification itself.
    private static let maxIndividualNotifications = 3

    /// Matches backend/src/sources/companyBackfill.ts's SOURCE constant.
    /// Items from this source are historical catch-up (fetched the first
    /// time a company has zero announcements on file), not genuinely new —
    /// they arrive pre-marked read so they don't inflate the unread badge
    /// or trigger a "new announcement" notification.
    private static let backfillSource = "bankier_company_backfill"

    static func syncAnnouncements(
        context: ModelContext,
        watchedTickers: [String],
        mutedTickers: Set<String> = []
    ) async throws {
        let items = try await BackendAPI.fetchAnnouncements(tickers: watchedTickers)
        let existingIDs = Set(try context.fetch(FetchDescriptor<Announcement>()).map(\.externalID))

        var newlyInserted: [Announcement] = []
        for item in items where !existingIDs.contains(item.external_id) {
            let publishedAt = isoFormatter.date(from: item.published_at) ?? .now
            let isBackfilled = item.source == backfillSource
            let announcement = Announcement(
                externalID: item.external_id,
                companyTicker: item.ticker,
                title: item.title,
                url: item.url,
                publishedAt: publishedAt,
                isRead: isBackfilled
            )
            context.insert(announcement)
            newlyInserted.append(announcement)
        }
        try context.save()

        let notifiable = newlyInserted.filter {
            !$0.isRead && !($0.companyTicker.map(mutedTickers.contains) ?? false)
        }
        guard !notifiable.isEmpty else { return }
        if notifiable.count <= maxIndividualNotifications {
            for announcement in notifiable {
                await PushNotificationManager.shared.scheduleLocalNotification(
                    title: announcement.companyTicker ?? "Komunikat",
                    body: announcement.title,
                    identifier: announcement.externalID
                )
            }
        } else {
            await PushNotificationManager.shared.scheduleLocalNotification(
                title: "Nowe komunikaty",
                body: "\(notifiable.count) nowych komunikatów od obserwowanych spółek",
                identifier: "summary-\(UUID().uuidString)"
            )
        }
    }

    static func syncCalendarEvents(context: ModelContext, watchedTickers: [String]) async throws {
        let items = try await BackendAPI.fetchCalendar(tickers: watchedTickers)
        let existingIDs = Set(try context.fetch(FetchDescriptor<CalendarEvent>()).map(\.externalID))

        for item in items where !existingIDs.contains(item.external_id) {
            guard let eventDate = dayFormatter.date(from: item.event_date) else { continue }
            let event = CalendarEvent(
                externalID: item.external_id,
                companyTicker: item.ticker,
                eventDate: eventDate,
                reportType: item.source_text ?? item.event_type,
                sourceText: item.source_text ?? ""
            )
            context.insert(event)
        }
        try context.save()
    }
}
