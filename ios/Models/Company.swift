import Foundation
import SwiftData

@Model
final class Company {
    @Attribute(.unique) var ticker: String
    var isin: String
    var nameFull: String
    var isWatched: Bool
    var isActive: Bool
    var isMuted: Bool = false

    init(
        ticker: String,
        isin: String,
        nameFull: String,
        isWatched: Bool = false,
        isActive: Bool = true,
        isMuted: Bool = false
    ) {
        self.ticker = ticker
        self.isin = isin
        self.nameFull = nameFull
        self.isWatched = isWatched
        self.isActive = isActive
        self.isMuted = isMuted
    }

    var displayName: String {
        nameFull
            .replacingOccurrences(of: " SPÓŁKA AKCYJNA", with: "")
            .replacingOccurrences(of: " SPÓŁKA EUROPEJSKA", with: "")
            .capitalized(with: Locale(identifier: "pl_PL"))
    }
}
