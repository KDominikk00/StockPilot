import EventKit
import Foundation

/// Copies report dates into a dedicated "StockPilot" calendar in Apple Calendar.
/// Re-running replaces that calendar's events, so dates that moved or were unwatched don't pile up.
enum CalendarExporter {
    struct Item {
        let title: String
        let notes: String
        let day: Date
    }

    enum ExportError: LocalizedError {
        case accessDenied
        case noWritableCalendarSource

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                "Brak dostępu do Kalendarza. Włącz go dla StockPilot w Ustawienia > Prywatność i ochrona > Kalendarze."
            case .noWritableCalendarSource:
                "Nie znaleziono konta, w którym można utworzyć kalendarz."
            }
        }
    }

    private static let calendarTitle = "StockPilot"

    /// Returns how many events were written.
    static func export(_ items: [Item]) async throws -> Int {
        let store = EKEventStore()
        guard try await store.requestFullAccessToEvents() else { throw ExportError.accessDenied }

        let calendar = try stockPilotCalendar(in: store)

        // Clear what we wrote last time (wide window; the calendar is ours alone).
        let from = Date(timeIntervalSinceNow: -5 * 365 * 86400)
        let to = Date(timeIntervalSinceNow: 5 * 365 * 86400)
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: [calendar])
        for old in store.events(matching: predicate) {
            try store.remove(old, span: .thisEvent, commit: false)
        }

        for item in items {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = item.title
            event.notes = item.notes
            event.isAllDay = true
            event.startDate = item.day
            event.endDate = item.day
            try store.save(event, span: .thisEvent, commit: false)
        }
        try store.commit()
        return items.count
    }

    private static func stockPilotCalendar(in store: EKEventStore) throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarTitle && $0.allowsContentModifications }) {
            return existing
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarTitle
        let source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first { $0.sourceType == .calDAV && $0.title == "iCloud" }
            ?? store.sources.first { $0.sourceType == .local }
        guard let source else { throw ExportError.noWritableCalendarSource }
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }

    /// Event dates are stored as Warsaw-midnight instants; an all-day event needs that same
    /// calendar day expressed in the device's time zone, or it can land a day off.
    static func allDayDate(for instant: Date) -> Date {
        var warsaw = Calendar(identifier: .gregorian)
        warsaw.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        let parts = warsaw.dateComponents([.year, .month, .day], from: instant)
        return Calendar.current.date(from: parts) ?? instant
    }
}
