import Foundation

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case profile = "My profile"
    case research = "Research"
    case network = "Network"
    case tracker = "Application tracker"
    case tailor = "Resume tailor"
    case outreach = "Outreach drafts"
    case skills = "Skills plan"
    case companies = "Company research"
    case quality = "Application check"
    case interview = "Interview prep"
    case insights = "Insights & privacy"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today: "sun.max"
        case .profile: "person.text.rectangle"
        case .research: "sparkle.magnifyingglass"
        case .network: "person.3"
        case .tracker: "checklist"
        case .tailor: "doc.text"
        case .outreach: "text.bubble"
        case .skills: "target"
        case .companies: "building.2"
        case .quality: "checkmark.seal"
        case .interview: "person.2.wave.2"
        case .insights: "chart.bar"
        }
    }
}

struct StudentProfile: Codable, Equatable {
    var resumeText = ""
    var schoolYear = "First year"
    var graduation = ""
    var locations = ""
    var workAuthorization = ""
    var targetCompanies = ""
    var careerInterests = ""
    var answers: [String: String] = [:]

    var isReady: Bool {
        !resumeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !careerInterests.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !targetCompanies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct CareerDirection: Codable, Identifiable {
    let title: String
    let why: String
    let nextStep: String
    var id: String { title }
}

struct Opportunity: Codable, Identifiable, Hashable {
    let company: String
    let program: String
    let careerArea: String
    let fitReason: String
    let eligibility: String
    let location: String
    let status: String
    let postingDate: String?
    let deadline: String?
    let applicationURL: URL?
    let officialProgramURL: URL
    let linkedInURL: URL?
    let sourceNotes: String
    let expectedApplicationTiming: String
    let preparationChecklist: [String]
    let resumeFocus: [String]
    let skillFocus: [String]

    var id: String { "\(company)-\(program)" }
    var statusLabel: String {
        switch status {
        case "open": "Open"
        case "recurring_watch": "Expected / recurring"
        default: "Verify"
        }
    }
}

struct ResearchReport: Codable {
    let careerSuggestions: [CareerDirection]
    let opportunities: [Opportunity]
    let suggestedCompanies: [CompanySuggestion]
    let networkingLeads: [NetworkingLead]
    let watchCompanies: [WatchCompany]
    let skillSuggestions: [SkillSuggestion]
    let researchNotes: [String]

    static let empty = ResearchReport(careerSuggestions: [], opportunities: [], suggestedCompanies: [], networkingLeads: [], watchCompanies: [], skillSuggestions: [], researchNotes: [])
}

struct CompanySuggestion: Codable, Identifiable, Hashable {
    var id: String { company.lowercased() }
    var company: String
    var category: String
    var whyItFits: String
    var earlyTalentPathway: String
    var officialCareersURL: URL?
}

struct NetworkingLead: Codable, Identifiable, Hashable {
    var id: String { organization.lowercased() }
    var organization: String
    var category: String
    var whyNetwork: String
    var outreachAngle: String
    var officialURL: URL?
    var status: String = "Not started"
    var lastChecked: Date = .now
}

struct WatchCompany: Codable, Identifiable, Hashable {
    var id: String { company.lowercased() }
    var company: String
    var reason: String
    var officialCareersURL: URL?
    var lastChecked: Date = .now
}

struct SkillSuggestion: Codable, Identifiable, Hashable {
    var id: String { title }
    var title: String
    var why: String
    var nextStep: String
}

struct NetworkContact: Codable, Identifiable, Hashable {
    let name: String
    let headline: String
    let company: String
    let sharedContext: String
    let profileURL: URL?
    let reachOutReason: String
    var id: String { "\(name)-\(company)" }
}

struct ApplicationRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var company: String
    var program: String
    var status: String = "Saved"
    var postingDate: String = ""
    var deadline: String = ""
    var requirements: String = ""
    var applicationURL: URL?
    var outreachStatus: String = "Not started"
    var notes: String = ""
    var description: String = ""
    var whyThisMatches: String = ""
    var lastChecked: Date = .now
    var suggestedContactIDs: [String] = []
    var companyResearchDone = false
    var resumeTailored = false
    var outreachPrepared = false
    var materialsChecked = false
    var interviewPrepDone = false
    var preparationChecklist: [String] = []
    var resumeFocus: [String] = []
    var skillFocus: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, company, program, status, postingDate, deadline, requirements, applicationURL, outreachStatus, notes
        case description, whyThisMatches, lastChecked, suggestedContactIDs, companyResearchDone, resumeTailored, outreachPrepared, materialsChecked, interviewPrepDone, preparationChecklist, resumeFocus, skillFocus
    }

    init(id: UUID = UUID(), company: String, program: String, status: String = "Saved", postingDate: String = "", deadline: String = "", requirements: String = "", applicationURL: URL? = nil, outreachStatus: String = "Not started", notes: String = "", description: String = "", whyThisMatches: String = "", lastChecked: Date = .now, suggestedContactIDs: [String] = [], companyResearchDone: Bool = false, resumeTailored: Bool = false, outreachPrepared: Bool = false, materialsChecked: Bool = false, interviewPrepDone: Bool = false, preparationChecklist: [String] = [], resumeFocus: [String] = [], skillFocus: [String] = []) {
        self.id = id; self.company = company; self.program = program; self.status = status; self.postingDate = postingDate; self.deadline = deadline; self.requirements = requirements; self.applicationURL = applicationURL; self.outreachStatus = outreachStatus; self.notes = notes; self.description = description; self.whyThisMatches = whyThisMatches; self.lastChecked = lastChecked; self.suggestedContactIDs = suggestedContactIDs; self.companyResearchDone = companyResearchDone; self.resumeTailored = resumeTailored; self.outreachPrepared = outreachPrepared; self.materialsChecked = materialsChecked; self.interviewPrepDone = interviewPrepDone; self.preparationChecklist = preparationChecklist; self.resumeFocus = resumeFocus; self.skillFocus = skillFocus
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        company = try c.decodeIfPresent(String.self, forKey: .company) ?? ""
        program = try c.decodeIfPresent(String.self, forKey: .program) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "Saved"
        postingDate = try c.decodeIfPresent(String.self, forKey: .postingDate) ?? ""
        deadline = try c.decodeIfPresent(String.self, forKey: .deadline) ?? ""
        requirements = try c.decodeIfPresent(String.self, forKey: .requirements) ?? ""
        applicationURL = try c.decodeIfPresent(URL.self, forKey: .applicationURL)
        outreachStatus = try c.decodeIfPresent(String.self, forKey: .outreachStatus) ?? "Not started"
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        whyThisMatches = try c.decodeIfPresent(String.self, forKey: .whyThisMatches) ?? ""
        lastChecked = try c.decodeIfPresent(Date.self, forKey: .lastChecked) ?? .now
        suggestedContactIDs = try c.decodeIfPresent([String].self, forKey: .suggestedContactIDs) ?? []
        companyResearchDone = try c.decodeIfPresent(Bool.self, forKey: .companyResearchDone) ?? false
        resumeTailored = try c.decodeIfPresent(Bool.self, forKey: .resumeTailored) ?? false
        outreachPrepared = try c.decodeIfPresent(Bool.self, forKey: .outreachPrepared) ?? false
        materialsChecked = try c.decodeIfPresent(Bool.self, forKey: .materialsChecked) ?? false
        interviewPrepDone = try c.decodeIfPresent(Bool.self, forKey: .interviewPrepDone) ?? false
        preparationChecklist = try c.decodeIfPresent([String].self, forKey: .preparationChecklist) ?? []
        resumeFocus = try c.decodeIfPresent([String].self, forKey: .resumeFocus) ?? []
        skillFocus = try c.decodeIfPresent([String].self, forKey: .skillFocus) ?? []
    }

    var preparationProgress: Int { [companyResearchDone, resumeTailored, outreachPrepared, materialsChecked].filter { $0 }.count }
}

struct TailoredResume: Codable {
    let roleSummary: String
    let priorityKeywords: [String]
    let suggestedChanges: [String]
    let tailoredBulletExamples: [String]
    let cautions: [String]
}

struct OutreachDraft: Codable, Identifiable {
    var recipientName: String
    var subject: String
    var message: String
    var rationale: String
    var opportunityID: UUID?
    var profileURL: URL?
    var contactCompany: String = ""
    var id: String { "\(recipientName)-\(subject)" }
}

struct SkillsPlan: Codable {
    let targetRole: String
    let strengths: [String]
    let gaps: [String]
    let fourWeekPlan: [String]
    let portfolioIdea: String
}

struct CompanyBrief: Codable {
    let company: String
    let businessSummary: String
    let earlyTalentNotes: [String]
    let conversationStarters: [String]
    let interviewThemes: [String]
    let sourceCaveat: String
}

struct ApplicationQualityCheck: Codable {
    let readyToApply: Bool
    let missingItems: [String]
    let resumeChecks: [String]
    let applicationChecks: [String]
    let recommendedNextAction: String
}

struct InterviewPrep: Codable {
    let role: String
    let behavioralQuestions: [String]
    let technicalOrRoleQuestions: [String]
    let storyPrompts: [String]
    let preparationPlan: [String]
}

struct RelationshipRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var company: String
    var sharedContext: String
    var lastContact: String = ""
    var followUpDate: String = ""
    var relationshipStrength: String = "New connection"
    var notes: String = ""
}

struct ResearchRun: Identifiable {
    let id = UUID()
    let startedAt = Date()
    var agents: [AgentProgress]
}

struct AgentProgress: Identifiable {
    let id = UUID()
    let name: String
    var status: Status

    enum Status: String {
        case waiting = "Waiting"
        case working = "Working"
        case complete = "Complete"
        case failed = "Needs attention"
    }
}
