import Foundation
import SwiftData

@Model
final class CalendarEvent {
    @Attribute(.unique) var externalID: String
    var companyTicker: String?
    var eventDate: Date
    var reportType: String
    var sourceText: String

    init(externalID: String, companyTicker: String?, eventDate: Date, reportType: String, sourceText: String) {
        self.externalID = externalID
        self.companyTicker = companyTicker
        self.eventDate = eventDate
        self.reportType = reportType
        self.sourceText = sourceText
    }
}
