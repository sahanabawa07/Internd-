import Foundation

struct ResponsesClient {
    private let apiKey: String
    private let model = "gpt-5.6-terra"

    init(apiKey: String) { self.apiKey = apiKey }

    func run(prompt: String, useWebSearch: Bool) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["model": model, "input": prompt]
        if useWebSearch { body["tools"] = [["type": "web_search"]] }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw ClientError.server(message)
        }
        let decoded = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        let text = decoded.output.compactMap { output in
            output.content?.compactMap { $0.text }.joined()
        }.joined(separator: "\n")
        guard !text.isEmpty else { throw ClientError.noTextOutput }
        return text
    }

    private struct ResponseEnvelope: Decodable {
        struct Output: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String?
            }
            let content: [Content]?
        }
        let output: [Output]
    }

    enum ClientError: LocalizedError {
        case invalidResponse, noTextOutput, server(String)
        var errorDescription: String? {
            switch self {
            case .invalidResponse: "The service returned an invalid response."
            case .noTextOutput: "The service did not return a response."
            case .server(let message): message
            }
        }
    }
}

