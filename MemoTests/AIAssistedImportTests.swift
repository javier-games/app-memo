//
//  AIAssistedImportTests.swift
//  MemoTests
//

import XCTest
@testable import Memo

final class AIAssistedImportTests: XCTestCase {

    private static let deckJSON = """
    {"deckList":[{"name":"Food","icon":"🥩","color":"253,251,102,255","cardList":[
      {"frontText":"Tea","frontHintText":"","backText":"Té","backHintText":""},
      {"frontText":"Sushi","frontHintText":"","backText":"","backHintText":""}
    ]}]}
    """

    private func request(
        model: String = "claude-opus-5-5",
        document: AIDocument = .text(name: "words.csv", content: "tea,té")
    ) -> AIDeckRequest {
        AIDeckRequest(
            apiKey: "test-key",
            model: model,
            systemPrompt: AIDeckPrompt.system,
            userPrompt: AIDeckPrompt.user(fileName: document.name, customPrompt: ""),
            document: document
        )
    }

    private func jsonBody(of request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func event(_ json: String) -> Data { Data(json.utf8) }

    // MARK: - Prompt

    func testCustomPromptIsAddedToTheDefaultOne() {
        let prompt = AIDeckPrompt.user(fileName: "notes.pdf", customPrompt: "  Only chapter 2  ")

        XCTAssertTrue(prompt.contains("notes.pdf"))
        XCTAssertTrue(prompt.contains("Additional instructions:\nOnly chapter 2"))
    }

    func testBlankCustomPromptAddsNothing() {
        let prompt = AIDeckPrompt.user(fileName: "notes.pdf", customPrompt: " \n ")

        XCTAssertFalse(prompt.contains("Additional instructions"))
    }

    func testSchemaRequiresEveryPropertyAndAllowsNoOthers() throws {
        let schema = AIDeckPrompt.schema
        XCTAssertEqual(schema["required"] as? [String], ["deckList"])
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false)

        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let deckList = try XCTUnwrap(properties["deckList"] as? [String: Any])
        let deck = try XCTUnwrap(deckList["items"] as? [String: Any])
        XCTAssertEqual(deck["required"] as? [String], ["cardList", "color", "icon", "name"])
    }

    // MARK: - Documents

    func testOversizedFileIsRefusedNotTrimmed() {
        let data = Data(count: AIImportKind.textFile.sizeLimitInMegabytes * 1_048_576 + 1)

        XCTAssertThrowsError(
            try AIDeckGenerator.document(named: "big.txt", data: data, kind: .textFile)
        ) { error in
            XCTAssertEqual(error as? AIFailure, .fileTooLarge(megabytes: 1))
        }
    }

    func testTextFileIsReadAsText() throws {
        let document = try AIDeckGenerator.document(
            named: "words.csv", data: Data("tea,té".utf8), kind: .textFile
        )

        guard case .text(let name, let content) = document else {
            return XCTFail("Expected a text document")
        }
        XCTAssertEqual(name, "words.csv")
        XCTAssertEqual(content, "tea,té")
    }

    // MARK: - Claude

    func testClaudeRequestAsksForTheDeckFormat() throws {
        let urlRequest = try ClaudeClient.makeRequest(request())
        let body = try jsonBody(of: urlRequest)

        XCTAssertEqual(urlRequest.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "x-api-key"), "test-key")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(body["model"] as? String, "claude-opus-5-5")
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(body["system"] as? String, AIDeckPrompt.system)

        let config = try XCTUnwrap(body["output_config"] as? [String: Any])
        let format = try XCTUnwrap(config["format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        XCTAssertNotNil(format["schema"])
    }

    func testClaudeRequestPutsThePDFBeforeTheQuestion() throws {
        let pdf = Data([0x25, 0x50, 0x44, 0x46])
        let body = try jsonBody(of: ClaudeClient.makeRequest(
            request(document: .pdf(name: "notes.pdf", data: pdf))
        ))

        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages.first?["content"] as? [[String: Any]])
        XCTAssertEqual(content.map { $0["type"] as? String }, ["document", "text"])

        let source = try XCTUnwrap(content[0]["source"] as? [String: Any])
        XCTAssertEqual(source["media_type"] as? String, "application/pdf")
        XCTAssertEqual(source["data"] as? String, pdf.base64EncodedString())
    }

    func testClaudeFallbackIsOnlyRequestedWhereSupported() throws {
        let supported = try ClaudeClient.makeRequest(request(model: "claude-opus-5-5"))
        XCTAssertEqual(try jsonBody(of: supported)["fallbacks"] as? String, "default")
        XCTAssertEqual(
            supported.value(forHTTPHeaderField: "anthropic-beta"),
            "server-side-fallback-2026-07-01"
        )

        let unsupported = try ClaudeClient.makeRequest(request(model: "claude-haiku-4-5"))
        XCTAssertNil(try jsonBody(of: unsupported)["fallbacks"])
        XCTAssertNil(unsupported.value(forHTTPHeaderField: "anthropic-beta"))
    }

    func testClaudeAnswerJoinsTextDeltas() throws {
        var answer = ClaudeClient.Answer()
        try answer.consume(event(#"{"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"hm"}}"#))
        try answer.consume(event(#"{"type":"content_block_delta","delta":{"type":"text_delta","text":"{\"deck"}}"#))
        try answer.consume(event(#"{"type":"content_block_delta","delta":{"type":"text_delta","text":"List\":[]}"}}"#))
        try answer.consume(event(#"{"type":"message_delta","delta":{"stop_reason":"end_turn"}}"#))

        XCTAssertEqual(try answer.text(), #"{"deckList":[]}"#)
    }

    func testClaudeAnswerStartsAgainAfterAFallback() throws {
        var answer = ClaudeClient.Answer()
        try answer.consume(event(#"{"type":"content_block_delta","delta":{"type":"text_delta","text":"{\"deckLi"}}"#))
        try answer.consume(event(#"{"type":"content_block_start","content_block":{"type":"fallback"}}"#))
        try answer.consume(event(#"{"type":"content_block_delta","delta":{"type":"text_delta","text":"{}"}}"#))

        XCTAssertEqual(try answer.text(), "{}")
    }

    func testClaudeAnswerReportsRefusalAndTruncation() throws {
        var refused = ClaudeClient.Answer()
        try refused.consume(event(#"{"type":"message_delta","delta":{"stop_reason":"refusal"}}"#))
        XCTAssertThrowsError(try refused.text()) { XCTAssertEqual($0 as? AIFailure, .refused) }

        var truncated = ClaudeClient.Answer()
        try truncated.consume(event(#"{"type":"content_block_delta","delta":{"type":"text_delta","text":"{"}}"#))
        try truncated.consume(event(#"{"type":"message_delta","delta":{"stop_reason":"max_tokens"}}"#))
        XCTAssertThrowsError(try truncated.text()) { XCTAssertEqual($0 as? AIFailure, .truncated) }

        var failed = ClaudeClient.Answer()
        XCTAssertThrowsError(
            try failed.consume(event(#"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#))
        ) { XCTAssertEqual($0 as? AIFailure, .service("Overloaded")) }
    }

    // MARK: - ChatGPT

    func testOpenAIRequestAsksForTheDeckFormat() throws {
        let pdf = Data([0x25, 0x50, 0x44, 0x46])
        let urlRequest = try OpenAIClient.makeRequest(
            request(model: "gpt-5.5", document: .pdf(name: "notes.pdf", data: pdf))
        )
        let body = try jsonBody(of: urlRequest)

        XCTAssertEqual(urlRequest.url?.absoluteString, "https://api.openai.com/v1/responses")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(body["model"] as? String, "gpt-5.5")
        XCTAssertEqual(body["instructions"] as? String, AIDeckPrompt.system)

        let input = try XCTUnwrap(body["input"] as? [[String: Any]])
        let content = try XCTUnwrap(input.first?["content"] as? [[String: Any]])
        XCTAssertEqual(content.map { $0["type"] as? String }, ["input_file", "input_text"])
        XCTAssertEqual(
            content[0]["file_data"] as? String,
            "data:application/pdf;base64,\(pdf.base64EncodedString())"
        )

        let text = try XCTUnwrap(body["text"] as? [String: Any])
        let format = try XCTUnwrap(text["format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        XCTAssertEqual(format["strict"] as? Bool, true)
    }

    func testOpenAIAnswerJoinsTextDeltas() throws {
        var answer = OpenAIClient.Answer()
        try answer.consume(event(#"{"type":"response.output_text.delta","delta":"{\"deckList\""}"#))
        try answer.consume(event(#"{"type":"response.output_text.delta","delta":":[]}"}"#))
        try answer.consume(event(#"{"type":"response.completed","response":{}}"#))

        XCTAssertEqual(try answer.text(), #"{"deckList":[]}"#)
    }

    func testOpenAIAnswerReportsFailures() throws {
        var cutOff = OpenAIClient.Answer()
        try cutOff.consume(event(#"{"type":"response.output_text.delta","delta":"{"}"#))
        try cutOff.consume(event(#"{"type":"response.incomplete","response":{}}"#))
        XCTAssertThrowsError(try cutOff.text()) { XCTAssertEqual($0 as? AIFailure, .truncated) }

        var failed = OpenAIClient.Answer()
        XCTAssertThrowsError(
            try failed.consume(event(#"{"type":"response.failed","response":{"error":{"message":"Bad file"}}}"#))
        ) { XCTAssertEqual($0 as? AIFailure, .service("Bad file")) }
    }

    func testOpenAIModelListKeepsOnlyChatModels() {
        let models = OpenAIClient.chatModels(in: [
            "gpt-5", "gpt-5.5", "text-embedding-3-large", "gpt-realtime", "gpt-image-1", "whisper-1",
        ])

        XCTAssertEqual(models, ["gpt-5.5", "gpt-5"])
    }

    // MARK: - Generating

    private struct StubClient: AIClient {
        var answer: String

        func models(apiKey: String) async throws -> [String] { [] }
        func generateDeckJSON(_ request: AIDeckRequest) async throws -> String { answer }
    }

    func testAnswerGoesThroughTheOrdinaryImporter() async throws {
        let preview = try await AIDeckGenerator.generate(
            from: .text(name: "words.csv", content: "tea,té"),
            customPrompt: "",
            model: "claude-opus-5-5",
            apiKey: "test-key",
            using: StubClient(answer: Self.deckJSON)
        )

        XCTAssertEqual(preview.deckCount, 1)
        XCTAssertEqual(preview.cardCount, 1)
        // The card with no back is left out, as it would be from a file.
        XCTAssertEqual(preview.skippedCardCount, 1)
    }

    func testAnswerThatIsNotADeckFileIsAnError() async {
        do {
            _ = try await AIDeckGenerator.generate(
                from: .text(name: "words.csv", content: "tea,té"),
                customPrompt: "",
                model: "claude-opus-5-5",
                apiKey: "test-key",
                using: StubClient(answer: "Sorry, I can't help with that.")
            )
            XCTFail("Expected an error")
        } catch {
            XCTAssertTrue(error is DeckImporter.Failure)
        }
    }

    // MARK: - Settings

    private final class MemorySecretStore: SecretStore {
        var secrets: [String: String] = [:]

        func secret(for account: String) -> String? { secrets[account] }
        func setSecret(_ secret: String?, for account: String) throws { secrets[account] = secret }
    }

    private func makeStore(secrets: SecretStore) -> AISettingsStore {
        let suite = "test.ai.settings.\(UUID().uuidString)"
        return AISettingsStore(defaults: UserDefaults(suiteName: suite)!, secrets: secrets)
    }

    func testConnectingStoresTheKeyAndPicksAModel() throws {
        let secrets = MemorySecretStore()
        let store = makeStore(secrets: secrets)
        store.settings.provider = .claude
        XCTAssertFalse(store.isConnected)

        try store.connect(.claude, apiKey: "key", models: ["claude-haiku-4-5", "claude-opus-5-5"])

        XCTAssertTrue(store.isConnected)
        XCTAssertEqual(store.apiKey(for: .claude), "key")
        XCTAssertEqual(store.model(for: .claude), "claude-opus-5-5")
    }

    func testNoAssistantIsSelectedByDefault() throws {
        let store = makeStore(secrets: MemorySecretStore())
        XCTAssertNil(store.settings.provider)

        // A key alone is not enough: the tool also has to be the one chosen.
        try store.connect(.claude, apiKey: "key", models: [])
        XCTAssertFalse(store.isConnected)
    }

    func testConnectionIsPerTool() throws {
        let store = makeStore(secrets: MemorySecretStore())
        try store.connect(.claude, apiKey: "key", models: [])
        store.settings.provider = .claude
        XCTAssertTrue(store.isConnected)

        store.settings.provider = .chatGPT
        XCTAssertFalse(store.isConnected)

        store.settings.provider = .claude
        store.disconnect(.claude)
        XCTAssertFalse(store.isConnected)
        XCTAssertNil(store.apiKey(for: .claude))
    }

    func testRefreshedModelListKeepsTheChoiceWhileItIsStillOffered() throws {
        let store = makeStore(secrets: MemorySecretStore())
        try store.connect(.claude, apiKey: "key", models: ["claude-opus-5-5", "claude-haiku-4-5"])
        store.setModel("claude-haiku-4-5", for: .claude)

        store.updateModels(["claude-opus-5-5", "claude-haiku-4-5", "claude-sonnet-5-5"], for: .claude)
        XCTAssertEqual(store.model(for: .claude), "claude-haiku-4-5")

        store.updateModels(["claude-opus-5-5"], for: .claude)
        XCTAssertEqual(store.model(for: .claude), "claude-opus-5-5")
    }

    func testModelsAreGroupedIntoKnownAndOther() {
        let groups = AIProvider.chatGPT.grouped(["gpt-4o", "gpt-9-preview", "gpt-5"])

        XCTAssertEqual(groups.known, ["gpt-5", "gpt-4o"])
        XCTAssertEqual(groups.other, ["gpt-9-preview"])
    }

    func testPreferredModelFallsBackToWhatTheKeyHas() {
        XCTAssertEqual(AIProvider.chatGPT.preferredModel(among: ["gpt-5", "gpt-4o"]), "gpt-5")
        XCTAssertEqual(AIProvider.chatGPT.preferredModel(among: ["gpt-4o"]), "gpt-4o")
        XCTAssertEqual(AIProvider.chatGPT.preferredModel(among: []), "gpt-5.5")
    }
}
