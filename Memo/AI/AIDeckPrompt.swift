//
//  AIDeckPrompt.swift
//  Memo
//
//  What the model is told, and the shape its answer must take. The answer is
//  the same JSON a deck file holds, so it goes through the ordinary importer
//  and gets the same checks as a file the user picked.
//

import Foundation

enum AIDeckPrompt {

    /// Memo's own instructions. Always sent; the user's text is added to them
    /// and never replaces them.
    static let system = """
        You turn study material into flashcards for Memo, a flashcard app.

        Read the attached file and return its content as flashcard decks, in the \
        JSON format you have been given.

        How to build the cards:
        - frontText is what the learner is shown: a term, a question, or a word to \
        translate. backText is what they must recall.
        - frontHintText and backHintText are optional short clues, such as a \
        pronunciation, an example or a mnemonic. Use an empty string when there \
        is nothing useful to add.
        - Use only what the file says. Do not add facts it does not contain.
        - Keep the languages the file uses.
        - If the file is already a list of pairs, a table, CSV or JSON, make one \
        card per entry, in the same order, and leave none out.
        - If the file is prose, write one card per fact worth remembering, and \
        keep each side short.

        How to build the decks:
        - Use one deck unless the file clearly covers separate subjects.
        - name is a short title for the deck. icon is a single emoji that suits \
        it. color is "r,g,b,a" with each part from 0 to 255, for example \
        "52,120,246,255".

        The person using the app may add instructions of their own. Follow them \
        for what to include and how to word the cards. The JSON format always \
        stays the same.
        """

    /// The per-file part of the prompt, with the user's own instructions, if
    /// any, appended.
    static func user(fileName: String, customPrompt: String) -> String {
        var parts = [
            "Create flashcards from the file \"\(fileName)\"."
        ]

        let custom = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            parts.append("Additional instructions:\n\(custom)")
        }

        return parts.joined(separator: "\n\n")
    }

    /// Wraps a text file's content so it cannot be mistaken for instructions.
    static func textDocument(name: String, content: String) -> String {
        "<file name=\"\(name)\">\n\(content)\n</file>"
    }

    /// JSON Schema for ``DeckTransferFile``.
    ///
    /// Every property is required and no others are allowed: both services
    /// insist on that before they will guarantee the answer matches.
    static var schema: [String: Any] {
        let card = object([
            "frontText": string,
            "frontHintText": string,
            "backText": string,
            "backHintText": string,
        ])

        let deck = object([
            "name": string,
            "icon": string,
            "color": string,
            "cardList": ["type": "array", "items": card],
        ])

        return object([
            "deckList": ["type": "array", "items": deck]
        ])
    }

    private static let string: [String: Any] = ["type": "string"]

    private static func object(_ properties: [String: Any]) -> [String: Any] {
        [
            "type": "object",
            "properties": properties,
            "required": properties.keys.sorted(),
            "additionalProperties": false,
        ]
    }
}
