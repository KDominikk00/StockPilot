import SwiftUI

struct RootTabView: View {
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
    }
}
