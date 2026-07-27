import SwiftUI

struct DashboardView: View {
    let store: AppStore

    private var priorityApps: [ApplicationRecord] {
        store.applications.sorted { priorityScore($0) > priorityScore($1) }
    }

    private var taskApps: [ApplicationRecord] { Array(priorityApps.prefix(4)) }
    private var plannedFollowUps: [RelationshipRecord] {
        store.relationships.filter { !$0.followUpDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { (daysUntil($0.followUpDate) ?? .max) < (daysUntil($1.followUpDate) ?? .max) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Today").font(.system(size: 38, weight: .semibold))
                        Text("Your plan is ordered by deadlines, strongest matches, and applications with the most work remaining.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.autoRefreshOnLaunch { Label("Auto-refresh on", systemImage: "arrow.clockwise").font(.system(size: 15)).foregroundStyle(.secondary) }
                }

                if store.run != nil {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Refreshing your opportunities and Watch List").font(.system(size: 20, weight: .semibold))
                        Text("This launch refresh uses your OpenAI API credit. You can turn it off in Settings anytime.").font(.system(size: 15)).foregroundStyle(.secondary)
                    }.padding(15).background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 18))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Next actions").font(.system(size: 25, weight: .semibold))
                    ForEach(plannedFollowUps.prefix(2)) { relationship in
                        TodayAction(icon: "paperplane", title: "Follow up with \(relationship.name)", detail: "\(relationship.company) · scheduled \(relationship.followUpDate)", action: { store.selection = .network })
                    }
                    if taskApps.isEmpty {
                        TodayAction(icon: "sparkle.magnifyingglass", title: store.report.opportunities.isEmpty ? "Set up your profile, then let Internd research" : "Choose a program to add to your tracker", detail: store.report.opportunities.isEmpty ? "Add your interests, targets, and API key. Results refresh when you open Internd." : "Your official links are waiting in Research.", action: { store.selection = store.report.opportunities.isEmpty ? .profile : .research })
                    } else {
                        ForEach(taskApps) { app in
                            TodayAction(icon: taskIcon(for: app), title: nextTask(for: app), detail: detail(for: app), action: { store.selection = .tracker })
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Skill building for this week").font(.system(size: 25, weight: .semibold))
                    let skills = Array(store.report.skillSuggestions.prefix(2))
                    if skills.isEmpty {
                        TodayAction(icon: "target", title: fallbackSkillTitle, detail: "Create a plan in Skills Plan after your next research refresh.", action: { store.selection = .skills })
                    } else {
                        ForEach(skills) { skill in
                            TodayAction(icon: "target", title: skill.title, detail: "\(skill.why) Next: \(skill.nextStep)", action: { store.selection = .skills })
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("At a glance").font(.system(size: 25, weight: .semibold))
                    HStack(spacing: 12) {
                        StatCard(value: "\(store.applications.count)", label: "Tracked")
                        StatCard(value: "\(store.watchCompanies.count)", label: "Watching")
                        StatCard(value: "\(store.applications.filter { $0.status == "Submitted" }.count)", label: "Submitted")
                        StatCard(value: "\(store.relationships.count)", label: "Outreach")
                    }
                }
            }.padding(22)
        }
    }

    private func priorityScore(_ app: ApplicationRecord) -> Int {
        let days = daysUntil(app.deadline)
        let deadlineScore = days.map { max(0, 40 - min($0, 40)) } ?? 3
        let effort = max(0, 4 - app.preparationProgress) * 12 + min(app.requirements.count / 12, 10)
        let fit = app.whyThisMatches.isEmpty ? 0 : 8
        return deadlineScore + effort + fit
    }

    private func daysUntil(_ text: String) -> Int? {
        let formats = ["MMM d, yyyy", "MMMM d, yyyy", "M/d/yyyy", "yyyy-MM-dd"]
        for format in formats {
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = format
            if let date = formatter.date(from: text) { return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: date).day }
        }
        return nil
    }

    private func nextTask(for app: ApplicationRecord) -> String {
        if !app.companyResearchDone { return "Research \(app.company)" }
        if !app.resumeTailored { return "Tailor your resume for \(app.company)" }
        if !app.outreachPrepared { return "Plan outreach for \(app.company)" }
        if !app.materialsChecked { return "Complete the application check for \(app.company)" }
        return "Submit \(app.company) application"
    }

    private func detail(for app: ApplicationRecord) -> String {
        var pieces: [String] = []
        if !app.deadline.isEmpty { pieces.append("Deadline: \(app.deadline)") }
        pieces.append("\(4 - app.preparationProgress) core steps left")
        if !app.requirements.isEmpty { pieces.append("Requirements saved") }
        return pieces.joined(separator: " · ")
    }

    private func taskIcon(for app: ApplicationRecord) -> String { app.deadline.isEmpty ? "checklist" : "calendar" }
    private var fallbackSkillTitle: String { profileInterest.lowercased().contains("consult") ? "Practice one consulting case" : "Choose one skill to build from your target roles" }
    private var profileInterest: String { store.profile.careerInterests }
}

private struct TodayAction: View {
    let icon: String; let title: String; let detail: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).font(.system(size: 24)).frame(width: 34, height: 34).background(InterndPalette.pink.opacity(0.45), in: Circle())
                VStack(alignment: .leading, spacing: 3) { Text(title).foregroundStyle(.primary); Text(detail).font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }.padding(13).background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 17))
        }.buttonStyle(.plain)
    }
}

private struct StatCard: View {
    let value: String; let label: String
    var body: some View { VStack(alignment: .leading, spacing: 2) { Text(value).font(.system(size: 28, weight: .semibold)); Text(label).font(.system(size: 15)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 15)) }
}
