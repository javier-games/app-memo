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
    
    @State private var currentCardIndex = 0
    @State private var reveal = false
    
    @State private var isCorrect = false
    @State private var isAnswered = false
    @State private var flagMarked = false;
    
    @State private var cardVisibility = false;
    
    @State private var cardPosition = CGPoint.zero
    @State private var dragAmount = CGSize.zero
    
    @State private var inLeftTrigger = false
    @State private var inRightTrigger = false
    @State private var inTrigger = false
    
    @State private var interactivity: [CardInteractivity] = [.angularDrag, .flipTap]
    @State private var hasBeenFlipped = false
    @State private var flipDirection = false
    
    @State private var shakeAmount: CGFloat = 0
    
    var cardOrigin = CGPoint(
        x: UIScreen.main.bounds.midX,
        y: UIScreen.main.bounds.midY - 100
    )
    
    var frontView: some View {
        Text(deck.cardList[currentCardIndex].frontText)
            .frame(width: 200, height: 300)
            .background(deck.getColor())
    }
    
    var backView: some View {
        Text(deck.cardList[currentCardIndex].backText)
            .frame(width: 200, height: 300)
            .background(deck.getColor())
    }
    
    var body: some View {
        ZStack {
            
            TriggerView(
                x: 50,
                y: UIScreen.main.bounds.midY,
                width: 100,
                height: UIScreen.main.bounds.height
            )
            
            TriggerView(
                x: UIScreen.main.bounds.width - 50,
                y: UIScreen.main.bounds.midY,
                width: 100,
                height: UIScreen.main.bounds.height
            )
            
            VStack{
                
                CardView (
                    isVisible: .constant(true),
                    isReveled: reveal,
                    frontView: frontView,
                    backView: backView,
                    interactivity: interactivity,
                    onFlip: { print(reveal) },
                    onAppear: {},
                    onDissaper: {}
                )
                
                
//                CardView(
//                    isVisible: $cardVisibility,
//                    isReveled: $reveal,
//                    flipDirection: $flipDirection,
//                    frontView: frontView,
//                    backView: backView,
//                    interactivity: $interactivity,
//                    dragAmount: dragAmount,
//                    onFlip: {
//                        hasBeenFlipped = true
//                        if cardVisibility {
//                            interactivity = .angularDrag
//                        }
//                    },
//                    onAppear: {},
//                    onDissaper: reset
//                )
//                .modifier(ShakeEffect(animatableData: shakeAmount))
//                .position(cardPosition)
//                .gesture(dragGesture)
            }
            
        }
        .onAppear(perform: initialize)
        .toolbar{
            
            
            ToolbarItem(placement: .principal) {
                ProgressView(value: calculateProgress())
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
                        action: {withAnimation {
                            reveal.toggle()
                        }}
                    )
                }
            }
        }
    }
    
    func initialize(){
        cardPosition = cardOrigin
        cardVisibility = true
//        interactivity = .flipTap
        
    }
    
    func calculateProgress() -> Double {
        return Double(currentCardIndex) / Double(deck.cardList.count)
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                dragAmount = CGSize(width: gesture.translation.width, height: 0)
                updateTriggers()
            }
            .onEnded { _ in
                if(reveal){
                    cardPosition.x += dragAmount.width
                }
                dragAmount = .zero
                checkDropTrigger()
            }
    }
    
    private func reset() {
        // Reset the state as needed
        cardPosition = cardOrigin
        
        reveal = false
        hasBeenFlipped = false
        updateTriggers()
        cardVisibility = true
//        interactivity = .flipDrag
    }
    
    private func updateTriggers() {
        let cardCenter = CGPoint(x: cardPosition.x + dragAmount.width, y: cardPosition.y + dragAmount.height)
        inLeftTrigger = cardCenter.x < 100
        inRightTrigger = cardCenter.x > UIScreen.main.bounds.width - 100
        inTrigger = inLeftTrigger || inRightTrigger
        isAnswered = reveal && inTrigger
        isCorrect = isAnswered && inRightTrigger
    }
    
    private func checkDropTrigger() {
        if reveal {
            if inLeftTrigger {
                markCorrect()
            } else if inRightTrigger {
                markIncorrect()
            } else {
                withAnimation {
                    reset()
                }
            }
        }
        else{
            if inTrigger {
                if inLeftTrigger {
                    flipDirection = true
                }
                withAnimation {
                    reveal.toggle()
                }
                flipDirection = false
            }
            else{
                withAnimation {
                    reset()
                }
            }
        }
    }
    
    private func markCorrect(){
        cardVisibility = false
    }
    
    private func markIncorrect(){
        withAnimation(.linear(duration: 0.2)) {
            self.shakeAmount += 10
        }
        
        cardVisibility = false
    }
    
    private func skip(){
        withAnimation(.linear(duration: 0.5)) {
            self.shakeAmount += 1
        }
        
        cardVisibility = false
    }
    
    private func markFlagged(){
        withAnimation(.linear(duration: 0.5)) {
            flagMarked.toggle()
        }
    }
    
}

struct TriggerView: View {
    
    let x : CGFloat;
    let y : CGFloat;
    let width : CGFloat;
    let height : CGFloat;
    
    var body: some View {
        Rectangle()
            .opacity(0)
            .frame(width: width, height: height)
            .position(x: x, y: y)
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakesPerUnit), y: 0))
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
            color: Color.accentColor
        )
        
        dummyDeckData.cardList = [
            CardData(frontText: "Front", backText: "Back"),
            CardData(frontText: "F", backText: "B")
        ]
        
        return NavigationView {FlashCardsView(deck: .constant(dummyDeckData))}
    }
}
