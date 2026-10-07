//
//  AIClient.swift
//  Memo
//

import Foundation

/// The file handed to the model.
enum AIDocument {

    case text(name: String, content: String)
    case pdf(name: String, data: Data)

    var name: String {
        switch self {
        case .text(let name, _), .pdf(let name, _): name
        }
    }
}

/// Everything one deck-generation call needs.
struct AIDeckRequest {
    var apiKey: String
    var model: String
    var systemPrompt: String
    var userPrompt: String
    var document: AIDocument
}

/// One AI service, reduced to the two things Memo asks of it.
protocol AIClient {

    /// The models the key can use. Doubles as the check that a key works.
    func models(apiKey: String) async throws -> [String]

    /// Returns the model's answer: JSON text in the deck file format.
    func generateDeckJSON(_ request: AIDeckRequest) async throws -> String
}

enum AIFailure: LocalizedError, Equatable {

    case notConnected
    case invalidKey
    case service(String)
    case network(String)
    case refused
    case truncated
    case emptyResponse
    case fileTooLarge(megabytes: Int)
    case unreadableText
    case keychain(Int32)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            String(localized: "No AI tool is connected. Connect one in Settings.")
        case .invalidKey:
            String(localized: "The API key was not accepted. Check it in Settings.")
        case .service(let message):
            String(localized: "The AI service reported a problem. \(message)")
        case .network(let message):
            String(localized: "The AI service could not be reached. \(message)")
        case .refused:
            String(localized: "The AI declined to work with this file.")
        case .truncated:
            String(localized: "The answer was cut off before it finished. Try a smaller file, or ask for fewer cards.")
        case .emptyResponse:
            String(localized: "The AI returned nothing to import.")
        case .fileTooLarge(let megabytes):
            String(localized: "That file is too large. The limit is \(megabytes) MB.")
        case .unreadableText:
            String(localized: "That file's text could not be read.")
        case .keychain(let status):
            String(localized: "The API key could not be saved (Keychain error \(Int(status))).")
        }
    }
}

/// The HTTP both clients share.
enum AIHTTP {

    /// Generation can pause for a while between chunks while the model thinks.
    static let timeout: TimeInterval = 300

    static func data(for request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response, body: data)
            return data
        } catch {
            throw translate(error)
        }
    }

    /// Calls `handle` with the JSON payload of each server-sent event.
    ///
    /// Both services put one JSON object on each `data:` line, so there is no
    /// need to reassemble multi-line events.
    static func forEachEvent(
        of request: URLRequest,
        _ handle: (Data) throws -> Void
    ) async throws {
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                var body = Data()
                for try await byte in bytes { body.append(byte) }
                try validate(response, body: body)
            }

            for try await line in bytes.lines {
                guard line.hasPrefix("data:") else { continue }

                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                guard !payload.isEmpty, payload != "[DONE]" else { continue }

                try handle(Data(payload.utf8))
            }
        } catch {
            throw translate(error)
        }
    }

    static func validate(_ response: URLResponse, body: Data) throws {
        guard let http = response as? HTTPURLResponse,
              !(200..<300).contains(http.statusCode)
        else { return }

        if http.statusCode == 401 { throw AIFailure.invalidKey }

        throw AIFailure.service(
            errorMessage(in: body) ?? String(localized: "Status \(http.statusCode).")
        )
    }

    /// Both services report errors as `{"error": {"message": "…"}}`.
    static func errorMessage(in body: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        return errorMessage(in: object ?? [:])
    }

    static func errorMessage(in object: [String: Any]) -> String? {
        if let error = object["error"] as? [String: Any] {
            return error["message"] as? String
        }
        return object["message"] as? String
    }

    private static func translate(_ error: Error) -> Error {
        if error is AIFailure || error is CancellationError { return error }

        if let urlError = error as? URLError {
            return urlError.code == .cancelled
                ? CancellationError()
                : AIFailure.network(urlError.localizedDescription)
        }

        return error
    }
}
