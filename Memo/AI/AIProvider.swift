//
//  AIProvider.swift
//  Memo
//

import Foundation

/// The AI services Memo can hand a file to.
///
/// Both are reached with an API key the user supplies. Neither Anthropic nor
/// OpenAI lets a third-party app sign in to a Claude or ChatGPT subscription,
/// so a key is the only way in; if that changes, it becomes a second way to
/// fill ``AISettingsStore``'s credentials rather than a change to this type.
enum AIProvider: String, CaseIterable, Identifiable, Codable {

    case claude
    case chatGPT

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude:  "Claude"
        case .chatGPT: "ChatGPT"
        }
    }

    var company: String {
        switch self {
        case .claude:  "Anthropic"
        case .chatGPT: "OpenAI"
        }
    }

    /// Used until the service has reported which models the key can reach.
    var defaultModel: String { knownModels[0] }

    /// Models known to read a file and answer in text, best first.
    ///
    /// OpenAI's model list says nothing about what a model can do, and holds
    /// speech, image and embedding models alongside the chat ones, so the
    /// models worth offering have to be named here. The first one the key has
    /// access to becomes the selection.
    var knownModels: [String] {
        switch self {
        case .claude:
            ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-4-5", "claude-fable-5-1"]
        case .chatGPT:
            ["gpt-5.5", "gpt-5.4", "gpt-5", "gpt-5-mini", "gpt-4.1", "gpt-4o"]
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .claude:  "sk-ant-…"
        case .chatGPT: "sk-…"
        }
    }

    /// Where the user creates a key.
    var keysPage: URL {
        switch self {
        case .claude:  URL(string: "https://platform.claude.com/settings/keys")!
        case .chatGPT: URL(string: "https://platform.openai.com/api-keys")!
        }
    }

    func preferredModel(among available: [String]) -> String {
        knownModels.first { available.contains($0) } ?? available.first ?? defaultModel
    }

    /// Splits what the key can use into the models named in ``knownModels``,
    /// in that order, and the rest, which may or may not suit the job.
    func grouped(_ available: [String]) -> (known: [String], other: [String]) {
        (
            knownModels.filter { available.contains($0) },
            available.filter { !knownModels.contains($0) }
        )
    }

    func makeClient() -> AIClient {
        switch self {
        case .claude:  return ClaudeClient()
        case .chatGPT: return OpenAIClient()
        }
    }
}
