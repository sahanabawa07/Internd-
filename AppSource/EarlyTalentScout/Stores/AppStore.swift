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

    let agentNames = ["Resume Analyst", "Career Strategist", "Program Researcher", "Link Verifier", "Opportunity Ranker"]

    init() {
        let workspace = TrackerPersistence.load()
        applications = workspace.applications
        relationships = workspace.relationships
    }

    var canResearch: Bool { profile.isReady && !apiKey.isEmpty && run == nil }

    var researchReadinessMessage: String? {
        if !profile.isReady { return "Add Career interests, Target companies, or a resume to begin." }
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Add and save an OpenAI API key in Internd → Settings to begin." }
        if run != nil { return "Your research team is working now." }
        return nil
    }

    func saveAPIKey() throws { try APIKeyStore.save(apiKey) }

    func runResearch() async {
        guard canResearch else { return }
        run = ResearchRun(agents: agentNames.map { AgentProgress(name: $0, status: .waiting) })
        errorMessage = nil
        defer { run = nil }
        let orchestrator = AgentOrchestrator(apiKey: apiKey)
        do {
            report = try await orchestrator.run(profile: profile) { [weak self] name, status in
                await MainActor.run { self?.updateAgent(name: name, status: status) }
            }
            selection = .research
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
            outreachDrafts.insert(try await AgentOrchestrator(apiKey: apiKey).draftOutreach(profile: profile, contact: contact, opportunity: opportunity, template: outreachTemplate), at: 0)
            if !relationships.contains(where: { $0.name == contact.name && $0.company == contact.company }) {
                relationships.append(RelationshipRecord(name: contact.name, company: contact.company, sharedContext: contact.sharedContext))
                persistApplications()
            }
        }
        catch { errorMessage = error.localizedDescription }
    }

    func track(_ opportunity: Opportunity) {
        guard !applications.contains(where: { $0.company == opportunity.company && $0.program == opportunity.program }) else { return }
        applications.append(ApplicationRecord(company: opportunity.company, program: opportunity.program, postingDate: opportunity.postingDate ?? "", deadline: opportunity.deadline ?? "", requirements: opportunity.eligibility, applicationURL: opportunity.applicationURL ?? opportunity.officialProgramURL))
        persistApplications()
    }

    func persistApplications() { TrackerPersistence.save(applications: applications, relationships: relationships) }

    func deleteLocalData() {
        applications = []
        relationships = []
        networkContacts = []
        outreachDrafts = []
        TrackerPersistence.deleteAll()
    }
}
