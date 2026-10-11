import SwiftUI
import SwiftData

@main
struct StockPilotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Company.self, Announcement.self, CalendarEvent.self)
        } catch {
            fatalError("Nie udało się zainicjalizować SwiftData: \(error)")
        }
        CompanySeeder.seedIfNeeded(context: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundRefreshManager.shared.scheduleNext()
            }
        }
    }
}
