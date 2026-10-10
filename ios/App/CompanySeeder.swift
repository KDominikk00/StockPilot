import Foundation
import SwiftData

private struct SeedFile: Decodable {
    struct SeedCompany: Decodable {
        let isin: String
        let name: String
        let ticker: String
    }
    let companies: [SeedCompany]
}

enum CompanySeeder {
    static func seedIfNeeded(context: ModelContext) {
        let existing = try? context.fetchCount(FetchDescriptor<Company>())
        guard (existing ?? 0) == 0 else { return }

        guard let url = Bundle.main.url(forResource: "companies_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode(SeedFile.self, from: data) else {
            return
        }

        for item in seed.companies {
            let company = Company(ticker: item.ticker, isin: item.isin, nameFull: item.name)
            context.insert(company)
        }
        try? context.save()
    }
}
