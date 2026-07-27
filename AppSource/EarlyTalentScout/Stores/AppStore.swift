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
    var networkingLeads: [NetworkingLead]
    var watchCompanies: [WatchCompany]
    var dismissedOpportunityIDs: Set<String>
    var tailoredResume: TailoredResume?
    var resumeTailorContext = ""
    var skillsPlanTarget = ""
    var companyResearchTarget = ""
    var networkLeadOrganization = ""
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
    var autoRefreshOnLaunch = false
    var profileRefreshQueued = false
    private var profileRevision = 0

    let agentNames = ["Resume Analyst", "Career Strategist", "Program Researcher", "Ecosystem Scout", "Link Verifier", "Opportunity Ranker"]

    init() {
        let workspace = TrackerPersistence.load()
        profile = workspace.profile
        applications = workspace.applications
        relationships = workspace.relationships
        networkingLeads = workspace.networkingLeads
        watchCompanies = workspace.watchCompanies
        dismissedOpportunityIDs = Set(workspace.dismissedOpportunityIDs)
        report = workspace.report ?? ResearchReport.empty
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
        autoRefreshOnLaunch = false
    }

    func refreshForNewLaunchIfPossible() async {
        // Research is intentionally manual so each API-backed run is a user choice.
    }

    func profileDidChange() {
        persistApplications()
        profileRevision += 1
        profileRefreshQueued = false
    }

    func runResearch(openResearchWhenFinished: Bool = true) async {
        guard canResearch else { return }
        let researchRevision = profileRevision
        persistApplications()
        run = ResearchRun(agents: agentNames.map { AgentProgress(name: $0, status: .waiting) })
        errorMessage = nil
        defer {
            run = nil
            if profileRevision != researchRevision { profileRefreshQueued = false }
        }
        let orchestrator = AgentOrchestrator(apiKey: apiKey)
        do {
            report = try await orchestrator.run(profile: profile) { [weak self] name, status in
                await MainActor.run { self?.updateAgent(name: name, status: status) }
            }
            updateWatchList(with: report)
            updateNetworkingLeads(with: report.networkingLeads)
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

    func addManualContact(name: String, company: String, sharedContext: String, profileURLText: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedCompany.isEmpty else { return }
        let contact = NetworkContact(name: trimmedName, headline: "", company: trimmedCompany, sharedContext: sharedContext.isEmpty ? "Found through LinkedIn" : sharedContext, profileURL: URL(string: profileURLText.trimmingCharacters(in: .whitespacesAndNewlines)), reachOutReason: "A real contact the user identified for this organization.")
        if !networkContacts.contains(contact) { networkContacts.append(contact) }
        if !relationships.contains(where: { $0.name == trimmedName && $0.company == trimmedCompany }) {
            relationships.append(RelationshipRecord(name: trimmedName, company: trimmedCompany, sharedContext: contact.sharedContext))
        }
        if let index = networkingLeads.firstIndex(where: { $0.organization.caseInsensitiveCompare(trimmedCompany) == .orderedSame }) {
            networkingLeads[index].status = "Contact saved"
        }
        persistApplications()
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

    func startCompanyResearch(for lead: NetworkingLead) {
        companyResearchTarget = lead.organization
        selection = .companies
    }

    func startNetworking(for lead: NetworkingLead) {
        networkLeadOrganization = lead.organization
        if let index = networkingLeads.firstIndex(where: { $0.id == lead.id }) {
            networkingLeads[index].status = "Finding contact"
            persistApplications()
        }
        selection = .network
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
        func factValue(matching terms: [String]) -> String? {
            opportunity.verifiedFacts.first { fact in
                let label = fact.label.lowercased()
                return terms.contains { label.contains($0) }
            }?.value
        }
        let posting = opportunity.postingDate ?? factValue(matching: ["posting", "posted", "opens", "opening"])
        let deadline = opportunity.deadline ?? factValue(matching: ["deadline", "close", "due date"])
        let requirementFacts = opportunity.verifiedFacts
            .filter { fact in
                let label = fact.label.lowercased()
                return label.contains("require") || label.contains("eligib") || label.contains("qualification")
            }
            .map(\.value)
        let requirements = Array(Set(([opportunity.eligibility] + requirementFacts).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })).joined(separator: " · ")
        applications.append(ApplicationRecord(company: opportunity.company, program: opportunity.program, postingDate: posting ?? "", deadline: deadline ?? "", requirements: requirements, applicationURL: opportunity.applicationURL ?? opportunity.officialProgramURL, description: opportunity.sourceNotes, whyThisMatches: opportunity.fitReason, lastChecked: .now, suggestedContactIDs: contacts, preparationChecklist: opportunity.preparationChecklist, resumeFocus: opportunity.resumeFocus, skillFocus: opportunity.skillFocus, officialSourceType: opportunity.officialSourceType, verifiedFacts: opportunity.verifiedFacts))
        persistApplications()
    }

    func applySavedResearchDetails(to applicationID: UUID) {
        guard let index = applications.firstIndex(where: { $0.id == applicationID }),
              let opportunity = report.opportunities.first(where: { $0.company == applications[index].company && $0.program == applications[index].program }) else { return }
        func factValue(matching terms: [String]) -> String? {
            opportunity.verifiedFacts.first { fact in
                let label = fact.label.lowercased()
                return terms.contains { label.contains($0) }
            }?.value
        }
        if applications[index].postingDate.isEmpty { applications[index].postingDate = opportunity.postingDate ?? factValue(matching: ["posting", "posted", "opens", "opening"]) ?? "" }
        if applications[index].deadline.isEmpty { applications[index].deadline = opportunity.deadline ?? factValue(matching: ["deadline", "close", "due date"]) ?? "" }
        if applications[index].requirements.isEmpty {
            let details = Array(Set(([opportunity.eligibility] + opportunity.verifiedFacts.filter { $0.label.lowercased().contains("require") || $0.label.lowercased().contains("eligib") || $0.label.lowercased().contains("qualification") }.map(\.value)).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
            applications[index].requirements = details.joined(separator: " · ")
        }
        applications[index].verifiedFacts = opportunity.verifiedFacts
        applications[index].officialSourceType = opportunity.officialSourceType
        applications[index].applicationURL = opportunity.applicationURL ?? opportunity.officialProgramURL
        persistApplications()
    }

    func startResumeTailor(for application: ApplicationRecord) {
        resumeTailorContext = "Target program: \(application.program) at \(application.company)\n\nKnown or expected application details:\n\(application.requirements)\n\nResume focus:\n\(application.resumeFocus.joined(separator: "\n• "))\n\nPreparation guidance:\n\(application.preparationChecklist.joined(separator: "\n• "))"
        selection = .tailor
    }

    func startSkillsPlan(for application: ApplicationRecord) {
        skillsPlanTarget = "\(application.program) at \(application.company). Focus skills: \(application.skillFocus.joined(separator: ", "))"
        selection = .skills
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

    func addManualOpportunity(company: String, program: String, description: String, officialURLText: String) {
        let company = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let program = program.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !company.isEmpty, !program.isEmpty, let url = URL(string: officialURLText.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme != nil else { return }
        let item = Opportunity(company: company, program: program, careerArea: "Manually added", fitReason: "Added by you.", eligibility: "Confirm eligibility on the official page.", location: "See official page", status: "unknown", postingDate: nil, deadline: nil, applicationURL: nil, officialProgramURL: url, linkedInURL: nil, sourceNotes: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Manually added opportunity. Confirm details on the official page." : description, expectedApplicationTiming: "Check the official page for timing.", preparationChecklist: [], resumeFocus: [], skillFocus: [], officialSourceType: "Official link added by you", verifiedFacts: [])
        guard !report.opportunities.contains(where: { $0.id == item.id }) else { return }
        report.opportunities.insert(item, at: 0)
        dismissedOpportunityIDs.remove(item.id)
        persistApplications()
    }

    func addManualWatchCompany(company: String, reason: String, program: String, officialURLText: String) {
        let company = company.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !company.isEmpty else { return }
        let url = URL(string: officialURLText.trimmingCharacters(in: .whitespacesAndNewlines))
        var leads: [Opportunity] = []
        let program = program.trimmingCharacters(in: .whitespacesAndNewlines)
        if !program.isEmpty, let url, url.scheme != nil {
            leads = [Opportunity(company: company, program: program, careerArea: "Manually added", fitReason: "Added by you.", eligibility: "Confirm on the official page.", location: "See official page", status: "unknown", postingDate: nil, deadline: nil, applicationURL: nil, officialProgramURL: url, linkedInURL: nil, sourceNotes: "Program lead added by you.", expectedApplicationTiming: "Check the official page.", preparationChecklist: [], resumeFocus: [], skillFocus: [], officialSourceType: "Official link added by you", verifiedFacts: [])]
        }
        if let index = watchCompanies.firstIndex(where: { $0.company.caseInsensitiveCompare(company) == .orderedSame }) {
            let existing = watchCompanies[index].programLeads ?? []
            watchCompanies[index].programLeads = existing + leads.filter { candidate in !existing.contains(where: { $0.id == candidate.id }) }
            if !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { watchCompanies[index].reason = reason }
            if watchCompanies[index].officialCareersURL == nil { watchCompanies[index].officialCareersURL = url }
        } else {
            watchCompanies.append(WatchCompany(company: company, reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Manually added to Watch List." : reason, officialCareersURL: url, programLeads: leads))
        }
        persistApplications()
    }

    func removeFromWatchList(_ watch: WatchCompany) {
        watchCompanies.removeAll { $0.id == watch.id }
        persistApplications()
    }

    func addManualNetworkingLead(organization: String, category: String, reason: String, officialURLText: String) {
        let organization = organization.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !organization.isEmpty else { return }
        let url = URL(string: officialURLText.trimmingCharacters(in: .whitespacesAndNewlines))
        let lead = NetworkingLead(organization: organization, category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Networking lead" : category, whyNetwork: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Manually added networking lead." : reason, outreachAngle: "Ask for a short conversation about the organization and early-career paths.", officialURL: url)
        guard !networkingLeads.contains(where: { $0.id == lead.id }) else { return }
        networkingLeads.insert(lead, at: 0)
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
        func leads(for company: String) -> [Opportunity] {
            newReport.opportunities.filter { $0.company.caseInsensitiveCompare(company) == .orderedSame }
        }
        for watch in newReport.watchCompanies where !liveCompanies.contains(watch.company.lowercased()) {
            if let index = watchCompanies.firstIndex(where: { $0.company.caseInsensitiveCompare(watch.company) == .orderedSame }) {
                watchCompanies[index] = watch
            } else {
                watchCompanies.append(watch)
            }
        }
        let targets = profile.targetCompanies.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for company in targets {
            let companyLeads = leads(for: company)
            if let index = watchCompanies.firstIndex(where: { $0.company.caseInsensitiveCompare(company) == .orderedSame }) {
                watchCompanies[index].programLeads = companyLeads
                if !companyLeads.isEmpty {
                    watchCompanies[index].reason = "Internd found \(companyLeads.count) program lead\(companyLeads.count == 1 ? "" : "s") for this company. Open the card to review each one."
                }
            } else {
                watchCompanies.append(WatchCompany(
                    company: company,
                    reason: companyLeads.isEmpty ? "No credible sophomore-accessible early-talent pathway was identified during this check." : "Internd found \(companyLeads.count) program lead\(companyLeads.count == 1 ? "" : "s") for this company. Open the card to review each one.",
                    officialCareersURL: companyLeads.first?.officialProgramURL,
                    programLeads: companyLeads
                ))
            }
        }
        persistApplications()
    }

    private func updateNetworkingLeads(with incoming: [NetworkingLead]) {
        for lead in incoming {
            if let index = networkingLeads.firstIndex(where: { $0.id == lead.id }) {
                let savedStatus = networkingLeads[index].status
                networkingLeads[index] = lead
                networkingLeads[index].status = savedStatus
            } else {
                networkingLeads.append(lead)
            }
        }
        persistApplications()
    }

    func persistApplications() { TrackerPersistence.save(profile: profile, applications: applications, relationships: relationships, networkingLeads: networkingLeads, watchCompanies: watchCompanies, dismissedOpportunityIDs: dismissedOpportunityIDs, report: report) }

    func deleteLocalData() {
        applications = []
        relationships = []
        networkingLeads = []
        networkContacts = []
        outreachDrafts = []
        watchCompanies = []
        dismissedOpportunityIDs = []
        TrackerPersistence.deleteAll()
    }
}
