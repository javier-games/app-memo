//
//  ClaudeClient.swift
//  Memo
//

import Foundation

/// Anthropic's Messages API.
struct ClaudeClient: AIClient {

    private static let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private static let apiVersion = "2023-06-01"
    private static let fallbackBeta = "server-side-fallback-2026-07-01"

    /// Room for a large deck. A request this size has to be streamed.
    private static let maxTokens = 64_000

    /// Models whose safety checks can decline a request, and which can hand a
    /// declined request to another model instead of failing.
    private static let fallbackModels: Set<String> = [
        "claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5",
    ]

    func models(apiKey: String) async throws -> [String] {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("models"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "limit", value: "100")]

        var request = URLRequest(url: components.url!)
        Self.authorize(&request, apiKey: apiKey)

        let data = try await AIHTTP.data(for: request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let models = object?["data"] as? [[String: Any]] ?? []

        return models.compactMap { $0["id"] as? String }
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
        var body: [String: Any] = [
            "model": request.model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": request.systemPrompt,
            "messages": [
                [
                    "role": "user",
                    // The file goes first: the model reads documents best when
                    // the question follows them.
                    "content": [
                        documentBlock(request.document),
                        ["type": "text", "text": request.userPrompt],
                    ],
                ]
            ],
            "output_config": [
                "format": ["type": "json_schema", "schema": AIDeckPrompt.schema]
            ],
        ]

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("messages"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = AIHTTP.timeout
        authorize(&urlRequest, apiKey: request.apiKey)

        if fallbackModels.contains(request.model) {
            body["fallbacks"] = "default"
            urlRequest.setValue(fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        }

        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        return urlRequest
    }

    private static func authorize(_ request: inout URLRequest, apiKey: String) {
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
    }

    private static func documentBlock(_ document: AIDocument) -> [String: Any] {
        switch document {
        case .text(let name, let content):
            return [
                "type": "text",
                "text": AIDeckPrompt.textDocument(name: name, content: content),
            ]
        case .pdf(_, let data):
            return [
                "type": "document",
                "source": [
                    "type": "base64",
                    "media_type": "application/pdf",
                    "data": data.base64EncodedString(),
                ],
            ]
        }
    }

    // MARK: - Response

    /// Assembles the answer from the stream's events.
    struct Answer {

        private var collected = ""
        private var stopReason: String?

        mutating func consume(_ event: Data) throws {
            guard let object = (try? JSONSerialization.jsonObject(with: event)) as? [String: Any],
                  let type = object["type"] as? String
            else { return }

            switch type {
            case "content_block_start":
                // A fallback block marks the point where another model took
                // over and started the answer again, so what came before it is
                // an abandoned attempt.
                let block = object["content_block"] as? [String: Any]
                if block?["type"] as? String == "fallback" { collected = "" }

            case "content_block_delta":
                let delta = object["delta"] as? [String: Any]
                if delta?["type"] as? String == "text_delta" {
                    collected += delta?["text"] as? String ?? ""
                }

            case "message_delta":
                let delta = object["delta"] as? [String: Any]
                if let reason = delta?["stop_reason"] as? String { stopReason = reason }

            case "error":
                throw AIFailure.service(AIHTTP.errorMessage(in: object) ?? "")

            default:
                break
            }
        }

        func text() throws -> String {
            switch stopReason {
            case "refusal":    throw AIFailure.refused
            case "max_tokens": throw AIFailure.truncated
            default:           break
            }

            guard !collected.isEmpty else { throw AIFailure.emptyResponse }
            return collected
        }
    }
}
