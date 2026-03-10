import SwiftUI

@main
struct ActBlackTheaterModeApp: App {
    
    init() {
        registerDefaultPreferences()
        DisplayModeController.shared.restorePendingModeIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
    }
}
