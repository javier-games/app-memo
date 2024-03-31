//
//  MemoApp.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/01/25.
//

import SwiftUI

@main
struct MemoApp: App {
    
    @ObservedObject static var decks = DecksData()

    init() {
        MemoApp.decks = MemoApp.loadDecksData() // Assuming load() returns the array of decks
    }
    
    var body: some Scene {
        WindowGroup {
            DeckListView(deckList: MemoApp.$decks.deckList)
        }
    }
    
    
    static func saveDecksData() {
        do {
            let data = try JSONEncoder().encode(decks)
            UserDefaults.standard.set(data, forKey: "DeckList")
        } catch {
            print("Error saving deck list: \(error)")
        }
    }

    private static func loadDecksData() -> DecksData {
        if let data = UserDefaults.standard.data(forKey: "DeckList") {
            do {
                let deckList = try JSONDecoder().decode(DecksData.self, from: data)
                return deckList
            } catch {
                print("Error loading deck list: \(error)")
            }
        }
        return DecksData()
    }
}
