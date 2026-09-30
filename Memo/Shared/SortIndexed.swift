//
//  SortIndexed.swift
//  Memo
//

import Foundation
// move(fromOffsets:toOffset:) is declared in SwiftUI, not the standard library.
import SwiftUI

/// A model whose position is stored rather than implied by array order.
///
/// Both decks and cards need this because CloudKit relationships are unordered
/// sets: position has to be a property, not a place in a list.
protocol SortIndexed: AnyObject {
    var sortIndex: Int { get set }
}

extension Deck: SortIndexed {}
extension Card: SortIndexed {}

extension Array where Element: SortIndexed {

    /// Applies a drag-to-reorder move and rewrites every element's sort index.
    ///
    /// Renumbers the whole list rather than only the rows that moved. Sort
    /// index is the stored order, so leaving gaps or duplicates would let two
    /// elements claim the same position and make the resulting order depend on
    /// the tie-breaker instead of on what the user did.
    ///
    /// The elements are reference types, so this updates them in place.
    /// Moves the element at `index` up or down by `offset` places.
    ///
    /// Wraps the insertion-offset arithmetic ``applyMove(from:to:)`` expects,
    /// which is one past the destination row when moving downwards — the sort
    /// of off-by-one that is invisible until a row lands in the wrong place.
    /// Out-of-range moves are ignored rather than clamped, so a "move up" on
    /// the first row does nothing instead of something surprising.
    func applyMove(at index: Int, by offset: Int) {
        let destination = index + offset + (offset > 0 ? 1 : 0)

        guard indices.contains(index),
              destination >= 0,
              destination <= count
        else { return }

        applyMove(from: IndexSet(integer: index), to: destination)
    }

    func applyMove(from source: IndexSet, to destination: Int) {
        var reordered = self
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, element) in reordered.enumerated() {
            element.sortIndex = index
        }
    }
}
