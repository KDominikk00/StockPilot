import SwiftUI
import SwiftData

struct AnnouncementsFeedView: View {
    @Query(filter: #Predicate<Company> { $0.isWatched })
    private var watchedCompanies: [Company]

    @Query(sort: \Announcement.publishedAt, order: .reverse)
    private var allAnnouncements: [Announcement]

    private var watchedTickers: Set<String> {
        Set(watchedCompanies.map(\.ticker))
    }

    private var feed: [Announcement] {
        allAnnouncements.filter { ($0.companyTicker).map(watchedTickers.contains) ?? false }
    }

    @State private var isRefreshing = false

    var body: some View {
        List {
            if watchedCompanies.isEmpty {
                ContentUnavailableView(
                    "Brak obserwowanych spółek",
                    systemImage: "megaphone",
                    description: Text("Dodaj spółki do watchlisty, aby zobaczyć ich komunikaty ESPI/EBI.")
                )
            } else if feed.isEmpty {
                ContentUnavailableView(
                    "Brak komunikatów",
                    systemImage: "tray",
                    description: Text("Backend synchronizacji nie jest jeszcze podłączony (kolejna faza). Pociągnij, aby odświeżyć.")
                )
            } else {
                ForEach(feed) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.companyTicker ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.title)
                        Text(item.publishedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Komunikaty")
        .refreshable {
            // Faza 1 podłączy tu AnnouncementSyncService wywołujący backend.
        }
    }
}

#Preview {
    NavigationStack { AnnouncementsFeedView() }
        .modelContainer(for: [Company.self, Announcement.self, CalendarEvent.self], inMemory: true)
}
