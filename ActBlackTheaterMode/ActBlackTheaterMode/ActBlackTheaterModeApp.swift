import SwiftUI

@main
struct ActBlackTheaterModeApp: App {
    
    init() {
        registerDefaultPreferences()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 420, minHeight: 260, maxHeight: 420)
        }
        .windowResizability(.contentSize)  // <- fits to content, no manual sizing
        .windowStyle(.titleBar)
    }
}
