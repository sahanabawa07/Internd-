import SwiftUI

@main
struct EarlyTalentScoutApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup("Internd") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 650)
        }
        .commands {
            CommandMenu("Research") {
                Button("Research opportunities") {
                    Task { await store.runResearch() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!store.canResearch)
            }
        }

        Settings {
            SettingsView(store: store)
        }
    }
}
