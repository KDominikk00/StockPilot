import SwiftUI
import SwiftData

struct CompanyDetailView: View {
    @Bindable var company: Company

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var announcements: [Announcement] = []
    @State private var events: [CalendarEvent] = []
    @State private var showAllAnnouncements = false
    @State private var showAllEvents = false

    private static let collapsedCount = 3

    private var visibleAnnouncements: [Announcement] {
        showAllAnnouncements ? announcements : Array(announcements.prefix(Self.collapsedCount))
    }

    private var visibleEvents: [CalendarEvent] {
        showAllEvents ? events : Array(events.prefix(Self.collapsedCount))
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
                                company.isMuted ? "Powiadomienia wyłączone" : "Powiadomienia włączone",
                                systemImage: company.isMuted ? "bell.slash" : "bell.fill"
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
                    ForEach(visibleAnnouncements) { item in
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
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                        .font(item.isRead ? .body : .body.bold())
                                        .foregroundStyle(.primary)
                                    Text(item.publishedAt.polishDateTime)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if announcements.count > Self.collapsedCount {
                        Button(showAllAnnouncements ? "Pokaż mniej" : "Pokaż więcej") {
                            showAllAnnouncements.toggle()
                        }
                    }
                }
            }

            Section("Terminy wyników") {
                if events.isEmpty {
                    Text("Brak zaplanowanych publikacji raportów.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visibleEvents) { event in
                        VStack(alignment: .leading) {
                            Text(event.reportType)
                            Text(event.eventDate.polishDate)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if events.count > Self.collapsedCount {
                        Button(showAllEvents ? "Pokaż mniej" : "Pokaż więcej") {
                            showAllEvents.toggle()
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
