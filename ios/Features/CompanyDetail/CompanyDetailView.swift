import SwiftUI
import SwiftData

struct CompanyDetailView: View {
    @Bindable var company: Company

    @Environment(\.modelContext) private var modelContext
    @State private var announcements: [Announcement] = []
    @State private var events: [CalendarEvent] = []

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(company.displayName).font(.headline)
                        Text("Ticker: \(company.ticker) · ISIN: \(company.isin)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    QuoteBadge(ticker: company.ticker)
                }
                HStack {
                    Button {
                        company.isWatched.toggle()
                    } label: {
                        Label(
                            company.isWatched ? "Obserwowana" : "Dodaj do watchlisty",
                            systemImage: company.isWatched ? "star.fill" : "star"
                        )
                    }
                    .labelStyle(.iconOnly)
                    if company.isWatched {
                        Button {
                            company.isMuted.toggle()
                        } label: {
                            Label(
                                company.isMuted ? "Wyciszone" : "Wycisz powiadomienia",
                                systemImage: company.isMuted ? "bell.slash.fill" : "bell"
                            )
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                .buttonStyle(.borderless)
                .font(.title3)
            }

            Section("Komunikaty") {
                if announcements.isEmpty {
                    Text("Brak komunikatów dla tej spółki.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(announcements) { item in
                        VStack(alignment: .leading) {
                            Text(item.title)
                            Text(item.publishedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Terminy wyników") {
                if events.isEmpty {
                    Text("Brak zaplanowanych publikacji raportów.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events) { event in
                        VStack(alignment: .leading) {
                            Text(event.reportType)
                            Text(event.eventDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(company.ticker)
        .task {
            let ticker = company.ticker
            let announcementDescriptor = FetchDescriptor<Announcement>(
                predicate: #Predicate { $0.companyTicker == ticker },
                sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
            )
            announcements = (try? modelContext.fetch(announcementDescriptor)) ?? []

            let eventDescriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { $0.companyTicker == ticker },
                sortBy: [SortDescriptor(\.eventDate)]
            )
            events = (try? modelContext.fetch(eventDescriptor)) ?? []
        }
    }
}
