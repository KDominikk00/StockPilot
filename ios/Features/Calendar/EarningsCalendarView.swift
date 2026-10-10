import SwiftUI
import SwiftData

struct EarningsCalendarView: View {
    @Query(filter: #Predicate<Company> { $0.isWatched })
    private var watchedCompanies: [Company]

    @Query private var allEvents: [CalendarEvent]

    @State private var visibleMonth: Date = Calendar.current.startOfDay(for: .now)

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
                let upcoming = eventsByDay.keys.sorted().filter { $0 >= Calendar.current.startOfDay(for: .now) }
                if watchedCompanies.isEmpty {
                    ContentUnavailableView(
                        "Brak obserwowanych spółek",
                        systemImage: "calendar",
                        description: Text("Dodaj spółki do watchlisty, aby zobaczyć terminy ich raportów.")
                    )
                } else if upcoming.isEmpty {
                    ContentUnavailableView(
                        "Brak zaplanowanych publikacji",
                        systemImage: "calendar.badge.clock",
                        description: Text("Synchronizacja terminarza wyników zostanie podłączona w kolejnej fazie.")
                    )
                } else {
                    ForEach(upcoming, id: \.self) { day in
                        Section(day.formatted(date: .abbreviated, time: .omitted)) {
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
        }
        .navigationTitle("Kalendarz wyników")
    }
}

private struct MonthHeader: View {
    @Binding var visibleMonth: Date

    var body: some View {
        HStack {
            Button { shift(by: -1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
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
                    VStack(spacing: 2) {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.caption)
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
    NavigationStack { EarningsCalendarView() }
        .modelContainer(for: [Company.self, Announcement.self, CalendarEvent.self], inMemory: true)
}
