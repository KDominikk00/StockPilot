import SwiftUI
import SwiftData

struct AnnouncementsFeedView: View {
    @Environment(\.modelContext) private var modelContext

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

    @State private var syncError: String?

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
                    description: Text("Pociągnij, aby odświeżyć z backendu.")
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
            do {
                try await SyncService.syncAnnouncements(context: modelContext, watchedTickers: Array(watchedTickers))
                syncError = nil
            } catch {
                syncError = error.localizedDescription
            }
        }
        .alert("Błąd synchronizacji", isPresented: .constant(syncError != nil), actions: {
            Button("OK") { syncError = nil }
        }, message: {
            Text(syncError ?? "")
        })
    }
}

#Preview {
    NavigationStack { AnnouncementsFeedView() }
        .modelContainer(for: [Company.self, Announcement.self, CalendarEvent.self], inMemory: true)
}
