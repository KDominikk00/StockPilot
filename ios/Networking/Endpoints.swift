import Foundation

enum BackendConfig {
    static let baseURL = URL(string: "http://localhost:3000")!
}

struct AnnouncementDTO: Decodable {
    let external_id: String
    let title: String
    let url: String
    let published_at: String
    let match_confidence: String
    let ticker: String
}

struct CalendarEventDTO: Decodable {
    let external_id: String
    let event_type: String
    let event_date: String
    let source_text: String?
    let ticker: String
}

private struct AnnouncementsResponse: Decodable {
    let items: [AnnouncementDTO]
}

private struct CalendarResponse: Decodable {
    let items: [CalendarEventDTO]
}

enum BackendAPI {
    private static let decoder = JSONDecoder()

    static func fetchAnnouncements(tickers: [String]) async throws -> [AnnouncementDTO] {
        guard !tickers.isEmpty else { return [] }
        var url = BackendConfig.baseURL.appendingPathComponent("v1/announcements")
        url = url.appending(queryItems: [URLQueryItem(name: "tickers", value: tickers.joined(separator: ","))])
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(AnnouncementsResponse.self, from: data).items
    }

    static func fetchCalendar(tickers: [String]) async throws -> [CalendarEventDTO] {
        guard !tickers.isEmpty else { return [] }
        var url = BackendConfig.baseURL.appendingPathComponent("v1/calendar")
        url = url.appending(queryItems: [URLQueryItem(name: "tickers", value: tickers.joined(separator: ","))])
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(CalendarResponse.self, from: data).items
    }
}
