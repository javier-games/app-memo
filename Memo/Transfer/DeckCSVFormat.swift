//
//  DeckCSVFormat.swift
//  Memo
//
//  CSV carries cards only — it has nowhere to put a deck's name, icon or
//  colour. The deck name therefore travels as the file name: a CSV export is
//  named after its deck, and a CSV import names the new deck after the file.
//

import Foundation

enum DeckCSVFormat {

    static let header = ["front", "frontHint", "back", "backHint"]

    // MARK: - Writing

    static func serialize(_ cards: [DeckTransferCard]) -> String {
        let rows = [header.joined(separator: ",")] + cards.map { card in
            [card.frontText, card.frontHintText, card.backText, card.backHintText]
                .map(escape)
                .joined(separator: ",")
        }

        return rows.joined(separator: "\r\n") + "\r\n"
    }

    /// Quotes a field only when it needs it, doubling any quotes inside, per
    /// RFC 4180.
    private static func escape(_ field: String) -> String {
        // Line breaks are checked at scalar level: Swift treats CRLF as a
        // single Character, so `contains("\n")` misses a field containing one.
        let hasLineBreak = field.unicodeScalars.contains { $0 == "\n" || $0 == "\r" }
        let needsQuoting = field.contains(",") || field.contains("\"") || hasLineBreak

        guard needsQuoting else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Reading

    /// Parses cards from CSV text.
    ///
    /// A header row is optional: files exported here carry one, and a
    /// hand-written file may not. Rows are read positionally as
    /// front, front hint, back, back hint, and short rows are padded rather
    /// than rejected so a two-column file still imports.
    static func parse(_ text: String) -> [DeckTransferCard] {
        // Spreadsheets and most export tools write a byte order mark. Left in
        // place it rides along as an invisible character on the first field,
        // which both corrupts the first card and stops the header being
        // recognised.
        let text = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text

        var rows = parseRows(text)

        if let first = rows.first, isHeader(first) {
            rows.removeFirst()
        }

        return rows.compactMap { row in
            guard row.contains(where: { !$0.isEmpty }) else { return nil }

            func field(_ index: Int) -> String {
                index < row.count ? row[index].trimmingCharacters(in: .whitespaces) : ""
            }

            // Two columns can only be a front and a back. Read positionally
            // the second would be a hint, leaving a card with no back, which
            // is the one thing a two-column file is certainly not.
            if row.count == 2 {
                return DeckTransferCard(frontText: field(0), backText: field(1))
            }

            return DeckTransferCard(
                frontText: field(0),
                frontHintText: field(1),
                backText: field(2),
                backHintText: field(3)
            )
        }
    }

    private static func isHeader(_ row: [String]) -> Bool {
        let normalized = row.map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        }
        return normalized.first == "front" && normalized.contains("back")
    }

    /// A single pass RFC 4180 reader: quoted fields may contain commas,
    /// newlines and doubled quotes.
    private static func parseRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character?

        func endField() {
            row.append(field)
            field = ""
        }

        func endRow() {
            endField()
            rows.append(row)
            row = []
        }

        while let character = pending ?? iterator.next() {
            pending = nil

            if inQuotes {
                if character == "\"" {
                    // A doubled quote is a literal quote; a single one closes.
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            pending = next
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
                continue
            }

            switch character {
            case "\"":
                inQuotes = true
            case ",":
                endField()
            case "\n", "\r", "\r\n":
                // CRLF is one Character in Swift, not two, so it is matched
                // here rather than by looking ahead after a lone carriage
                // return — which is why a file written with CRLF previously
                // parsed as a single enormous field.
                endRow()
            default:
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty { endRow() }

        return rows
    }
}
