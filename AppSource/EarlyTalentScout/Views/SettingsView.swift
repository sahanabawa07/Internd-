import SwiftUI

struct SettingsView: View {
    let store: AppStore
    @State private var saveMessage: String?

    var body: some View {
        @Bindable var store = store
        Form {
            Section("OpenAI") {
                SecureField("API key", text: $store.apiKey)
                Button("Save to Keychain") {
                    do { try store.saveAPIKey(); saveMessage = "Saved securely in your macOS Keychain." }
                    catch { saveMessage = error.localizedDescription }
                }
                if let saveMessage { Text(saveMessage).font(.system(size: 15)).foregroundStyle(.secondary) }
            }
            Section("Research policy") {
                Toggle("Refresh research when Internd opens", isOn: Binding(get: { store.autoRefreshOnLaunch }, set: { store.setAutoRefreshOnLaunch($0) }))
                Text("When this is on, Internd refreshes opportunities and the Watch List after you tap Begin. Each refresh uses your OpenAI API credit. You can still refresh manually from Research.")
                    .foregroundStyle(.secondary)
                Text("The research and link-verification agents prefer employer-owned careers and program pages. LinkedIn is only a supporting source, never the sole application link.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .padding()
    }
}
