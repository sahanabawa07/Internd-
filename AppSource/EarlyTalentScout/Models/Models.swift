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

struct StudentProfile: Codable {
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

    var id: String { "\(company)-\(program)" }
    var statusLabel: String {
        switch status {
        case "open": "Open"
        case "recurring_watch": "Watch"
        default: "Verify"
        }
    }
}

struct ResearchReport: Codable {
    let careerSuggestions: [CareerDirection]
    let opportunities: [Opportunity]
    let researchNotes: [String]

    static let empty = ResearchReport(careerSuggestions: [], opportunities: [], researchNotes: [])
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
    var status: String = "Interested"
    var postingDate: String = ""
    var deadline: String = ""
    var requirements: String = ""
    var applicationURL: URL?
    var outreachStatus: String = "Not started"
    var notes: String = ""
}

struct TailoredResume: Codable {
    let roleSummary: String
    let priorityKeywords: [String]
    let suggestedChanges: [String]
    let tailoredBulletExamples: [String]
    let cautions: [String]
}

struct OutreachDraft: Codable, Identifiable {
    let recipientName: String
    let subject: String
    let message: String
    let rationale: String
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
