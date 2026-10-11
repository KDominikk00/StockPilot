import SwiftUI
import SwiftData

struct CompanySearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var allCompanies: [Company] = []
    @State private var searchText = ""
    @State private var selectedTickers: Set<String> = []

    private var filtered: [Company] {
        guard !searchText.isEmpty else { return allCompanies }
        let query = searchText.uppercased()
        return allCompanies.filter {
            $0.nameFull.uppercased().contains(query) || $0.ticker.uppercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { company in
                Button {
                    toggleSelection(company.ticker)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(company.displayName)
                                .foregroundStyle(.primary)
                            Text(company.ticker)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedTickers.contains(company.ticker) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Szukaj spółki, ticker, ISIN")
            .navigationTitle("Dodaj spółki")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") {
                        commitSelection()
                        dismiss()
                    }
                }
            }
        }
        .task {
            let descriptor = FetchDescriptor<Company>(sortBy: [SortDescriptor(\.nameFull)])
            allCompanies = (try? modelContext.fetch(descriptor)) ?? []
            selectedTickers = Set(allCompanies.filter(\.isWatched).map(\.ticker))
        }
    }

    /// Selection only touches local view state while the sheet is open —
    /// no SwiftData write happens per tap. Earlier this wrote through
    /// immediately on every toggle, which crashed SwiftData with a
    /// "Duplicate registration attempt" / memory-corruption fault after a
    /// few consecutive writes to the same entity in quick succession, no
    /// matter how the query/context setup was arranged. Batching every
    /// change into a single save on confirm sidesteps that entirely and
    /// also matches how a multi-select picker should behave.
    private func toggleSelection(_ ticker: String) {
        if selectedTickers.contains(ticker) {
            selectedTickers.remove(ticker)
        } else {
            selectedTickers.insert(ticker)
        }
    }

    private func commitSelection() {
        for company in allCompanies where company.isWatched != selectedTickers.contains(company.ticker) {
            company.isWatched = selectedTickers.contains(company.ticker)
        }
        try? modelContext.save()
    }
}

#Preview {
    CompanySearchView()
        .modelContainer(for: [Company.self, Announcement.self, CalendarEvent.self], inMemory: true)
}
