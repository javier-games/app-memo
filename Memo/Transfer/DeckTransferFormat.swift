//
//  DeckTransferFormat.swift
//  Memo
//
//  The on-disk shape of a deck file, exactly as the README documents it:
//
//      { "deckList": [ { "name", "icon", "color", "cardList": [ … ] } ] }
//
//  Kept apart from the SwiftData models on purpose. `@Model` types are not
//  Codable, and tying the file format to them would mean every future model
//  change silently altering a format other people's files are written in.
//

import Foundation

/// A whole file: the library, or part of it.
struct DeckTransferFile: Codable {
    var deckList: [DeckTransferDeck] = []
}

struct DeckTransferDeck: Codable {

    var name: String
    var icon: String
    /// `"r,g,b,a"`, each 0...255, as the documented format stores colour.
    var color: String
    var cardList: [DeckTransferCard]

    init(
        name: String = "",
        icon: String = "",
        color: String = "",
        cardList: [DeckTransferCard] = []
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.cardList = cardList
    }

    /// Everything but the name is optional, so a hand-written file needs only
    /// what the author cares about.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        icon = (try? container.decode(String.self, forKey: .icon)) ?? ""
        color = (try? container.decode(String.self, forKey: .color)) ?? ""
        cardList = (try? container.decode([DeckTransferCard].self, forKey: .cardList)) ?? []
    }
}

struct DeckTransferCard: Codable {

    var frontText: String
    var frontHintText: String
    var backText: String
    var backHintText: String

    /// Not part of the documented format. Read when present so a file written
    /// by a later version keeps its progress, and absent from anything written
    /// to the published schema.
    var practiceProgress: Int?

    init(
        frontText: String = "",
        frontHintText: String = "",
        backText: String = "",
        backHintText: String = "",
        practiceProgress: Int? = nil
    ) {
        self.frontText = frontText
        self.frontHintText = frontHintText
        self.backText = backText
        self.backHintText = backHintText
        self.practiceProgress = practiceProgress
    }

    /// Mirrors the tolerance the first release needed: the hint fields postdate
    /// it and are missing from older payloads.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frontText = (try? container.decode(String.self, forKey: .frontText)) ?? ""
        backText = (try? container.decode(String.self, forKey: .backText)) ?? ""
        frontHintText = (try? container.decode(String.self, forKey: .frontHintText)) ?? ""
        backHintText = (try? container.decode(String.self, forKey: .backHintText)) ?? ""
        practiceProgress = try? container.decode(Int.self, forKey: .practiceProgress)
    }

    /// A card with no front or no back cannot be practised, so it is not worth
    /// importing.
    var isComplete: Bool {
        !frontText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !backText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Converts the format's `"r,g,b,a"` colour string.
enum DeckTransferColor {

    static let fallback = (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

    static func components(
        from string: String
    ) -> (red: Double, green: Double, blue: Double, alpha: Double) {
        let parts = string.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else { return fallback }

        return (normalize(parts[0]), normalize(parts[1]), normalize(parts[2]), normalize(parts[3]))
    }

    /// The inverse, for writing files.
    static func string(
        red: Double, green: Double, blue: Double, alpha: Double
    ) -> String {
        let byte = { (value: Double) in Int((min(1, max(0, value)) * 255).rounded()) }
        return "\(byte(red)),\(byte(green)),\(byte(blue)),\(byte(alpha))"
    }

    private static func normalize(_ value: Int) -> Double {
        min(1, max(0, Double(value) / 255.0))
    }
}
