import SwiftUI
import SwiftData

struct RootTabView: View {
    @StateObject private var pushManager = PushNotificationManager.shared

    @Query(filter: #Predicate<Company> { $0.isWatched })
    private var watchedCompanies: [Company]

    var body: some View {
        TabView {
            NavigationStack {
                WatchlistView()
            }
            .tabItem { Label("Watchlist", systemImage: "star.fill") }

            NavigationStack {
                AnnouncementsFeedView()
            }
            .tabItem { Label("Komunikaty", systemImage: "megaphone.fill") }

            NavigationStack {
                EarningsCalendarView()
            }
            .tabItem { Label("Kalendarz", systemImage: "calendar") }
        }
        .task {
            pushManager.requestAuthorizationAndRegister()
        }
        .onChange(of: pushManager.deviceToken) { _, _ in
            uploadSubscription()
        }
        .onChange(of: watchedCompanies) { _, _ in
            uploadSubscription()
        }
    }

    private func uploadSubscription() {
        guard let token = pushManager.deviceToken else { return }
        let tickers = watchedCompanies.map(\.ticker)
        Task {
            await SubscriptionSyncService.sync(deviceToken: token, tickers: tickers)
        }
    }
}
