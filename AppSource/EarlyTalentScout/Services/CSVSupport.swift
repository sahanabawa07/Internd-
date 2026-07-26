import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum CSVSupport {
    static func parseConnections(_ text: String) -> [[String: String]] {
        let rows = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let headerLine = rows.first else { return [] }
        let headers = split(headerLine).map { $0.lowercased() }
        return rows.dropFirst().map { row in
            let values = split(row)
            return Dictionary(uniqueKeysWithValues: zip(headers, values))
        }
    }

    static func applicationSpreadsheet(_ records: [ApplicationRecord]) -> String {
        let header = ["Company", "Program", "Status", "Posting date", "Deadline", "Requirements", "Application link", "Outreach", "Notes"]
        let data = records.map { record in
            [record.company, record.program, record.status, record.postingDate, record.deadline, record.requirements, record.applicationURL?.absoluteString ?? "", record.outreachStatus, record.notes]
                .map(escape).joined(separator: ",")
        }
        return ([header.map(escape).joined(separator: ",")] + data).joined(separator: "\n")
    }

    private static func split(_ line: String) -> [String] {
        var values: [String] = [], current = "", insideQuotes = false
        for character in line {
            if character == "\"" { insideQuotes.toggle() }
            else if character == "," && !insideQuotes { values.append(current.trimmingCharacters(in: .whitespaces)); current = "" }
            else { current.append(character) }
        }
        values.append(current.trimmingCharacters(in: .whitespaces))
        return values.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"") ) }
    }

    private static func escape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

struct ApplicationCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var csv: String
    init(csv: String) { self.csv = csv }
    init(configuration: ReadConfiguration) throws { csv = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(csv.utf8)) }
}
