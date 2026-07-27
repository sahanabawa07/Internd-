import SwiftUI

struct ResumeTailorView: View {
    let store: AppStore
    @State private var description = ""

    var body: some View {
        List {
            Section("Role description") {
                TextEditor(text: $description).frame(minHeight: 180)
                Button("Tailor my resume") { Task { await store.tailorResume(for: description) } }
                    .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let tailored = store.tailoredResume {
                Section("Tailoring plan") {
                    Text(tailored.roleSummary)
                    Text("Keywords: \(tailored.priorityKeywords.joined(separator: ", "))").foregroundStyle(.secondary)
                    ForEach(tailored.suggestedChanges, id: \.self) { Text("• \($0)") }
                }
                Section("Truth-preserving bullet examples") { ForEach(tailored.tailoredBulletExamples, id: \.self) { Text($0) } }
                Section("Check before using") { ForEach(tailored.cautions, id: \.self) { Text($0).foregroundStyle(.secondary) } }
            }
        }
        .onAppear {
            if description.isEmpty, !store.resumeTailorContext.isEmpty { description = store.resumeTailorContext }
        }
    }
}
