import Foundation

struct Quote {
    let price: Double
    let changePercent: Double
}

private struct ChartResponse: Decodable {
    struct Result: Decodable {
        struct Meta: Decodable {
            let regularMarketPrice: Double?
            let regularMarketChangePercent: Double?
        }
        let meta: Meta
    }
    struct Chart: Decodable {
        let result: [Result]?
    }
    let chart: Chart
}

/// Quotes come from Yahoo Finance's public chart endpoint (no API key, no
/// anti-bot wall) rather than stooq.pl as originally planned — stooq retired
/// its simple CSV endpoint and now gates everything behind a JS proof-of-work
/// challenge an on-device fetch can't solve. See notes in the plan.
actor QuoteService {
    static let shared = QuoteService()

    private struct CacheEntry {
        let quote: Quote?
        let fetchedAt: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 60
    private let decoder = JSONDecoder()

    private init() {}

    func quote(forTicker ticker: String) async -> Quote? {
        if let cached = cache[ticker], Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.quote
        }

        let quote = await fetchQuote(ticker: ticker)
        cache[ticker] = CacheEntry(quote: quote, fetchedAt: .now)
        return quote
    }

    private func fetchQuote(ticker: String) async -> Quote? {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker).WA") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try decoder.decode(ChartResponse.self, from: data)
            guard let meta = response.chart.result?.first?.meta,
                  let price = meta.regularMarketPrice else {
                return nil
            }
            return Quote(price: price, changePercent: meta.regularMarketChangePercent ?? 0)
        } catch {
            return nil
        }
    }
}
