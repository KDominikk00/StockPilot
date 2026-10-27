import SwiftUI
import SwiftData

struct EarningsCalendarView: View {
    let watchedCompanies: [Company]

    @Environment(\.modelContext) private var modelContext

    @Query private var allEvents: [CalendarEvent]

    @State private var visibleMonth: Date = Calendar.current.startOfDay(for: .now)
    @State private var syncError: String?

    private var watchedTickers: Set<String> {
        Set(watchedCompanies.map(\.ticker))
    }

    private var eventsByDay: [Date: [CalendarEvent]] {
        let calendar = Calendar.current
        let relevant = allEvents.filter { ($0.companyTicker).map(watchedTickers.contains) ?? false }
        return Dictionary(grouping: relevant) { calendar.startOfDay(for: $0.eventDate) }
    }

    var body: some View {
        VStack(spacing: 0) {
            MonthHeader(visibleMonth: $visibleMonth)

            MonthGrid(visibleMonth: visibleMonth, eventsByDay: eventsByDay)

            List {
                let daysInMonth = eventsByDay.keys.sorted().filter {
                    Calendar.current.isDate($0, equalTo: visibleMonth, toGranularity: .month)
                }
                if watchedCompanies.isEmpty {
                    ContentUnavailableView(
                        "Brak obserwowanych spółek",
                        systemImage: "calendar",
                        description: Text("Dodaj spółki do watchlisty, aby zobaczyć terminy ich raportów.")
                    )
                } else if daysInMonth.isEmpty {
                    ContentUnavailableView(
                        "Brak terminów",
                        systemImage: "calendar.badge.clock",
                        description: Text("W tym miesiącu nie ma zaplanowanych publikacji. Zmień miesiąc strzałkami lub przeciągnij listę w dół.")
                    )
                } else {
                    ForEach(daysInMonth, id: \.self) { day in
                        Section(day.polishDate) {
                            ForEach(eventsByDay[day] ?? []) { event in
                                VStack(alignment: .leading) {
                                    Text(event.companyTicker ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(event.reportType)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                do {
                    try await SyncService.syncCalendarEvents(context: modelContext, watchedTickers: Array(watchedTickers))
                    syncError = nil
                } catch {
                    syncError = error.localizedDescription
                }
            }
        }
        .navigationTitle("Kalendarz wyników")
        .alert("Błąd synchronizacji", isPresented: .constant(syncError != nil), actions: {
            Button("OK") { syncError = nil }
        }, message: {
            Text(syncError ?? "")
        })
    }
}

private struct MonthHeader: View {
    @Binding var visibleMonth: Date

    var body: some View {
        HStack {
            Button { shift(by: -1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(visibleMonth.polishMonthYear)
                .font(.headline)
            Spacer()
            Button { shift(by: 1) } label: { Image(systemName: "chevron.right") }
        }
        .padding()
    }

    private func shift(by months: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: months, to: visibleMonth) {
            visibleMonth = newDate
        }
    }
}

private struct MonthGrid: View {
    let visibleMonth: Date
    let eventsByDay: [Date: [CalendarEvent]]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var days: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let firstOfMonth = monthInterval.start
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        // Monday-first layout: weekday 2 = Monday in Calendar's numbering (1 = Sunday)
        let leadingBlanks = (weekdayOfFirst + 5) % 7

        var result: [Date?] = Array(repeating: nil, count: leadingBlanks)
        var current = firstOfMonth
        while current < monthInterval.end {
            result.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    let hasEvents = !(eventsByDay[calendar.startOfDay(for: day)]?.isEmpty ?? true)
                    let isToday = calendar.isDateInToday(day)
                    VStack(spacing: 2) {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.caption.weight(isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? Color.white : Color.primary)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(isToday ? Color.accentColor : .clear))
                        Circle()
                            .fill(hasEvents ? Color.accentColor : .clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                } else {
                    Color.clear.frame(minHeight: 32)
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack { EarningsCalendarView(watchedCompanies: []) }
        .modelContainer(for: [Company.self, Announcement.self, CalendarEvent.self], inMemory: true)
}
