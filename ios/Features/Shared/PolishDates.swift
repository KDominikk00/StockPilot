import Foundation

private let polishLocale = Locale(identifier: "pl_PL")

extension Date {
    var polishDate: String {
        formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(polishLocale))
    }

    var polishDateTime: String {
        formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(polishLocale))
    }

    /// "październik 2026" (nominative, unlike the genitive "października" that FormatStyle produces).
    var polishMonthYear: String {
        let formatter = DateFormatter()
        formatter.locale = polishLocale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: self).localizedCapitalized
    }
}
