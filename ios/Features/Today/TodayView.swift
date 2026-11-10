import SwiftUI
import SwiftData

/// Home tab: a daily briefing (what's new, what's coming) followed by the watched companies.
struct TodayView: View {
    let watchedCompanies: [Company]
    let showAnnouncements: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Announcement.publishedAt, order: .reverse)
    private var allAnnouncements: [Announcement]

    @Query(sort: \CalendarEvent.eventDate)
    private var allEvents: [CalendarEvent]

    @State private var reader: ReaderLink?
    @State private var showingSearch = false
    @State private var syncError: String?
    @State private var lastSync: Date?

    /// Opening the tab or returning to the app refreshes, but not more often than this.
    private static let autoSyncInterval: TimeInterval = 60
    private static let highlightCount = 3
    private static let upcomingCount = 3
    private static let highlightWindow: TimeInterval = 7 * 24 * 3600

    private var watchedTickers: Set<String> {
        Set(watchedCompanies.map(\.ticker))
    }

    private var mutedTickers: Set<String> {
        Set(watchedCompanies.filter(\.isMuted).map(\.ticker))
    }

    private var companiesByTicker: [String: Company] {
        Dictionary(watchedCompanies.map { ($0.ticker, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var watchedAnnouncements: [Announcement] {
        allAnnouncements.filter { ($0.companyTicker).map(watchedTickers.contains) ?? false }
    }

    private var unreadByTicker: [String: [Announcement]] {
        Dictionary(
            grouping: watchedAnnouncements.filter { !$0.isRead },
            by: { $0.companyTicker ?? "" }
        )
    }

    /// Same rule as the tab badge used to apply: muted companies don't count as news.
    private var unreadCount: Int {
        unreadByTicker.filter { !mutedTickers.contains($0.key) }.values.reduce(0) { $0 + $1.count }
    }

    private var upcomingEvents: [CalendarEvent] {
        let today = Calendar.current.startOfDay(for: .now)
        return allEvents.filter { $0.eventDate >= today && ($0.companyTicker).map(watchedTickers.contains) ?? false }
    }

    private var reportsThisWeek: Int {
        let today = Calendar.current.startOfDay(for: .now)
        guard let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return 0 }
        return upcomingEvents.filter { $0.eventDate < weekEnd }.count
    }

    /// Last week's filings: unread first, then results/dividends before meetings before
    /// everything else, with routine transaction filings last, newest first within a group.
    private var highlights: [Announcement] {
        let cutoff = Date().addingTimeInterval(-Self.highlightWindow)
        return watchedAnnouncements
            .filter { $0.publishedAt > cutoff }
            .sorted { a, b in
                if a.isRead != b.isRead { return !a.isRead }
                if a.priority != b.priority { return a.priority < b.priority }
                return a.publishedAt > b.publishedAt
            }
            .prefix(Self.highlightCount)
            .map { $0 }
    }

    var body: some View {
        List {
            if watchedCompanies.isEmpty {
                ContentUnavailableView {
                    Label("Dodaj pierwszą spółkę", systemImage: "star")
                } description: {
                    Text("Wybierz spółki z GPW, a tu zobaczysz, co nowego.")
                } actions: {
                    Button("Dodaj spółkę") { showingSearch = true }
                }
            } else {
                summarySection
                highlightsSection
                upcomingSection
                companiesSection
            }
        }
        .navigationTitle("Dziś")
        .navigationDestination(for: Company.self) { company in
            CompanyDetailView(company: company)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSearch = true
                } label: {
                    Label("Dodaj spółkę", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            CompanySearchView()
        }
        .readerSheet(item: $reader)
        .refreshable { await sync() }
        .task { await syncIfStale() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await syncIfStale() }
            }
        }
        .alert("Błąd synchronizacji", isPresented: .constant(syncError != nil), actions: {
            Button("OK") { syncError = nil }
        }, message: {
            Text(syncError ?? "")
        })
    }

    private func syncIfStale() async {
        if let lastSync, Date().timeIntervalSince(lastSync) < Self.autoSyncInterval { return }
        await sync(showsError: false)
    }

    private func sync(showsError: Bool = true) async {
        guard !watchedCompanies.isEmpty else { return }
        lastSync = .now
        do {
            let tickers = Array(watchedTickers)
            try await SyncService.syncAnnouncements(
                context: modelContext,
                watchedTickers: tickers,
                mutedTickers: mutedTickers
            )
            try await SyncService.syncCalendarEvents(context: modelContext, watchedTickers: tickers)
            syncError = nil
        } catch {
            // Automatic syncs fail quietly (the backend may be waking up); only a manual pull reports.
            if showsError { syncError = error.localizedDescription }
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(Date.now.polishLongDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                HStack(spacing: 12) {
                    SummaryTile(title: "Nowe komunikaty", value: unreadCount)
                    SummaryTile(title: "Raporty w tym tygodniu", value: reportsThisWeek)
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
        }
    }

    private var highlightsSection: some View {
        Section("Najważniejsze") {
            if highlights.isEmpty {
                Text("Brak komunikatów z ostatnich 7 dni.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(highlights) { item in
                    Button {
                        item.isRead = true
                        reader = ReaderLink(string: item.url)
                    } label: {
                        AnnouncementRow(item: item, showsTicker: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("Wszystkie komunikaty", action: showAnnouncements)
        }
    }

    private var upcomingSection: some View {
        Section("Nadchodzące raporty") {
            let events = Array(upcomingEvents.prefix(Self.upcomingCount))
            if events.isEmpty {
                Text("Brak zaplanowanych publikacji raportów.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(companiesByTicker[event.companyTicker ?? ""]?.displayName ?? event.companyTicker ?? "")
                                .font(.body.weight(.medium))
                            Spacer()
                            Text(event.eventDate.polishWeekdayDate)
                                .font(.body.weight(.medium))
                        }
                        Text(event.reportType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private var companiesSection: some View {
        Section {
            ForEach(watchedCompanies) { company in
                NavigationLink(value: company) {
                    CompanyRow(
                        company: company,
                        unread: unreadByTicker[company.ticker] ?? [],
                        nextReport: upcomingEvents.first { $0.companyTicker == company.ticker }
                    )
                }
            }
        } header: {
            Text("Obserwowane (\(watchedCompanies.count))")
        } footer: {
            Text("Dane mają charakter informacyjny i nie stanowią rekomendacji inwestycyjnej.")
                .font(.caption2)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CompanyRow: View {
    let company: Company
    let unread: [Announcement]
    let nextReport: CalendarEvent?

    /// "1 nowy", "2 nowe", "5 nowych": Polish plural forms for "komunikat".
    private var unreadText: String {
        let n = unread.count
        if n == 1 { return "1 nowy" }
        let lastTwo = n % 100
        let last = n % 10
        return (2...4).contains(last) && !(12...14).contains(lastTwo) ? "\(n) nowe" : "\(n) nowych"
    }

    private var statusText: String {
        guard let newest = unread.first else { return "\(company.ticker) · bez zmian" }
        let tag = newest.tags.first.map { " · \($0.title)" } ?? ""
        return "\(company.ticker) · \(unreadText)\(tag)"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if !unread.isEmpty {
                        Circle()
                            .fill(.tint)
                            .frame(width: 8, height: 8)
                    }
                    Text(company.displayName)
                        .font(.body)
                    if company.isMuted {
                        Image(systemName: "bell.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("raport")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(nextReport?.eventDate.polishDayMonth ?? "brak")
                    .font(.subheadline.weight(.medium))
            }
        }
    }
}

#Preview {
    NavigationStack { TodayView(watchedCompanies: [], showAnnouncements: {}) }
        .modelContainer(for: [Company.self, Announcement.self, CalendarEvent.self], inMemory: true)
}
