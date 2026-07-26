import SwiftUI
import AppKit

struct OutreachView: View {
    let store: AppStore

    var body: some View {
        @Bindable var store = store
        List {
            Section("Review before sending") {
                Text("These are editable drafts. Copy a message into LinkedIn or email yourself after reviewing it; the app does not auto-send messages.").foregroundStyle(.secondary)
                TextEditor(text: $store.outreachTemplate).frame(minHeight: 75)
                Text("Use {first_name}, {shared_context}, {career_interest}, and {company} as optional placeholders.").font(.caption).foregroundStyle(.secondary)
            }
            if store.outreachDrafts.isEmpty {
                ContentUnavailableView("No outreach drafts", systemImage: "text.bubble", description: Text("Create one from a suggested network contact."))
            }
            ForEach(store.outreachDrafts) { draft in
                VStack(alignment: .leading, spacing: 6) {
                    Text("To: \(draft.recipientName)").font(.headline)
                    Text(draft.subject).foregroundStyle(.secondary)
                    Text(draft.message).textSelection(.enabled)
                    Text(draft.rationale).font(.caption).foregroundStyle(.secondary)
                    Button("Copy message") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(draft.message, forType: .string)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
