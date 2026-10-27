import Foundation

struct PriceBar {
    let time: Date
    let open: Double?
    let close: Double?
}

/// How the price moved after a filing was published. Purely descriptive: other news the same
/// day moves the price too, so this is not a claim that the filing caused the move.
struct PriceReaction: Equatable {
    enum Kind {
        /// Published during the session, full hour elapsed.
        case withinHour
        /// Published during the session, the session ended before the hour was up.
        case untilClose
        /// Published during the session, less than an hour has passed and the session is still open.
        case sincePublication
        /// Published outside the session; the following session has finished.
        case nextSession
        /// Published outside the session; the following session is still running.
        case nextSessionLive
    }

    let changePercent: Double
    let kind: Kind
}

extension PriceReaction {
    private static let barLength: TimeInterval = 300
    private static let sessionOpenMinute = 9 * 60
    /// The 17:00 bar is the closing auction; it ends at 17:05.
    private static let sessionEndMinute = 17 * 60 + 5
    private static let closingBarMinute = 17 * 60

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return calendar
    }()

    private static func minuteOfDay(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private static func isFinished(_ day: [PriceBar]) -> Bool {
        guard let last = day.last else { return false }
        return minuteOfDay(last.time) >= closingBarMinute
    }

    /// `bars` must be sorted ascending by time.
    static func compute(publishedAt: Date, bars: [PriceBar]) -> PriceReaction? {
        guard !bars.isEmpty else { return nil }
        let sessions = Dictionary(grouping: bars) { calendar.startOfDay(for: $0.time) }
        let publishedDay = calendar.startOfDay(for: publishedAt)
        let publishedMinute = minuteOfDay(publishedAt)

        if let day = sessions[publishedDay],
           (sessionOpenMinute..<sessionEndMinute).contains(publishedMinute) {
            return duringSession(publishedAt: publishedAt, day: day)
        }
        return outsideSession(publishedAt: publishedAt, bars: bars, sessions: sessions)
    }

    private static func duringSession(publishedAt: Date, day: [PriceBar]) -> PriceReaction? {
        let reference = day.last { $0.time.addingTimeInterval(barLength) <= publishedAt && $0.close != nil }?.close
            ?? day.first?.open
        let target = publishedAt.addingTimeInterval(3600)
        guard let reference, reference != 0,
              let end = day.last(where: {
                  $0.time.addingTimeInterval(barLength) <= target
                      && $0.time.addingTimeInterval(barLength) > publishedAt
                      && $0.close != nil
              }),
              let endPrice = end.close,
              let last = day.last else { return nil }

        let kind: Kind
        if target <= last.time.addingTimeInterval(barLength) {
            kind = .withinHour
        } else {
            kind = isFinished(day) ? .untilClose : .sincePublication
        }
        return PriceReaction(changePercent: (endPrice / reference - 1) * 100, kind: kind)
    }

    private static func outsideSession(
        publishedAt: Date,
        bars: [PriceBar],
        sessions: [Date: [PriceBar]]
    ) -> PriceReaction? {
        guard let reference = bars.last(where: { $0.time <= publishedAt && $0.close != nil })?.close,
              reference != 0,
              let next = bars.first(where: { $0.time > publishedAt }),
              let nextDay = sessions[calendar.startOfDay(for: next.time)],
              let close = nextDay.last(where: { $0.close != nil })?.close else { return nil }

        return PriceReaction(
            changePercent: (close / reference - 1) * 100,
            kind: isFinished(nextDay) ? .nextSession : .nextSessionLive
        )
    }
}

private struct IntradayResponse: Decodable {
    struct Quote: Decodable {
        let open: [Double?]
        let close: [Double?]
    }
    struct Indicators: Decodable {
        let quote: [Quote]
    }
    struct Result: Decodable {
        let timestamp: [TimeInterval]?
        let indicators: Indicators
    }
    struct Chart: Decodable {
        let result: [Result]?
    }
    let chart: Chart
}

/// Intraday (5-minute) bars from Yahoo's chart endpoint, one request per ticker, shared by every
/// filing of that company. Yahoo keeps 5-minute history for about 60 days; we ask for one month.
actor PriceReactionService {
    static let shared = PriceReactionService()

    private struct CacheEntry {
        let bars: [PriceBar]?
        let fetchedAt: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private var inFlight: [String: Task<[PriceBar]?, Never>] = [:]
    private let cacheTTL: TimeInterval = 300

    private init() {}

    func reaction(forTicker ticker: String, publishedAt: Date) async -> PriceReaction? {
        guard let bars = await bars(forTicker: ticker) else { return nil }
        return PriceReaction.compute(publishedAt: publishedAt, bars: bars)
    }

    private func bars(forTicker ticker: String) async -> [PriceBar]? {
        if let cached = cache[ticker], Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.bars
        }
        if let task = inFlight[ticker] {
            return await task.value
        }
        let task = Task { await Self.download(ticker: ticker) }
        inFlight[ticker] = task
        let bars = await task.value
        inFlight[ticker] = nil
        cache[ticker] = CacheEntry(bars: bars, fetchedAt: .now)
        return bars
    }

    private static func download(ticker: String) async -> [PriceBar]? {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker).WA?interval=5m&range=1mo") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(IntradayResponse.self, from: data)
            guard let result = response.chart.result?.first,
                  let timestamps = result.timestamp,
                  let quote = result.indicators.quote.first else { return nil }
            return timestamps.enumerated().map { index, timestamp in
                PriceBar(
                    time: Date(timeIntervalSince1970: timestamp),
                    open: index < quote.open.count ? quote.open[index] : nil,
                    close: index < quote.close.count ? quote.close[index] : nil
                )
            }
        } catch {
            return nil
        }
    }
}
