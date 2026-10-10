import SwiftUI
import SwiftData

@main
struct GPWCommandCenterApp: App {
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
    }
}
