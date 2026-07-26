import SwiftUI

struct TrackerView: View {
    let store: AppStore
    @State private var exporting = false

    var body: some View {
        @Bindable var store = store
        List {
            Section {
                HStack {
                    Text("Track deadlines, requirements, and outreach here. Export anytime for Excel, Numbers, or Google Sheets.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Export CSV") { exporting = true }.disabled(store.applications.isEmpty)
                }
            }
            ForEach($store.applications) { $application in
                VStack(alignment: .leading) {
                    TextField("Company", text: $application.company).font(.headline)
                    TextField("Program", text: $application.program)
                    HStack { TextField("Posting date", text: $application.postingDate); TextField("Deadline", text: $application.deadline); TextField("Status", text: $application.status) }
                    TextField("Requirements", text: $application.requirements)
                    TextField("Outreach status", text: $application.outreachStatus)
                    TextField("Notes", text: $application.notes)
                    if let url = application.applicationURL { Link("Application page", destination: url) }
                }
                .padding(.vertical, 5)
            }
            Button("Add application") { store.applications.append(ApplicationRecord(company: "", program: "")) }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .fileExporter(isPresented: $exporting, document: ApplicationCSVDocument(csv: CSVSupport.applicationSpreadsheet(store.applications)), contentType: .commaSeparatedText, defaultFilename: "internship-application-tracker") { _ in }
        .onChange(of: store.applications) { _, _ in store.persistApplications() }
    }
}
