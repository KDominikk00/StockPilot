import SwiftUI
import SwiftData

struct CompanyDetailView: View {
    @Bindable var company: Company

    @Query private var allAnnouncements: [Announcement]
    @Query private var allEvents: [CalendarEvent]

    private var announcements: [Announcement] {
        allAnnouncements
            .filter { $0.companyTicker == company.ticker }
            .sorted { $0.publishedAt > $1.publishedAt }
    }

    private var events: [CalendarEvent] {
        allEvents
            .filter { $0.companyTicker == company.ticker }
            .sorted { $0.eventDate < $1.eventDate }
    }

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
                    Button {
                        company.isWatched.toggle()
                    } label: {
                        Image(systemName: company.isWatched ? "star.fill" : "star")
                    }
                    .buttonStyle(.borderless)
                }
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
    }
}
