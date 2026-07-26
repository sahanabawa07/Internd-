import SwiftUI

struct ResearchView: View {
    let store: AppStore

    var body: some View {
        List {
            if !store.report.careerSuggestions.isEmpty {
                Section("Career directions") {
                    ForEach(store.report.careerSuggestions) { direction in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(direction.title).font(.headline)
                            Text(direction.why)
                            Text("Next: \(direction.nextStep)").foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                }
            }
            Section("Verified programs") {
                if store.report.opportunities.isEmpty {
                    ContentUnavailableView("No research yet", systemImage: "sparkle.magnifyingglass", description: Text("Complete your profile and start a research run."))
                }
                ForEach(store.report.opportunities) { opportunity in
                    OpportunityRow(opportunity: opportunity, isTracked: store.applications.contains(where: { $0.company == opportunity.company && $0.program == opportunity.program })) {
                        store.track(opportunity)
                    }
                }
            }
            if !store.report.researchNotes.isEmpty {
                Section("Research notes") { ForEach(store.report.researchNotes, id: \.self) { Text($0).foregroundStyle(.secondary) } }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

struct OpportunityRow: View {
    let opportunity: Opportunity
    let isTracked: Bool
    let track: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(opportunity.company).font(.headline); Text(opportunity.program); Spacer(); Text(opportunity.statusLabel).foregroundStyle(statusColor).font(.caption).padding(.horizontal, 7).padding(.vertical, 3).background(statusColor.opacity(0.15), in: Capsule()) }
            Text(opportunity.fitReason)
            Text("\(opportunity.careerArea) · \(opportunity.location)").foregroundStyle(.secondary)
            Text("Eligibility: \(opportunity.eligibility)").font(.caption).foregroundStyle(.secondary)
            if let postingDate = opportunity.postingDate { Text("Posted: \(postingDate)").font(.caption).foregroundStyle(.secondary) }
            HStack {
                Link("Official page", destination: opportunity.officialProgramURL)
                if let applicationURL = opportunity.applicationURL { Link("Apply", destination: applicationURL) }
                if let linkedInURL = opportunity.linkedInURL { Link("LinkedIn", destination: linkedInURL) }
                Spacer()
                Button(isTracked ? "Tracked" : "Track", systemImage: isTracked ? "checkmark.circle.fill" : "plus.circle", action: track).buttonStyle(.borderless).disabled(isTracked)
            }
        }.padding(.vertical, 6)
    }

    private var statusColor: Color { opportunity.status == "open" ? .green : opportunity.status == "recurring_watch" ? .orange : .secondary }
}
