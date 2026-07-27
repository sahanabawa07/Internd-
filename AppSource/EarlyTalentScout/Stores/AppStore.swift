import Foundation
import Observation

@MainActor @Observable
final class AppStore {
    var profile = StudentProfile()
    var selection: WorkspaceSection? = .today
    var report = ResearchReport.empty
    var networkContacts: [NetworkContact] = []
    var applications: [ApplicationRecord]
    var relationships: [RelationshipRecord]
    var watchCompanies: [WatchCompany]
    var dismissedOpportunityIDs: Set<String>
    var tailoredResume: TailoredResume?
    var outreachDrafts: [OutreachDraft] = []
    var outreachTemplate = "Hi {first_name}, I noticed we share {shared_context}. I’m exploring {career_interest} and would appreciate 15 minutes to hear about your experience at {company}. Thank you!"
    var skillsPlan: SkillsPlan?
    var companyBrief: CompanyBrief?
    var qualityCheck: ApplicationQualityCheck?
    var interviewPrep: InterviewPrep?
    var run: ResearchRun?
    var errorMessage: String?
    var apiKey = APIKeyStore.read() ?? ""
    var hasRefreshedThisLaunch = false
    var autoRefreshOnLaunch = UserDefaults.standard.object(forKey: "internd.autoRefreshOnLaunch") as? Bool ?? true

    let agentNames = ["Resume Analyst", "Career Strategist", "Program Researcher", "Link Verifier", "Opportunity Ranker"]

    init() {
        let workspace = TrackerPersistence.load()
        profile = workspace.profile
        applications = workspace.applications
        relationships = workspace.relationships
        watchCompanies = workspace.watchCompanies
        dismissedOpportunityIDs = Set(workspace.dismissedOpportunityIDs)
    }

    var canResearch: Bool { profile.isReady && !apiKey.isEmpty && run == nil }

    var researchReadinessMessage: String? {
        if !profile.isReady { return "Add Career interests, Target companies, or a resume to begin." }
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Add and save an OpenAI API key in Internd → Settings to begin." }
        if run != nil { return "Your research team is working now." }
        return nil
    }

    func saveAPIKey() throws { try APIKeyStore.save(apiKey) }

    func setAutoRefreshOnLaunch(_ enabled: Bool) {
        autoRefreshOnLaunch = enabled
        UserDefaults.standard.set(enabled, forKey: "internd.autoRefreshOnLaunch")
    }

    func refreshForNewLaunchIfPossible() async {
        guard autoRefreshOnLaunch, !hasRefreshedThisLaunch, canResearch else { return }
        hasRefreshedThisLaunch = true
        await runResearch(openResearchWhenFinished: false)
    }

    func runResearch(openResearchWhenFinished: Bool = true) async {
        guard canResearch else { return }
        persistApplications()
        run = ResearchRun(agents: agentNames.map { AgentProgress(name: $0, status: .waiting) })
        errorMessage = nil
        defer { run = nil }
        let orchestrator = AgentOrchestrator(apiKey: apiKey)
        do {
            report = try await orchestrator.run(profile: profile) { [weak self] name, status in
                await MainActor.run { self?.updateAgent(name: name, status: status) }
            }
            updateWatchList(with: report)
            if openResearchWhenFinished { selection = .research }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateAgent(name: String, status: AgentProgress.Status) {
        guard var active = run, let index = active.agents.firstIndex(where: { $0.name == name }) else { return }
        active.agents[index].status = status
        run = active
    }

    func findConnections(csv: String) async {
        guard !apiKey.isEmpty else { errorMessage = "Add an API key in Settings first."; return }
        do {
            networkContacts = try await AgentOrchestrator(apiKey: apiKey).findConnections(profile: profile, connectionRows: CSVSupport.parseConnections(csv))
            selection = .network
        } catch { errorMessage = error.localizedDescription }
    }

    func tailorResume(for description: String) async {
        guard profile.isReady, !apiKey.isEmpty else { errorMessage = "Add a resume or interests, then save an API key in Settings."; return }
        do { tailoredResume = try await AgentOrchestrator(apiKey: apiKey).tailorResume(profile: profile, jobDescription: description) }
        catch { errorMessage = error.localizedDescription }
    }

    func createSkillsPlan(targetRole: String) async {
        guard profile.isReady, !apiKey.isEmpty else { errorMessage = "Add a resume or interests, then save an API key in Settings."; return }
        do { skillsPlan = try await AgentOrchestrator(apiKey: apiKey).buildSkillsPlan(profile: profile, targetRole: targetRole) }
        catch { errorMessage = error.localizedDescription }
    }

    func researchCompany(_ company: String) async {
        guard !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !apiKey.isEmpty else { errorMessage = "Enter a company and save an API key in Settings."; return }
        do { companyBrief = try await AgentOrchestrator(apiKey: apiKey).researchCompany(company, interests: profile.careerInterests) }
        catch { errorMessage = error.localizedDescription }
    }

    func runQualityCheck(application: ApplicationRecord, materials: String) async {
        guard !apiKey.isEmpty else { errorMessage = "Add an API key in Settings first."; return }
        do { qualityCheck = try await AgentOrchestrator(apiKey: apiKey).checkApplication(profile: profile, application: application, extraMaterials: materials) }
        catch { errorMessage = error.localizedDescription }
    }

    func prepareInterview(role: String, company: String) async {
        guard !apiKey.isEmpty else { errorMessage = "Add an API key in Settings first."; return }
        do { interviewPrep = try await AgentOrchestrator(apiKey: apiKey).prepareInterview(profile: profile, role: role, company: company) }
        catch { errorMessage = error.localizedDescription }
    }

    func createOutreach(for contact: NetworkContact, opportunity: ApplicationRecord?) async {
        guard !apiKey.isEmpty else { errorMessage = "Add an API key in Settings first."; return }
        do {
            var draft = try await AgentOrchestrator(apiKey: apiKey).draftOutreach(profile: profile, contact: contact, opportunity: opportunity, template: outreachTemplate)
            draft.opportunityID = opportunity?.id
            draft.profileURL = contact.profileURL
            draft.contactCompany = contact.company
            outreachDrafts.insert(draft, at: 0)
            if !relationships.contains(where: { $0.name == contact.name && $0.company == contact.company }) {
                relationships.append(RelationshipRecord(name: contact.name, company: contact.company, sharedContext: contact.sharedContext))
                persistApplications()
            }
            selection = .outreach
        }
        catch { errorMessage = error.localizedDescription }
    }

    func markOutreachSent(_ draft: OutreachDraft) {
        let today = Date.now
        let followUp = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let dateText = formatter.string(from: today)
        let followUpText = formatter.string(from: followUp)

        if let relationshipIndex = relationships.firstIndex(where: { $0.name == draft.recipientName && $0.company == draft.contactCompany }) {
            relationships[relationshipIndex].lastContact = dateText
            relationships[relationshipIndex].followUpDate = followUpText
            relationships[relationshipIndex].relationshipStrength = "Message sent"
        } else {
            relationships.append(RelationshipRecord(name: draft.recipientName, company: draft.contactCompany, sharedContext: "Outreach draft sent", lastContact: dateText, followUpDate: followUpText, relationshipStrength: "Message sent"))
        }

        if let applicationID = draft.opportunityID, let index = applications.firstIndex(where: { $0.id == applicationID }) {
            applications[index].outreachPrepared = true
            applications[index].outreachStatus = "Message sent to \(draft.recipientName) · follow up \(followUpText)"
            updateStage(for: index)
        }
        persistApplications()
    }

    func track(_ opportunity: Opportunity) {
        guard !applications.contains(where: { $0.company == opportunity.company && $0.program == opportunity.program }) else { return }
        let contacts = suggestedContacts(for: opportunity.company).map(\.id)
        applications.append(ApplicationRecord(company: opportunity.company, program: opportunity.program, postingDate: opportunity.postingDate ?? "", deadline: opportunity.deadline ?? "", requirements: opportunity.eligibility, applicationURL: opportunity.applicationURL ?? opportunity.officialProgramURL, description: opportunity.sourceNotes, whyThisMatches: opportunity.fitReason, lastChecked: .now, suggestedContactIDs: contacts))
        persistApplications()
    }

    func dismiss(_ opportunity: Opportunity) {
        dismissedOpportunityIDs.insert(opportunity.id)
        persistApplications()
    }

    func restoreDismissedResearch() {
        dismissedOpportunityIDs.removeAll()
        persistApplications()
    }

    func addToWatchList(_ suggestion: CompanySuggestion) {
        guard !watchCompanies.contains(where: { $0.company.caseInsensitiveCompare(suggestion.company) == .orderedSame }) else { return }
        watchCompanies.append(WatchCompany(company: suggestion.company, reason: "Added from More companies worth exploring. \(suggestion.earlyTalentPathway)", officialCareersURL: suggestion.officialCareersURL))
        persistApplications()
    }

    func suggestedContacts(for company: String) -> [NetworkContact] {
        let exact = networkContacts.filter { $0.company.localizedCaseInsensitiveCompare(company) == .orderedSame }
        let related = networkContacts.filter { contact in
            let context = "\(contact.company) \(contact.headline) \(contact.sharedContext)".lowercased()
            return !exact.contains(contact) && (context.contains(company.lowercased()) || profile.targetCompanies.lowercased().contains(contact.company.lowercased()))
        }
        return Array((exact + related).prefix(3))
    }

    func setManualProgress(for id: UUID, keyPath: WritableKeyPath<ApplicationRecord, Bool>, to value: Bool) {
        guard let index = applications.firstIndex(where: { $0.id == id }) else { return }
        applications[index][keyPath: keyPath] = value
        updateStage(for: index)
        persistApplications()
    }

    func updateStage(for index: Int) {
        guard applications.indices.contains(index) else { return }
        let app = applications[index]
        if app.status == "Submitted" || app.status == "Interviewing" || app.status == "Closed" { return }
        let completed = app.preparationProgress
        applications[index].status = completed == 0 ? "Saved" : completed == 1 ? "Researching" : completed == 2 ? "Resume tailored" : completed == 3 ? "Materials checked" : "Ready to submit"
    }

    private func updateWatchList(with newReport: ResearchReport) {
        let liveCompanies = Set(newReport.opportunities.map { $0.company.lowercased() })
        watchCompanies.removeAll { liveCompanies.contains($0.company.lowercased()) }
        for watch in newReport.watchCompanies where !liveCompanies.contains(watch.company.lowercased()) {
            if let index = watchCompanies.firstIndex(where: { $0.company.caseInsensitiveCompare(watch.company) == .orderedSame }) {
                watchCompanies[index] = watch
            } else {
                watchCompanies.append(watch)
            }
        }
        let targets = profile.targetCompanies.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for company in targets where !liveCompanies.contains(company.lowercased()) && !watchCompanies.contains(where: { $0.company.caseInsensitiveCompare(company) == .orderedSame }) {
            watchCompanies.append(WatchCompany(company: company, reason: "No credible sophomore-accessible early-talent pathway was identified during this check.", officialCareersURL: nil))
        }
        persistApplications()
    }

    func persistApplications() { TrackerPersistence.save(profile: profile, applications: applications, relationships: relationships, watchCompanies: watchCompanies, dismissedOpportunityIDs: dismissedOpportunityIDs) }

    func deleteLocalData() {
        applications = []
        relationships = []
        networkContacts = []
        outreachDrafts = []
        watchCompanies = []
        dismissedOpportunityIDs = []
        TrackerPersistence.deleteAll()
    }
}
