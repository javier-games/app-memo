//
//  AIDeckGenerator.swift
//  Memo
//

import Foundation
import UniformTypeIdentifiers

/// The kinds of file AI-assisted import accepts.
enum AIImportKind: String, CaseIterable, Identifiable {

    case textFile
    case pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .textFile: String(localized: "Text File")
        case .pdf:      "PDF"
        }
    }

    var menuIcon: String {
        switch self {
        case .textFile: "doc.text"
        case .pdf:      "doc.richtext"
        }
    }

    /// `.text` covers plain text, CSV, JSON, Markdown and the like.
    var contentTypes: [UTType] {
        switch self {
        case .textFile: [.text]
        case .pdf:      [.pdf]
        }
    }

    /// Too large a file is refused rather than trimmed: cards made from part
    /// of a file would look complete and not be.
    var sizeLimitInMegabytes: Int {
        switch self {
        case .textFile: 1
        // Encoded for sending, a PDF grows by a third, and the services cap a
        // whole request at about 32 MB.
        case .pdf:      20
        }
    }
}

/// Turns a file into decks by way of an AI service.
///
/// Stops at a ``DeckImporter/Preview``, like any other import: nothing is
/// written until the user has seen what was found.
enum AIDeckGenerator {

    static func loadDocument(at url: URL, kind: AIImportKind) throws -> AIDocument {
        let data = try DeckImporter.read(contentsOf: url)
        return try document(named: url.lastPathComponent, data: data, kind: kind)
    }

    static func document(named name: String, data: Data, kind: AIImportKind) throws -> AIDocument {
        guard data.count <= kind.sizeLimitInMegabytes * 1_048_576 else {
            throw AIFailure.fileTooLarge(megabytes: kind.sizeLimitInMegabytes)
        }

        switch kind {
        case .pdf:
            return .pdf(name: name, data: data)

        case .textFile:
            guard let content = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
            else { throw AIFailure.unreadableText }

            return .text(name: name, content: content)
        }
    }

    static func generate(
        from document: AIDocument,
        customPrompt: String,
        model: String,
        apiKey: String,
        using client: AIClient
    ) async throws -> DeckImporter.Preview {
        let json = try await client.generateDeckJSON(
            AIDeckRequest(
                apiKey: apiKey,
                model: model,
                systemPrompt: AIDeckPrompt.system,
                userPrompt: AIDeckPrompt.user(
                    fileName: document.name,
                    customPrompt: customPrompt
                ),
                document: document
            )
        )

        return try DeckImporter.preview(
            data: Data(json.utf8),
            kind: .json,
            fallbackDeckName: (document.name as NSString).deletingPathExtension
        )
    }
}
