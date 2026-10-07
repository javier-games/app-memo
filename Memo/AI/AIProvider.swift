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
    var defaultModel: String { preferredModels[0] }

    /// Best first. The first one the key has access to becomes the selection.
    var preferredModels: [String] {
        switch self {
        case .claude:  ["claude-opus-5-5"]
        case .chatGPT: ["gpt-5.5", "gpt-5.4", "gpt-5"]
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
        preferredModels.first { available.contains($0) } ?? available.first ?? defaultModel
    }

    func makeClient() -> AIClient {
        switch self {
        case .claude:  return ClaudeClient()
        case .chatGPT: return OpenAIClient()
        }
    }
}
