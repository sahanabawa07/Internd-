import SwiftUI

struct TrackerView: View {
    let store: AppStore
    @State private var exporting = false

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Application tracker").font(.title2.weight(.semibold))
                        Text("Each application carries its deadlines, requirements, outreach, and preparation stages with it.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Export CSV") { exporting = true }.disabled(store.applications.isEmpty)
                }

                if store.applications.isEmpty {
                    ContentUnavailableView("Nothing is in your tracker yet", systemImage: "checklist", description: Text("Choose Add to tracker on a research result to keep its official link and details here."))
                }
                ForEach(store.applications.indices, id: \.self) { index in
                    ApplicationCard(store: store, application: $store.applications[index])
                }
                Button("Add application manually", systemImage: "plus") {
                    store.applications.append(ApplicationRecord(company: "", program: ""))
                    store.persistApplications()
                }
            }.padding(22)
        }
        .fileExporter(isPresented: $exporting, document: ApplicationCSVDocument(csv: CSVSupport.applicationSpreadsheet(store.applications)), contentType: .commaSeparatedText, defaultFilename: "internd-application-tracker") { _ in }
        .onChange(of: store.applications) { _, _ in store.persistApplications() }
    }
}

private struct ApplicationCard: View {
    let store: AppStore
    @Binding var application: ApplicationRecord
    private let stages = ["Saved", "Researching", "Resume tailored", "Network outreach", "Materials checked", "Ready to submit", "Submitted", "Interviewing", "Closed"]

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    TextField("Company", text: $application.company).font(.title3.weight(.semibold))
                    TextField("Internship or program", text: $application.program).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Stage", selection: $application.status) { ForEach(stages, id: \.self) { Text($0).tag($0) } }
                    .labelsHidden().frame(width: 155)
            }
            if !application.description.isEmpty { Text(application.description).font(.subheadline) }
            if !application.whyThisMatches.isEmpty { Label("Why this matches you: \(application.whyThisMatches)", systemImage: "sparkles").font(.subheadline).foregroundStyle(.secondary) }

            HStack {
                TextField("Posting date", text: $application.postingDate)
                TextField("Application deadline", text: $application.deadline)
            }
            TextField("Application requirements", text: $application.requirements, axis: .vertical).lineLimit(2...4)
            if let url = application.applicationURL { Link("Open official application page", destination: url) }
            if !application.verifiedFacts.isEmpty {
                DisclosureGroup("Research audit · \(application.officialSourceType)") {
                    ForEach(application.verifiedFacts) { fact in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(fact.label): \(fact.value)").font(.caption)
                            Text(fact.classificationLabel).font(.caption2).foregroundStyle(fact.classification == "confirmed" ? .green : fact.classification == "historical" ? .orange : .secondary)
                            if let url = fact.sourceURL { Link("View source", destination: url).font(.caption2) }
                        }.padding(.vertical, 2)
                    }
                }.font(.caption.weight(.medium)).tint(InterndPalette.ink)
            }

            if !application.preparationChecklist.isEmpty || !application.resumeFocus.isEmpty || !application.skillFocus.isEmpty {
                Divider()
                Text("Prepare before applications open").font(.headline)
                if !application.preparationChecklist.isEmpty { LabeledContent("Preparation", value: application.preparationChecklist.joined(separator: " · ")) }
                if !application.resumeFocus.isEmpty { LabeledContent("Resume focus", value: application.resumeFocus.joined(separator: " · ")) }
                if !application.skillFocus.isEmpty { LabeledContent("Skills to build", value: application.skillFocus.joined(separator: " · ")) }
                HStack {
                    Button("Tailor resume") { store.startResumeTailor(for: application) }
                    Button("Build skills plan") { store.startSkillsPlan(for: application) }
                }
                Text("For recurring programs, this is preparation guidance from current or prior-cycle information—not a promise of next cycle's requirements.").font(.caption).foregroundStyle(.secondary)
            }

            Divider()
            Text("Preparation progress \(application.preparationProgress)/4").font(.headline)
            ProgressView(value: Double(application.preparationProgress), total: 4).tint(InterndPalette.ink)
            Toggle("Company research complete", isOn: progressBinding(\.companyResearchDone))
            Toggle("Resume tailored", isOn: progressBinding(\.resumeTailored))
            Toggle("Outreach drafted or sent", isOn: progressBinding(\.outreachPrepared))
            Toggle("Application materials checked", isOn: progressBinding(\.materialsChecked))
            Toggle("Interview prep complete", isOn: progressBinding(\.interviewPrepDone))

            Divider()
            Text("Suggested people to reach out to").font(.headline)
            let contacts = store.suggestedContacts(for: application.company)
            if contacts.isEmpty {
                Text("Import your LinkedIn Connections CSV or add people in Network to see up to three real contacts here. Internd will never invent connections.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open Network") { store.selection = .network }.font(.caption)
            } else {
                ForEach(contacts) { contact in
                    HStack {
                        VStack(alignment: .leading) { Text(contact.name); Text("\(contact.company) · \(contact.sharedContext)").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Button("Draft outreach") { Task { await store.createOutreach(for: contact, opportunity: application) } }.buttonStyle(.borderless)
                    }
                }
            }
            TextField("Outreach status", text: $application.outreachStatus)
            TextField("Personal notes", text: $application.notes, axis: .vertical).lineLimit(2...4)
            Text("Last checked \(application.lastChecked.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(17).background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.7)))
    }

    private func progressBinding(_ keyPath: WritableKeyPath<ApplicationRecord, Bool>) -> Binding<Bool> {
        Binding(get: { application[keyPath: keyPath] }, set: { newValue in
            application[keyPath: keyPath] = newValue
            store.setManualProgress(for: application.id, keyPath: keyPath, to: newValue)
        })
    }
}
