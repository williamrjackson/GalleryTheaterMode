import SwiftUI

@main
struct ActBlackTheaterModeApp: App {
    
    init() {
        registerDefaultPreferences()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
    }
}
