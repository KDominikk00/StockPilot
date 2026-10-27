import SwiftUI
import SwiftData

struct AnnouncementsFeedView: View {
    let watchedCompanies: [Company]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @Query(sort: \Announcement.publishedAt, order: .reverse)
    private var allAnnouncements: [Announcement]

    private var watchedTickers: Set<String> {
        Set(watchedCompanies.map(\.ticker))
    }

    private var mutedTickers: Set<String> {
        Set(watchedCompanies.filter(\.isMuted).map(\.ticker))
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
                    description: Text("Przeciągnij listę w dół, aby sprawdzić najnowsze komunikaty.")
                )
            } else {
                ForEach(feed) { item in
                    Button {
                        item.isRead = true
                        if let url = URL(string: item.url) {
                            openURL(url)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            if !item.isRead {
                                Circle()
                                    .fill(.tint)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.companyTicker ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.title)
                                    .font(item.isRead ? .body : .body.bold())
                                    .foregroundStyle(.primary)
                                Text(item.publishedAt.polishDateTime)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                AnnouncementTagRow(tags: item.tags)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Komunikaty")
        .refreshable {
            do {
                try await SyncService.syncAnnouncements(
                    context: modelContext,
                    watchedTickers: Array(watchedTickers),
                    mutedTickers: mutedTickers
                )
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
    NavigationStack { AnnouncementsFeedView(watchedCompanies: []) }
        .modelContainer(for: [Company.self, Announcement.self, CalendarEvent.self], inMemory: true)
}
