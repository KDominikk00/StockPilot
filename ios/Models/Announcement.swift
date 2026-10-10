import Foundation
import SwiftData

@Model
final class Announcement {
    @Attribute(.unique) var externalID: String
    var companyTicker: String?
    var title: String
    var url: String
    var publishedAt: Date
    var isRead: Bool

    init(externalID: String, companyTicker: String?, title: String, url: String, publishedAt: Date, isRead: Bool = false) {
        self.externalID = externalID
        self.companyTicker = companyTicker
        self.title = title
        self.url = url
        self.publishedAt = publishedAt
        self.isRead = isRead
    }
}
