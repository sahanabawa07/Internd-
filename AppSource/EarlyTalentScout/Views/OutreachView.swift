import SwiftUI
import AppKit

struct OutreachView: View {
    let store: AppStore
    @State private var copiedDraftID: String?

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Outreach drafts").font(.title2.weight(.semibold))
                    Text("Review the message, copy it into LinkedIn, and mark it sent. Internd then updates the tracker and creates a seven-day follow-up reminder automatically.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Your message template").font(.headline)
                    TextEditor(text: $store.outreachTemplate).frame(minHeight: 75)
                    Text("Optional placeholders: {first_name}, {shared_context}, {career_interest}, and {company}.").font(.caption).foregroundStyle(.secondary)
                }
                .padding(15).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18))

                if store.outreachDrafts.isEmpty {
                    ContentUnavailableView("No outreach drafts yet", systemImage: "text.bubble", description: Text("Create one from a suggested contact in Application tracker or Network."))
                }
                ForEach(store.outreachDrafts) { draft in
                    OutreachDraftCard(draft: draft, copied: copiedDraftID == draft.id, copy: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(draft.message, forType: .string)
                        copiedDraftID = draft.id
                    }, markSent: { store.markOutreachSent(draft) })
                }
            }.padding(22)
        }
    }
}

private struct OutreachDraftCard: View {
    let draft: OutreachDraft
    let copied: Bool
    let copy: () -> Void
    let markSent: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("To: \(draft.recipientName)").font(.headline)
                    if !draft.contactCompany.isEmpty { Text(draft.contactCompany).foregroundStyle(.secondary) }
                    Text(draft.subject).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if draft.opportunityID != nil { Label("Tracker linked", systemImage: "link").font(.caption).foregroundStyle(.secondary) }
            }
            Text(draft.message).textSelection(.enabled)
            Text(draft.rationale).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(copied ? "Copied" : "Copy message", systemImage: copied ? "checkmark" : "doc.on.doc", action: copy)
                    .buttonStyle(.bordered)
                if let url = draft.profileURL {
                    Link("Open LinkedIn profile", destination: url).buttonStyle(.bordered)
                } else if let url = linkedInSearchURL {
                    Link("Search LinkedIn", destination: url).buttonStyle(.bordered)
                }
                Spacer()
                Button("Mark as sent", systemImage: "paperplane.fill", action: markSent)
                    .buttonStyle(.borderedProminent).tint(InterndPalette.ink)
            }
            Text("Marking it sent adds a follow-up reminder for seven days from now. It never sends a message for you.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(17).background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.7)))
    }

    private var linkedInSearchURL: URL? {
        let query = "\(draft.recipientName) \(draft.contactCompany)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://www.linkedin.com/search/results/people/?keywords=\(encoded)")
    }
}
