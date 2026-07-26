import Foundation

enum TrackerPersistence {
    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EarlyTalentScout", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("applications.json")
    }

    struct Workspace: Codable {
        var applications: [ApplicationRecord]
        var relationships: [RelationshipRecord]
    }

    static func load() -> Workspace {
        guard let data = try? Data(contentsOf: fileURL) else { return Workspace(applications: [], relationships: []) }
        return (try? JSONDecoder().decode(Workspace.self, from: data)) ?? Workspace(applications: [], relationships: [])
    }

    static func save(applications: [ApplicationRecord], relationships: [RelationshipRecord]) {
        guard let data = try? JSONEncoder().encode(Workspace(applications: applications, relationships: relationships)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func deleteAll() { try? FileManager.default.removeItem(at: fileURL) }
}
