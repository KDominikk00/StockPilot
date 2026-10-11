import SwiftUI
import SwiftData

struct WatchlistView: View {
    let watchedCompanies: [Company]

    @State private var searchText = ""
    @State private var showingSearch = false

    var body: some View {
        List {
            if watchedCompanies.isEmpty {
                ContentUnavailableView(
                    "Brak obserwowanych spółek",
                    systemImage: "star",
                    description: Text("Dodaj spółki z GPW, które chcesz śledzić.")
                )
            } else {
                Section("Obserwowane") {
                    ForEach(watchedCompanies) { company in
                        NavigationLink(value: company) {
                            CompanyRow(company: company)
                        }
                    }
                }
            }
        }
        .navigationTitle("Watchlist")
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
    }
}

struct CompanyRow: View {
    let company: Company

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(company.displayName)
                    .font(.body)
                Text(company.ticker)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            QuoteBadge(ticker: company.ticker)
        }
    }
}

#Preview {
    NavigationStack { WatchlistView(watchedCompanies: []) }
        .modelContainer(for: [Company.self, Announcement.self, CalendarEvent.self], inMemory: true)
}
