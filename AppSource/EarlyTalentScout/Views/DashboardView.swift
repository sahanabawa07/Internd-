import SwiftUI

struct DashboardView: View {
    let store: AppStore

    private var submitted: Int { store.applications.filter { $0.status.localizedCaseInsensitiveContains("submitted") }.count }
    private var interviews: Int { store.applications.filter { $0.status.localizedCaseInsensitiveContains("interview") }.count }
    private var nextDeadline: ApplicationRecord? {
        store.applications.first { !$0.deadline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your next best move").font(.headline)
                    Text(nextMove).font(.title3)
                    Text(nextMoveDetail).foregroundStyle(.secondary)
                    Button(nextButtonTitle) { store.selection = nextSection }
                }
                .padding(.vertical, 8)
            }

            Section("Progress") {
                HStack(spacing: 28) {
                    Metric(value: store.applications.count, label: "Tracked")
                    Metric(value: submitted, label: "Submitted")
                    Metric(value: interviews, label: "Interviews")
                    Metric(value: store.relationships.count, label: "Connections")
                }
                .padding(.vertical, 6)
            }

            Section("Next actions") {
                if let deadline = nextDeadline {
                    ActionRow(icon: "calendar", title: "Review \(deadline.company) deadline", detail: deadline.deadline) { store.selection = .tracker }
                }
                if !store.relationships.isEmpty {
                    ActionRow(icon: "person.2", title: "Review networking follow-ups", detail: "\(store.relationships.count) saved relationship\(store.relationships.count == 1 ? "" : "s")") { store.selection = .network }
                }
                if store.report.opportunities.isEmpty {
                    ActionRow(icon: "sparkle.magnifyingglass", title: "Run your first opportunity search", detail: "Find early-talent programs that match you") { store.selection = .profile }
                }
                if store.applications.isEmpty && !store.report.opportunities.isEmpty {
                    ActionRow(icon: "plus.circle", title: "Track a promising program", detail: "Save programs from Research into your tracker") { store.selection = .research }
                }
                if store.applications.isEmpty && store.report.opportunities.isEmpty && store.relationships.isEmpty {
                    Text("Start with your profile, then research opportunities and build your outreach list.").foregroundStyle(.secondary)
                }
            }

            Section("Quick start") {
                HStack {
                    Button("Update profile") { store.selection = .profile }
                    Button("Research programs") { store.selection = .research }
                    Button("Tailor resume") { store.selection = .tailor }
                    Button("Interview prep") { store.selection = .interview }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private var nextMove: String {
        if store.profile.resumeText.isEmpty && store.profile.careerInterests.isEmpty { return "Complete your profile" }
        if store.report.opportunities.isEmpty { return "Research early-talent programs" }
        if store.applications.isEmpty { return "Add your first application to the tracker" }
        if let deadline = nextDeadline { return "Check \(deadline.company) before \(deadline.deadline)" }
        return "Keep your application momentum moving" 
    }

    private var nextMoveDetail: String {
        if store.profile.resumeText.isEmpty && store.profile.careerInterests.isEmpty { return "Add your resume or career interests so recommendations fit you." }
        if store.report.opportunities.isEmpty { return "Let the research team find official program pages and application links." }
        if store.applications.isEmpty { return "Tracking dates, requirements, and outreach keeps the search organized." }
        return "Use the tracker and networking CRM to decide what deserves attention today." }

    private var nextButtonTitle: String {
        if store.profile.resumeText.isEmpty && store.profile.careerInterests.isEmpty { return "Open profile" }
        if store.report.opportunities.isEmpty { return "Start research" }
        return "Open tracker" }

    private var nextSection: WorkspaceSection {
        if store.profile.resumeText.isEmpty && store.profile.careerInterests.isEmpty { return .profile }
        if store.report.opportunities.isEmpty { return .profile }
        return .tracker
    }
}

private struct Metric: View {
    let value: Int
    let label: String
    var body: some View { VStack(alignment: .leading, spacing: 2) { Text("\(value)").font(.title2.weight(.semibold)); Text(label).foregroundStyle(.secondary) } }
}

private struct ActionRow: View {
    let icon: String
    let title: String
    let detail: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Image(systemName: icon).frame(width: 20); VStack(alignment: .leading) { Text(title); Text(detail).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
        }
        .buttonStyle(.plain)
    }
}
