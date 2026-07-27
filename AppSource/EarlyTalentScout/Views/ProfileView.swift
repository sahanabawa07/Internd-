import SwiftUI

struct ProfileView: View {
    let store: AppStore
    @Binding var showingImporter: Bool

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Resume") {
                HStack {
                    Text(store.profile.resumeText.isEmpty ? "No resume imported" : "Resume ready")
                        .foregroundStyle(store.profile.resumeText.isEmpty ? Color.secondary : Color.green)
                    Spacer()
                    Button("Import PDF or text") { showingImporter = true }
                }
                TextEditor(text: $store.profile.resumeText)
                    .font(.system(size: 18))
                    .frame(minHeight: 140)
            }
            Section("Your search") {
                Picker("College year", selection: $store.profile.schoolYear) {
                    Text("First year").tag("First year")
                    Text("Second year").tag("Second year")
                    Text("Other").tag("Other")
                }
                TextField("Expected graduation", text: $store.profile.graduation, prompt: Text("May 2029"))
                TextField("Locations / remote preference", text: $store.profile.locations, prompt: Text("Chicago, remote"))
                TextField("Work authorization constraints (optional)", text: $store.profile.workAuthorization)
                TextField("Target companies", text: $store.profile.targetCompanies, prompt: Text("Microsoft, Adobe, Deloitte"))
                TextField("Career interests", text: $store.profile.careerInterests, prompt: Text("Product, climate tech, data"))
            }
            Section {
                Button("Start multi-agent research") { Task { await store.runResearch() } }
                    .disabled(!store.canResearch)
                if let message = store.researchReadinessMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                if store.profileRefreshQueued {
                    Label("Profile updated — refreshing recommendations after you finish editing.", systemImage: "arrow.clockwise")
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Five focused agents analyze, research, verify, and rank results. Target companies, interests, or a resume are enough to begin. Your API key is stored in macOS Keychain.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .padding()
        .onChange(of: store.profile) { _, _ in store.profileDidChange() }
        .onDisappear { store.persistApplications() }
    }
}
