//
//  Group.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/27.
//

import Foundation
import SwiftUI

class DecksData: ObservableObject, Decodable, Encodable {
    var deckList: [DeckData] = []
}

class DeckData : Identifiable, ObservableObject, Decodable, Encodable{
    
    var name: String
    var icon: String
    private var color: String
    var cardList: [CardData]
    
    init(name: String, icon: String, color: Color) {
        self.name = name
        self.icon = icon
        self.color = DeckData.getStringColorFromColor(color: color)
        self.cardList = Array()
    }
    
    func getColor() -> Color {
        return DeckData.getColorFromStringColor(stringColor: self.color)
    }
    
    func setColor(color: Color){
        self.color = DeckData.getStringColorFromColor(color: color)
    }
    
    private static func getStringColorFromColor(color: Color) -> String {
        let uiColor = UIColor(color)
        guard let components = uiColor.cgColor.components else {
            return ""
        }
        let red = Int(components[0] * 255)
        let green = Int(components[1] * 255)
        let blue = Int(components[2] * 255)
        let alpha = components.count > 3 ? Int(components[3] * 255) : 255
        return String(format: "%d,%d,%d,%d", red, green, blue, alpha)
    }
    
    private static func getColorFromStringColor(stringColor: String) -> Color {
        let components = stringColor.split(separator: ",").compactMap { Int($0) }
        guard components.count == 4 else {
            return Color.black // Default color
        }
        let red = Double(components[0]) / 255.0
        let green = Double(components[1]) / 255.0
        let blue = Double(components[2]) / 255.0
        let alpha = Double(components[3]) / 255.0
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    public func getPracticeCards() -> [CardData] {
        return shuflle(cards: cardList)
    }
    
    private func shuflle(cards: [CardData]) -> [CardData] {
        return cards.shuffled()
    }
}

class CardData : Identifiable, ObservableObject, Decodable, Encodable{
    
    var frontText: String
    var backText: String
    
    init(frontText: String, backText: String) {
        self.frontText = frontText
        self.backText = backText
    }
}
