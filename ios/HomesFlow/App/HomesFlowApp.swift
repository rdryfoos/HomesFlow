import SwiftUI
import SwiftData

@main
struct HomesFlowApp: App {
    let modelContainer: ModelContainer

    @StateObject private var router = AppRouter()

    init() {
        CrashReporting.start()
        do {
            modelContainer = try SwiftDataContainer.makeContainer()
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(router: router)
        }
        .modelContainer(modelContainer)
    }
}
