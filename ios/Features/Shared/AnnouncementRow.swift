import SwiftUI

/// One filing: unread dot, optional ticker, title, timestamp and tags. Shared by the briefing,
/// the announcements feed and the company page.
struct AnnouncementRow: View {
    let item: Announcement
    var showsTicker = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !item.isRead {
                Circle()
                    .fill(.tint)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                if showsTicker {
                    Text(item.companyTicker ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(item.title)
                    .font(item.isRead ? .body : .body.bold())
                    .foregroundStyle(.primary)
                Text(item.publishedAt.polishDateTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                AnnouncementTagRow(announcement: item)
            }
        }
    }
}
