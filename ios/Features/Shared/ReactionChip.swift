import SwiftUI

private let polishLocale = Locale(identifier: "pl_PL")

extension PriceReaction {
    var label: String {
        let percent = changePercent.formatted(
            .number.precision(.fractionLength(1)).sign(strategy: .always()).locale(polishLocale)
        ) + "%"
        switch kind {
        case .withinHour: return "\(percent) w 1 h"
        case .untilClose: return "\(percent) do zamknięcia"
        case .sincePublication: return "\(percent) od publikacji"
        case .nextSession: return "kolejna sesja \(percent)"
        case .nextSessionLive: return "kolejna sesja (trwa) \(percent)"
        }
    }
}

extension Announcement {
    /// Only price-sensitive filings, and only while Yahoo still has intraday bars for them.
    var showsReaction: Bool {
        guard companyTicker != nil,
              publishedAt > Date().addingTimeInterval(-7 * 24 * 3600) else { return false }
        let tags = self.tags
        return tags.contains(.results) || tags.contains(.dividend)
    }
}

/// Neutral price move after publication: a plain percentage, no arrow or colour, because the
/// filing is not necessarily the cause.
struct ReactionChip: View {
    let announcement: Announcement
    @State private var reaction: PriceReaction?

    var body: some View {
        // Always a real view (empty text until loaded): `.task` never fires on an EmptyView.
        Text(reaction?.label ?? "")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        .task(id: announcement.externalID) {
            guard announcement.showsReaction, let ticker = announcement.companyTicker else { return }
            reaction = await PriceReactionService.shared.reaction(
                forTicker: ticker,
                publishedAt: announcement.publishedAt
            )
        }
    }
}
