//
//  OpenAIClient.swift
//  Memo
//

import Foundation

/// OpenAI's Responses API.
struct OpenAIClient: AIClient {

    private static let baseURL = URL(string: "https://api.openai.com/v1")!

    func models(apiKey: String) async throws -> [String] {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("models"))
        Self.authorize(&request, apiKey: apiKey)

        let data = try await AIHTTP.data(for: request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let models = object?["data"] as? [[String: Any]] ?? []

        return Self.chatModels(in: models.compactMap { $0["id"] as? String })
    }

    /// The account's list also holds speech, image and embedding models, none
    /// of which can read a file and answer in text.
    static func chatModels(in ids: [String]) -> [String] {
        let unsuitable = [
            "audio", "realtime", "image", "tts", "transcribe", "search",
            "embedding", "moderation", "instruct",
        ]

        return ids
            .filter { id in
                id.hasPrefix("gpt-") && !unsuitable.contains(where: id.contains)
            }
            .sorted(by: >)
    }

    func generateDeckJSON(_ request: AIDeckRequest) async throws -> String {
        var answer = Answer()
        try await AIHTTP.forEachEvent(of: try Self.makeRequest(request)) { event in
            try answer.consume(event)
        }
        return try answer.text()
    }

    // MARK: - Request

    static func makeRequest(_ request: AIDeckRequest) throws -> URLRequest {
        let body: [String: Any] = [
            "model": request.model,
            "stream": true,
            "instructions": request.systemPrompt,
            "input": [
                [
                    "role": "user",
                    "content": [
                        documentPart(request.document),
                        ["type": "input_text", "text": request.userPrompt],
                    ],
                ]
            ],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "deck_file",
                    "strict": true,
                    "schema": AIDeckPrompt.schema,
                ]
            ],
        ]

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("responses"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = AIHTTP.timeout
        authorize(&urlRequest, apiKey: request.apiKey)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        return urlRequest
    }

    private static func authorize(_ request: inout URLRequest, apiKey: String) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }

    private static func documentPart(_ document: AIDocument) -> [String: Any] {
        switch document {
        case .text(let name, let content):
            return [
                "type": "input_text",
                "text": AIDeckPrompt.textDocument(name: name, content: content),
            ]
        case .pdf(let name, let data):
            return [
                "type": "input_file",
                "filename": name,
                "file_data": "data:application/pdf;base64,\(data.base64EncodedString())",
            ]
        }
    }

    // MARK: - Response

    /// Assembles the answer from the stream's events.
    struct Answer {

        private var collected = ""
        private var wasRefused = false
        private var wasCutOff = false

        mutating func consume(_ event: Data) throws {
            guard let object = (try? JSONSerialization.jsonObject(with: event)) as? [String: Any],
                  let type = object["type"] as? String
            else { return }

            switch type {
            case "response.output_text.delta":
                collected += object["delta"] as? String ?? ""

            case "response.refusal.delta", "response.refusal.done":
                wasRefused = true

            case "response.incomplete":
                wasCutOff = true

            case "response.failed":
                let response = object["response"] as? [String: Any] ?? [:]
                throw AIFailure.service(AIHTTP.errorMessage(in: response) ?? "")

            case "error":
                throw AIFailure.service(AIHTTP.errorMessage(in: object) ?? "")

            default:
                break
            }
        }

        func text() throws -> String {
            if wasRefused { throw AIFailure.refused }
            if wasCutOff { throw AIFailure.truncated }

            guard !collected.isEmpty else { throw AIFailure.emptyResponse }
            return collected
        }
    }
}
