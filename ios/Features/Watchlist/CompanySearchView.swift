import SwiftUI
import SwiftData

struct CompanySearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Company.nameFull) private var allCompanies: [Company]
    @State private var searchText = ""

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
                    company.isWatched.toggle()
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
                        if company.isWatched {
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
                    Button("Gotowe") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CompanySearchView()
        .modelContainer(for: [Company.self, Announcement.self, CalendarEvent.self], inMemory: true)
}
