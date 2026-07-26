import SwiftUI
import UniformTypeIdentifiers

struct NetworkView: View {
    let store: AppStore
    @State private var showingImporter = false

    var body: some View {
        @Bindable var store = store
        List {
            Section("Find warm connections") {
                Text("Export your LinkedIn connections as a CSV, then import it here. The Network Scout identifies relevant people using that export and public alumni context. It does not access your logged-in LinkedIn account.")
                    .foregroundStyle(.secondary)
                Button("Import LinkedIn connections CSV") { showingImporter = true }
            }
            Section("Suggested contacts") {
                if store.networkContacts.isEmpty {
                    ContentUnavailableView("No contacts analyzed", systemImage: "person.3", description: Text("Import a connections CSV to find relevant warm introductions."))
                }
                ForEach(store.networkContacts) { contact in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(contact.name).font(.headline)
                            Text(contact.company).foregroundStyle(.secondary)
                            Spacer()
                            Button("Draft message") { Task { await store.createOutreach(for: contact, opportunity: nil) } }
                        }
                        Text(contact.headline).foregroundStyle(.secondary)
                        Text(contact.sharedContext)
                        Text(contact.reachOutReason).font(.caption).foregroundStyle(.secondary)
                        if let url = contact.profileURL { Link("Open public profile", destination: url) }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section("Relationship follow-ups") {
                ForEach($store.relationships) { $relationship in
                    VStack(alignment: .leading) {
                        Text("\(relationship.name) · \(relationship.company)").font(.headline)
                        Text(relationship.sharedContext).foregroundStyle(.secondary)
                        HStack { TextField("Last contact", text: $relationship.lastContact); TextField("Follow up", text: $relationship.followUpDate) }
                        TextField("Relationship", text: $relationship.relationshipStrength)
                        TextField("Conversation notes", text: $relationship.notes)
                    }.padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.commaSeparatedText]) { result in
            guard case .success(let url) = result else { return }
            do {
                guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
                defer { url.stopAccessingSecurityScopedResource() }
                let connections = try String(contentsOf: url, encoding: .utf8)
                Task { await store.findConnections(csv: connections) }
            } catch { store.errorMessage = "Could not read the connections CSV." }
        }
        .onChange(of: store.relationships) { _, _ in store.persistApplications() }
    }
}
