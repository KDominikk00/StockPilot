import Foundation

enum SubscriptionSyncService {
    static func sync(deviceToken: String, tickers: [String]) async {
        do {
            try await BackendAPI.postSubscription(deviceToken: deviceToken, tickers: tickers)
        } catch {
            print("Subscription sync nie powiódł się: \(error)")
        }
    }
}
