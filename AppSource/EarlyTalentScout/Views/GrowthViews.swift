import SwiftUI

struct SkillsPlanView: View {
    let store: AppStore
    @State private var targetRole = ""

    var body: some View {
        List {
            Section("Build a skills plan") {
                TextField("Target role", text: $targetRole, prompt: Text("Data analyst internship"))
                Button("Create four-week plan") { Task { await store.createSkillsPlan(targetRole: targetRole) } }
                    .disabled(targetRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let plan = store.skillsPlan {
                Section("Current strengths") { ForEach(plan.strengths, id: \.self) { Text("• \($0)") } }
                Section("Skills to develop") { ForEach(plan.gaps, id: \.self) { Text("• \($0)") } }
                Section("Four-week plan") { ForEach(plan.fourWeekPlan, id: \.self) { Text($0) } }
                Section("Portfolio idea") { Text(plan.portfolioIdea) }
            }
        }
    }
}

struct CompanyResearchView: View {
    let store: AppStore
    @State private var company = ""

    var body: some View {
        List {
            Section("Company intelligence") {
                TextField("Company", text: $company, prompt: Text("Adobe"))
                Button("Research company") { Task { await store.researchCompany(company) } }.disabled(company.isEmpty)
            }
            if let brief = store.companyBrief {
                Section("Business overview") { Text(brief.businessSummary) }
                Section("Early talent") { ForEach(brief.earlyTalentNotes, id: \.self) { Text("• \($0)") } }
                Section("Conversation starters") { ForEach(brief.conversationStarters, id: \.self) { Text("• \($0)") } }
                Section("Interview themes") { ForEach(brief.interviewThemes, id: \.self) { Text("• \($0)") } }
                Section { Text(brief.sourceCaveat).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

struct ApplicationQualityView: View {
    let store: AppStore
    @State private var selectedID: UUID?
    @State private var materials = ""

    var selectedApplication: ApplicationRecord? { store.applications.first { $0.id == selectedID } }

    var body: some View {
        List {
            Section("Pre-submit quality check") {
                Picker("Application", selection: $selectedID) {
                    Text("Choose an application").tag(UUID?.none)
                    ForEach(store.applications) { item in Text("\(item.company) — \(item.program)").tag(Optional(item.id)) }
                }
                TextEditor(text: $materials).frame(minHeight: 90).overlay(alignment: .topLeading) { if materials.isEmpty { Text("Paste any additional requirements, cover letter notes, or portfolio links").foregroundStyle(.tertiary).padding(8).allowsHitTesting(false) } }
                Button("Check application") { if let application = selectedApplication { Task { await store.runQualityCheck(application: application, materials: materials) } } }.disabled(selectedApplication == nil)
            }
            if let result = store.qualityCheck {
                Section(result.readyToApply ? "Ready to apply" : "Before you submit") { Text(result.recommendedNextAction) }
                Section("Missing items") { ForEach(result.missingItems, id: \.self) { Text("• \($0)") } }
                Section("Resume checks") { ForEach(result.resumeChecks, id: \.self) { Text("• \($0)") } }
                Section("Application checks") { ForEach(result.applicationChecks, id: \.self) { Text("• \($0)") } }
            }
        }
    }
}

struct InterviewPrepView: View {
    let store: AppStore
    @State private var role = ""
    @State private var company = ""

    var body: some View {
        List {
            Section("Prepare for an interview") {
                TextField("Role", text: $role, prompt: Text("Product management intern"))
                TextField("Company", text: $company, prompt: Text("Target company"))
                Button("Create interview plan") { Task { await store.prepareInterview(role: role, company: company) } }.disabled(role.isEmpty || company.isEmpty)
            }
            if let prep = store.interviewPrep {
                Section("Behavioral questions") { ForEach(prep.behavioralQuestions, id: \.self) { Text("• \($0)") } }
                Section("Role questions") { ForEach(prep.technicalOrRoleQuestions, id: \.self) { Text("• \($0)") } }
                Section("Your story prompts") { ForEach(prep.storyPrompts, id: \.self) { Text("• \($0)") } }
                Section("Preparation plan") { ForEach(prep.preparationPlan, id: \.self) { Text($0) } }
            }
        }
    }
}

struct InsightsPrivacyView: View {
    let store: AppStore
    @State private var confirmDelete = false

    private var submitted: Int { store.applications.filter { $0.status.localizedCaseInsensitiveContains("submitted") }.count }
    private var interviews: Int { store.applications.filter { $0.status.localizedCaseInsensitiveContains("interview") }.count }
    private var overdueFollowUps: Int { store.relationships.filter { !$0.followUpDate.isEmpty }.count }

    var body: some View {
        List {
            Section("Search insights") {
                LabeledContent("Tracked applications", value: "\(store.applications.count)")
                LabeledContent("Submitted", value: "\(submitted)")
                LabeledContent("Interviews", value: "\(interviews)")
                LabeledContent("Planned follow-ups", value: "\(overdueFollowUps)")
                Text("Update application status and outreach records consistently; the metrics improve as you use the tracker.").foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Text("Your tracker and relationship notes are stored locally on this Mac. The app sends only the text needed for an AI task to the configured OpenAI API.").foregroundStyle(.secondary)
                Button("Delete local tracker and relationship data", role: .destructive) { confirmDelete = true }
            }
        }
        .alert("Delete local career data?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { store.deleteLocalData() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes locally saved applications and relationship notes. It cannot be undone.") }
    }
}
