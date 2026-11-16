import SwiftUI

@main
struct HealthDuoWatchApp: App {
    @StateObject private var session = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(session)
        }
    }
}
