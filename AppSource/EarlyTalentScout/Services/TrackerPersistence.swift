import Foundation

enum TrackerPersistence {
    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EarlyTalentScout", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("applications.json")
    }

    struct Workspace: Codable {
        var profile: StudentProfile
        var applications: [ApplicationRecord]
        var relationships: [RelationshipRecord]
        var networkingLeads: [NetworkingLead]
        var watchCompanies: [WatchCompany]
        var dismissedOpportunityIDs: [String]

        init(profile: StudentProfile = StudentProfile(), applications: [ApplicationRecord] = [], relationships: [RelationshipRecord] = [], networkingLeads: [NetworkingLead] = [], watchCompanies: [WatchCompany] = [], dismissedOpportunityIDs: [String] = []) {
            self.profile = profile
            self.applications = applications
            self.relationships = relationships
            self.networkingLeads = networkingLeads
            self.watchCompanies = watchCompanies
            self.dismissedOpportunityIDs = dismissedOpportunityIDs
        }

        enum CodingKeys: String, CodingKey { case profile, applications, relationships, networkingLeads, watchCompanies, dismissedOpportunityIDs }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            profile = try c.decodeIfPresent(StudentProfile.self, forKey: .profile) ?? StudentProfile()
            applications = try c.decodeIfPresent([ApplicationRecord].self, forKey: .applications) ?? []
            relationships = try c.decodeIfPresent([RelationshipRecord].self, forKey: .relationships) ?? []
            networkingLeads = try c.decodeIfPresent([NetworkingLead].self, forKey: .networkingLeads) ?? []
            watchCompanies = try c.decodeIfPresent([WatchCompany].self, forKey: .watchCompanies) ?? []
            dismissedOpportunityIDs = try c.decodeIfPresent([String].self, forKey: .dismissedOpportunityIDs) ?? []
        }
    }

    static func load() -> Workspace {
        guard let data = try? Data(contentsOf: fileURL) else { return Workspace() }
        return (try? JSONDecoder().decode(Workspace.self, from: data)) ?? Workspace()
    }

    static func save(profile: StudentProfile, applications: [ApplicationRecord], relationships: [RelationshipRecord], networkingLeads: [NetworkingLead], watchCompanies: [WatchCompany], dismissedOpportunityIDs: Set<String>) {
        guard let data = try? JSONEncoder().encode(Workspace(profile: profile, applications: applications, relationships: relationships, networkingLeads: networkingLeads, watchCompanies: watchCompanies, dismissedOpportunityIDs: Array(dismissedOpportunityIDs))) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func deleteAll() { try? FileManager.default.removeItem(at: fileURL) }
}
