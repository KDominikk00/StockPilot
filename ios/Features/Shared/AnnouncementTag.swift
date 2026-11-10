import SwiftUI

/// Category derived from an announcement title. A filing can carry several tags.
enum AnnouncementTag: CaseIterable {
    case results
    case dividend
    case generalMeeting
    case transactions

    var title: String {
        switch self {
        case .results: "Wyniki"
        case .dividend: "Dywidenda"
        case .generalMeeting: "WZA"
        case .transactions: "Transakcje"
        }
    }

    var color: Color {
        switch self {
        case .results: .blue
        case .dividend: .green
        case .generalMeeting: .purple
        case .transactions: .orange
        }
    }

    /// Lower is more important when ranking filings in the briefing.
    var priority: Int {
        switch self {
        case .results, .dividend: 0
        case .generalMeeting: 1
        case .transactions: 3
        }
    }

    /// Lowercased fragments; a title matches when it contains any of them.
    private var keywords: [String] {
        switch self {
        case .results:
            ["wyniki", "wyników", "raport roczny", "raportu rocznego", "raport kwartalny", "raportu kwartalnego",
             "raport półroczny", "raportu półrocznego", "raport okresowy", "raportu okresowego",
             "sprawozdanie finansowe", "results"]
        case .dividend:
            ["dywidend", "dividend", "podziału zysku", "podział zysku"]
        case .generalMeeting:
            ["walne zgromadzeni", "walnego zgromadzeni", "walnym zgromadzeni", "walnemu zgromadzeni",
             "general meeting", "nwz", "zwz"]
        case .transactions:
            ["transakcj", "art. 19", "skup akcji", "skupu akcji", "nabycie akcji", "buyback"]
        }
    }

    static func tags(for title: String) -> [AnnouncementTag] {
        let lowered = title.lowercased()
        return allCases.filter { tag in tag.keywords.contains { lowered.contains($0) } }
    }
}

extension Announcement {
    var tags: [AnnouncementTag] { AnnouncementTag.tags(for: title) }

    /// Untagged filings rank between meetings and routine transaction filings.
    var priority: Int { tags.map(\.priority).min() ?? 2 }
}

struct AnnouncementTagRow: View {
    let announcement: Announcement

    var body: some View {
        let tags = announcement.tags
        if !tags.isEmpty {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tag.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tag.color.opacity(0.15), in: Capsule())
                }
                ReactionChip(announcement: announcement)
            }
            .padding(.top, 2)
        }
    }
}
