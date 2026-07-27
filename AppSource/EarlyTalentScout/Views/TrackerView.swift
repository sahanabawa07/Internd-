import SwiftUI

struct TrackerView: View {
    let store: AppStore
    @State private var exporting = false
    @State private var selectedApplicationID: UUID?

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Application tracker").font(.system(size: 28, weight: .semibold))
                        Text("Each application carries its deadlines, requirements, outreach, and preparation stages with it.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Export CSV") { exporting = true }.disabled(store.applications.isEmpty)
                }

                if store.applications.isEmpty {
                    ContentUnavailableView("Nothing is in your tracker yet", systemImage: "checklist", description: Text("Choose Add to tracker on a research result to keep its official link and details here."))
                } else {
                    Text("Click a row to open its full details, requirements, sources, preparation checklist, and outreach plan.")
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                    applicationTable
                    if let selectedIndex = store.applications.firstIndex(where: { $0.id == selectedApplicationID }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Application details").font(.system(size: 25, weight: .semibold))
                            ApplicationCard(store: store, application: $store.applications[selectedIndex])
                        }
                    }
                }
                Button("Add application manually", systemImage: "plus") {
                    store.applications.append(ApplicationRecord(company: "", program: ""))
                    store.persistApplications()
                }
            }.padding(22)
        }
        .fileExporter(isPresented: $exporting, document: ApplicationCSVDocument(csv: CSVSupport.applicationSpreadsheet(store.applications)), contentType: .commaSeparatedText, defaultFilename: "internd-application-tracker") { _ in }
        .onChange(of: store.applications) { _, _ in store.persistApplications() }
        .onAppear { if selectedApplicationID == nil { selectedApplicationID = store.applications.first?.id } }
    }

    private var applicationTable: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                GridRow {
                    tableHeader("Company", width: 150)
                    tableHeader("Program", width: 210)
                    tableHeader("Stage", width: 160)
                    tableHeader("Posted", width: 115)
                    tableHeader("Deadline", width: 125)
                    tableHeader("Requirements", width: 230)
                    tableHeader("Contacts", width: 110)
                    tableHeader("Prep", width: 80)
                    tableHeader("Link", width: 100)
                }
                Divider().gridCellColumns(9)
                ForEach(store.applications.indices, id: \.self) { index in
                    ApplicationTableRow(store: store, application: Binding(get: { store.applications[index] }, set: { store.applications[index] = $0 }), isSelected: selectedApplicationID == store.applications[index].id) {
                        selectedApplicationID = store.applications[index].id
                    }
                    Divider().gridCellColumns(9)
                }
            }
            .padding(14)
            .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 19))
        }
    }

    private func tableHeader(_ title: String, width: CGFloat) -> some View {
        Text(title.uppercased())
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(InterndPalette.ink.opacity(0.72))
            .frame(width: width, alignment: .leading)
    }
}

private struct ApplicationTableRow: View {
    let store: AppStore
    @Binding var application: ApplicationRecord
    let isSelected: Bool
    let select: () -> Void
    private let stages = ["Saved", "Researching", "Resume tailored", "Network outreach", "Materials checked", "Ready to submit", "Submitted", "Interviewing", "Closed"]

    var body: some View {
        GridRow {
            TextField("Company", text: $application.company).frame(width: 150, alignment: .leading)
            TextField("Program", text: $application.program).frame(width: 210, alignment: .leading)
            Picker("Stage", selection: $application.status) { ForEach(stages, id: \.self) { Text($0).tag($0) } }
                .labelsHidden().frame(width: 160, alignment: .leading)
            TextField("Posted", text: $application.postingDate).frame(width: 115, alignment: .leading)
            TextField("Deadline", text: $application.deadline).frame(width: 125, alignment: .leading)
            Text(application.requirements.isEmpty ? "—" : application.requirements)
                .font(.system(size: 15)).lineLimit(2).frame(width: 230, alignment: .leading)
            Text("\(store.suggestedContacts(for: application.company).count) people")
                .font(.system(size: 15)).frame(width: 110, alignment: .leading)
            Text("\(application.preparationProgress)/4")
                .font(.system(size: 15, weight: .medium)).frame(width: 80, alignment: .leading)
            Group {
                if let url = application.applicationURL { Link("Open", destination: url) }
                else { Text("—").foregroundStyle(.secondary) }
            }.frame(width: 100, alignment: .leading)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 5)
        .background(isSelected ? InterndPalette.pink.opacity(0.28) : .clear, in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
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
                    TextField("Company", text: $application.company).font(.system(size: 25, weight: .semibold))
                    TextField("Internship or program", text: $application.program).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Stage", selection: $application.status) { ForEach(stages, id: \.self) { Text($0).tag($0) } }
                    .labelsHidden().frame(width: 155)
            }
            if !application.description.isEmpty { Text(application.description).font(.system(size: 17)) }
            if !application.whyThisMatches.isEmpty { Label("Why this matches you: \(application.whyThisMatches)", systemImage: "sparkles").font(.system(size: 17)).foregroundStyle(.secondary) }

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
                            Text("\(fact.label): \(fact.value)").font(.system(size: 15))
                            Text(fact.classificationLabel).font(.system(size: 14)).foregroundStyle(fact.classification == "confirmed" ? .green : fact.classification == "historical" ? .orange : .secondary)
                            if let url = fact.sourceURL { Link("View source", destination: url).font(.system(size: 14)) }
                        }.padding(.vertical, 2)
                    }
                }.font(.system(size: 16, weight: .medium)).tint(InterndPalette.ink)
            }

            if !application.preparationChecklist.isEmpty || !application.resumeFocus.isEmpty || !application.skillFocus.isEmpty {
                Divider()
                Text("Prepare before applications open").font(.system(size: 20, weight: .semibold))
                if !application.preparationChecklist.isEmpty { LabeledContent("Preparation", value: application.preparationChecklist.joined(separator: " · ")) }
                if !application.resumeFocus.isEmpty { LabeledContent("Resume focus", value: application.resumeFocus.joined(separator: " · ")) }
                if !application.skillFocus.isEmpty { LabeledContent("Skills to build", value: application.skillFocus.joined(separator: " · ")) }
                HStack {
                    Button("Tailor resume") { store.startResumeTailor(for: application) }
                    Button("Build skills plan") { store.startSkillsPlan(for: application) }
                }
                Text("For recurring programs, this is preparation guidance from current or prior-cycle information—not a promise of next cycle's requirements.").font(.system(size: 15)).foregroundStyle(.secondary)
            }

            Divider()
            Text("Preparation progress \(application.preparationProgress)/4").font(.system(size: 20, weight: .semibold))
            ProgressView(value: Double(application.preparationProgress), total: 4).tint(InterndPalette.ink)
            Toggle("Company research complete", isOn: progressBinding(\.companyResearchDone))
            Toggle("Resume tailored", isOn: progressBinding(\.resumeTailored))
            Toggle("Outreach drafted or sent", isOn: progressBinding(\.outreachPrepared))
            Toggle("Application materials checked", isOn: progressBinding(\.materialsChecked))
            Toggle("Interview prep complete", isOn: progressBinding(\.interviewPrepDone))

            Divider()
            Text("Suggested people to reach out to").font(.system(size: 20, weight: .semibold))
            let contacts = store.suggestedContacts(for: application.company)
            if contacts.isEmpty {
                Text("Import your LinkedIn Connections CSV or add people in Network to see up to three real contacts here. Internd will never invent connections.")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                Button("Open Network") { store.selection = .network }.font(.system(size: 15))
            } else {
                ForEach(contacts) { contact in
                    HStack {
                        VStack(alignment: .leading) { Text(contact.name); Text("\(contact.company) · \(contact.sharedContext)").font(.system(size: 15)).foregroundStyle(.secondary) }
                        Spacer()
                        Button("Draft outreach") { Task { await store.createOutreach(for: contact, opportunity: application) } }.buttonStyle(.borderless)
                    }
                }
            }
            TextField("Outreach status", text: $application.outreachStatus)
            TextField("Personal notes", text: $application.notes, axis: .vertical).lineLimit(2...4)
            Text("Last checked \(application.lastChecked.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 15)).foregroundStyle(.tertiary)
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
