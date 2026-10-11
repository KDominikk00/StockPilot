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

    static func syncAnnouncements(context: ModelContext, watchedTickers: [String]) async throws {
        let items = try await BackendAPI.fetchAnnouncements(tickers: watchedTickers)
        let existingIDs = Set(try context.fetch(FetchDescriptor<Announcement>()).map(\.externalID))

        for item in items where !existingIDs.contains(item.external_id) {
            let publishedAt = isoFormatter.date(from: item.published_at) ?? .now
            let announcement = Announcement(
                externalID: item.external_id,
                companyTicker: item.ticker,
                title: item.title,
                url: item.url,
                publishedAt: publishedAt
            )
            context.insert(announcement)
        }
        try context.save()
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
