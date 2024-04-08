//
//  ContentView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/01/25.
//

import SwiftUI
import Combine

struct FlashCardsView: View {
    
    @Binding var deck: DeckData
    
    @State private var currentCardIndex = -1
    
    @State private var flip = false
    @State private var offset: CGSize = CGSize.zero
    @State private var interactivity: [CardInteractivity] = [.flipTap]
    
    @State private var hasBeenFlipped = false
    @State private var cardScale: CGFloat = 0
    
    @State private var practiceCards: [CardData]
    
    
    let cardOrigin = CGPoint(
        x: UIScreen.main.bounds.midX,
        y: UIScreen.main.bounds.midY - 100
    )
    
    var frontView: some View {
        Text(
            isCardIndexInRange() ? "" :
            practiceCards[currentCardIndex].frontText
        )
        .frame(width: 200, height: 300)
        .background(deck.getColor())
        .foregroundColor(deck.getColor().invertedColor())
    }
    
    var backView: some View {
        
        Text(
            isCardIndexInRange() ? "" :
            practiceCards[currentCardIndex].backText
        )
        .frame(width: 200, height: 300)
        .background(deck.getColor())
        .foregroundColor(deck.getColor().invertedColor())
    }
    
    var body: some View {
        
        ZStack {
            
            VStack{
                CardView (
                    flip: $flip,
                    frontView: frontView,
                    backView: backView,
                    interactivity: $interactivity,
                    offset: $offset,
                    scale: $cardScale,
                    flipAngle: 180,
                    onFlip: onFlip,
                    onRelease: onRelease
                )
                .onAppear(perform: onAppear)
            }
            
        }
        .toolbar{
            
            ToolbarItem(placement: .principal) {
                ProgressView(
                    value:  Double(currentCardIndex) /  Double(practiceCards.count))
                    .progressViewStyle(LinearProgressViewStyle())
            }
            
            ToolbarItem(placement: .bottomBar)
            {
                HStack{
                    
                    CircleButtonView(
                        iconName: "forward.fill",
                        buttonColor: Color.accentColor,
                        isEnabled: .constant(true),
                        action: skip
                    )
                    
                    CircleButtonView(
                        iconName: "xmark",
                        buttonColor: Color.red,
                        isEnabled: $hasBeenFlipped,
                        action: markIncorrect
                    )
                    
                    CircleButtonView(
                        iconName: "checkmark",
                        buttonColor: Color.green,
                        isEnabled: $hasBeenFlipped,
                        action: markCorrect
                    )
                    
                    CircleButtonView(
                        iconName: "arrow.2.squarepath",
                        buttonColor: Color.accentColor,
                        isEnabled: .constant(true),
                        action:  { flip.toggle() }
                    )
                }
            }
        }
    }
    
    
    init(deck: Binding<DeckData>) {
        self._deck = deck
        self.practiceCards = deck.wrappedValue.getPracticeCards()
    }
    
    private func isCardIndexInRange() -> Bool{
        return currentCardIndex < 0
        || currentCardIndex >= practiceCards.count
    }
    
    private func onAppear(){
        getCard()
    }
    
    private func getCard(){
        
        if practiceCards.isEmpty {
            completePractice()
            return
        }
        
        currentCardIndex += 1
        
        if currentCardIndex >= practiceCards.count {
            completePractice()
            return
        }
        
        
        offset = .zero
        hasBeenFlipped = false
        
        if !interactivity.contains(.flipTap) {
            interactivity.append(.flipTap)
        }
        
        if !interactivity.contains(.flipDrag) {
            interactivity.append(.flipDrag)
        }
        
        showCard()
    }
    
    private func onFlip(isReveled: Bool){
        if isReveled {
            if interactivity.contains(.flipDrag) {
                interactivity.removeAll { i in i == .flipDrag }
            }
            
            if !interactivity.contains(.horizontalDrag) {
                interactivity.append(.horizontalDrag)
            }
            
            hasBeenFlipped = true
        }
        else {
            if interactivity.contains(.horizontalDrag) {
                interactivity.removeAll { i in i == .horizontalDrag }
            }
            
            if !interactivity.contains(.flipDrag) {
                interactivity.append(.flipDrag)
            }
        }
    }
    
    private func onRelease(isReveled: Bool){
        if !isReveled { return }
        
        if offset.width > 100 {
            markCorrect()
        }
        
        else if offset.width < -100 {
            markIncorrect()
        }
        
        else {
            withAnimation{
                offset = .zero
            }
        }
    }
    
    private func markCorrect(){
        hideCard { getCard() }
    }
    
    private func markIncorrect(){
        hideCard { getCard() }
    }
    
    private func skip(){
        hideCard { getCard() }
    }
    
    private func showCard() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
            cardScale = 1.0
        }
    }
    
    private func hideCard(callback: @escaping () -> Void) {
        let animationDuration = 0.3
        flip = true
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
            cardScale = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            callback()
        }
    }
    
    private func completePractice(){
        
    }
    
}

struct CircleButtonView: View {
    let iconName: String
    let buttonColor: Color // Added color parameter
    @Binding var isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .foregroundColor(.white)
        }
        .disabled(!isEnabled)
        .padding(15)
        .frame(width: 70)
        .background(isEnabled ? buttonColor : Color.gray) // Use the color parameter here
        .clipShape(Circle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        
        let dummyDeckData: DeckData = DeckData(
            name: "My Deck",
            icon: "😂",
            color: Color.yellow
        )
        
        dummyDeckData.cardList = [
            CardData(frontText: "Front", backText: "Back"),
            CardData(frontText: "F", backText: "B")
        ]
        
        return NavigationView {FlashCardsView(deck: .constant(dummyDeckData))}
    }
}
