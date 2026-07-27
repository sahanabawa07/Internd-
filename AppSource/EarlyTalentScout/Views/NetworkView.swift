import SwiftUI
import UniformTypeIdentifiers

struct NetworkView: View {
    let store: AppStore
    @State private var showingImporter = false
    @State private var manualName = ""
    @State private var manualCompany = ""
    @State private var manualContext = ""
    @State private var manualProfileURL = ""

    var body: some View {
        @Bindable var store = store
        List {
            Section("Find warm connections") {
                Text("Export your LinkedIn connections as a CSV, then import it here. The Network Scout identifies relevant people using that export and public alumni context. It does not access your logged-in LinkedIn account.")
                    .foregroundStyle(.secondary)
                Button("Import LinkedIn connections CSV") { showingImporter = true }
            }
            Section("Add a LinkedIn contact") {
                if !store.networkLeadOrganization.isEmpty {
                    Text("For your networking-first lead: find a real person at \(store.networkLeadOrganization) on LinkedIn, then save them here to draft a message.")
                        .foregroundStyle(.secondary)
                }
                TextField("Name", text: $manualName)
                TextField("Organization", text: $manualCompany)
                TextField("Shared context (optional)", text: $manualContext)
                TextField("LinkedIn profile URL (optional)", text: $manualProfileURL)
                Button("Save contact") {
                    store.addManualContact(name: manualName, company: manualCompany, sharedContext: manualContext, profileURLText: manualProfileURL)
                    manualName = ""; manualCompany = ""; manualContext = ""; manualProfileURL = ""
                }.disabled(manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manualCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section("Suggested contacts") {
                if store.networkContacts.isEmpty {
                    ContentUnavailableView("No contacts analyzed", systemImage: "person.3", description: Text("Import a connections CSV to find relevant warm introductions."))
                }
                ForEach(store.networkContacts) { contact in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(contact.name).font(.system(size: 20, weight: .semibold))
                            Text(contact.company).foregroundStyle(.secondary)
                            Spacer()
                            Button("Draft message") { Task { await store.createOutreach(for: contact, opportunity: nil) } }
                        }
                        Text(contact.headline).foregroundStyle(.secondary)
                        Text(contact.sharedContext)
                        Text(contact.reachOutReason).font(.system(size: 15)).foregroundStyle(.secondary)
                        if let url = contact.profileURL { Link("Open public profile", destination: url) }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section("Relationship follow-ups") {
                ForEach($store.relationships) { $relationship in
                    VStack(alignment: .leading) {
                        Text("\(relationship.name) · \(relationship.company)").font(.system(size: 20, weight: .semibold))
                        Text(relationship.sharedContext).foregroundStyle(.secondary)
                        HStack { TextField("Last contact", text: $relationship.lastContact); TextField("Follow up", text: $relationship.followUpDate) }
                        TextField("Relationship", text: $relationship.relationshipStrength)
                        TextField("Conversation notes", text: $relationship.notes)
                        Button("Draft message") {
                            let contact = NetworkContact(name: relationship.name, headline: "", company: relationship.company, sharedContext: relationship.sharedContext, profileURL: nil, reachOutReason: "A saved networking relationship.")
                            Task { await store.createOutreach(for: contact, opportunity: nil) }
                        }.buttonStyle(.borderless)
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
        .onAppear { if manualCompany.isEmpty { manualCompany = store.networkLeadOrganization } }
    }
}
