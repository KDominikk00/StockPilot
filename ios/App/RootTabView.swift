import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var pushManager = PushNotificationManager.shared

    @Query(filter: #Predicate<Company> { $0.isWatched })
    private var watchedCompanies: [Company]

    @Query(filter: #Predicate<Announcement> { $0.isRead == false })
    private var unreadAnnouncements: [Announcement]

    private var unreadCount: Int {
        let watchedTickers = Set(watchedCompanies.filter { !$0.isMuted }.map(\.ticker))
        return unreadAnnouncements.filter { ($0.companyTicker).map(watchedTickers.contains) ?? false }.count
    }

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
            .badge(unreadCount)

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
            syncWatchedCompanies()
        }
    }

    private func uploadSubscription() {
        guard let token = pushManager.deviceToken else { return }
        let tickers = watchedCompanies.filter { !$0.isMuted }.map(\.ticker)
        Task {
            await SubscriptionSyncService.sync(deviceToken: token, tickers: tickers)
        }
    }

    /// Fires whenever the watchlist changes (including adding a new
    /// company), so a newly-watched company gets its announcements/calendar
    /// pulled in immediately rather than waiting for the next manual
    /// pull-to-refresh or the ~20-minute background refresh.
    private func syncWatchedCompanies() {
        let tickers = watchedCompanies.map(\.ticker)
        guard !tickers.isEmpty else { return }
        let mutedTickers = Set(watchedCompanies.filter(\.isMuted).map(\.ticker))
        Task {
            try? await SyncService.syncAnnouncements(
                context: modelContext,
                watchedTickers: tickers,
                mutedTickers: mutedTickers
            )
            try? await SyncService.syncCalendarEvents(context: modelContext, watchedTickers: tickers)
        }
    }
}
