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
    
    @State private var isCorrect = false
    @State private var isAnswered = false
    @State private var flagMarked = false;
    
    @State private var cardVisibility = false;
    
    @State private var cardPosition = CGPoint.zero
    @State private var dragAmount = CGSize.zero
    
    @State private var inLeftTrigger = false
    @State private var inRightTrigger = false
    @State private var inTrigger = false
    
    @State private var flipped = false
    @State private var hasBeenFlipped = false
    @State private var flipDirection = false
    @State private var yRotationAngle: Double = 0
    
    @State private var shakeAmount: CGFloat = 0
    
     var cardOrigin = CGPoint(
        x: UIScreen.main.bounds.midX,
        y: UIScreen.main.bounds.midY - 100
    )
    
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
                CardView(
                    isVisible: $cardVisibility,
                    dragAmount: $dragAmount,
                    flipped: $flipped,
                    flipDirection: $flipDirection,
                    isAnswered: $isAnswered,
                    isCorrect: $isCorrect,
                    frontText: deck.cardList[currentCardIndex].frontText,
                    backText: deck.cardList[currentCardIndex].backText,
                    onTapGesture: flip,
//                    onAppear: nil,
                    onDissaper: reset
                )
                .modifier(ShakeEffect(animatableData: shakeAmount))
                .position(cardPosition)
                .gesture(dragGesture)
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
                        action: flip
                    )
                }
            }
        }
    }
    
    func initialize(){
        cardPosition = cardOrigin
        cardVisibility = true
    }
    
    func calculateProgress() -> Double {
        return Double(currentCardIndex) / Double(deck.cardList.count)
    }
    
    private func flip(){
        withAnimation {
            flipped.toggle()
            yRotationAngle = 0
        }
        
        hasBeenFlipped = true
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                dragAmount = CGSize(width: gesture.translation.width, height: 0)
                updateTriggers()
            }
            .onEnded { _ in
                if(flipped){
                    cardPosition.x += dragAmount.width
                }
                dragAmount = .zero
                checkDropTrigger()
            }
    }
    
    
    
    
    
    private func reset() {
        // Reset the state as needed
        cardPosition = cardOrigin
        
        flipped = false
        hasBeenFlipped = false
        updateTriggers()
        yRotationAngle = 0
        cardVisibility = true
    }
    
    private func updateTriggers() {
        let cardCenter = CGPoint(x: cardPosition.x + dragAmount.width, y: cardPosition.y + dragAmount.height)
        inLeftTrigger = cardCenter.x < 100
        inRightTrigger = cardCenter.x > UIScreen.main.bounds.width - 100
        inTrigger = inLeftTrigger || inRightTrigger
        isAnswered = flipped && inTrigger
        isCorrect = isAnswered && inRightTrigger
    }
    
    private func checkDropTrigger() {
        if flipped{
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
                flip()
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


struct CardView: View {
    
    @Binding var isVisible: Bool
    
    @Binding var dragAmount: CGSize
    @Binding var flipped: Bool
    @Binding var flipDirection: Bool
    
    @Binding var isAnswered: Bool
    @Binding var isCorrect: Bool
    
    @State var cardScale: CGFloat = 0
    @State var flip: CGFloat = 0
    
    let frontText: String
    let backText: String
    
    let onTapGesture: () -> Void
//    let onAppear: () -> Void
    let onDissaper: () -> Void
    
    var frontContent: some View {
        Text(frontText)
            .foregroundColor(Color.black)
            .frame(width: 200, height: 300)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 10)
    }
    
    var backContent: some View {
        Text(backText)
            .foregroundColor(Color.black)
            .frame(width: 200, height: 300)
            .background(isAnswered ? isCorrect ? Color.green : Color.red : Color.yellow)
            .cornerRadius(10)
            .shadow(radius: 10)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0)) // Counter-rotate the back text
    }

    var body: some View {
        VStack {
            if flipped {
                backContent
            } else {
                frontContent
            }
        }
        .rotation3DEffect(.degrees(flipped ? flipDirection ? -180 : 180 : flip), axis: (x: 0, y: 1, z: 0))
        .rotationEffect(.degrees(flipped ? calculateZRotation(from: dragAmount.width) : 0))
        .scaleEffect(cardScale)
        .onTapGesture (perform: onTapGesture)
        .offset( x: flipped ? dragAmount.width : 0, y: 0)
        .onChange(of: isVisible) { if isVisible { show() } else { hide() }}
        .onChange(of: dragAmount) { old, new in onDragChanged(from: old, to: new)}
        .onChange(of: flipped){flip = 0}
    }
    
    private func calculateYRotation(from dragWidth: CGFloat) -> Double {
        let maxRotation = 180.0  // Maximum rotation angle in degrees
        let screenWidth = UIScreen.main.bounds.width
        let rotation = (Double(dragWidth) / Double(screenWidth)) * maxRotation
        return min(maxRotation, max(-maxRotation, rotation))
    }
    
    
    private func calculateZRotation(from dragWidth: CGFloat) -> Double {
        let maxRotation = 15.0
        let screenWidth = UIScreen.main.bounds.width
        let rotation = (Double(dragWidth) / Double(screenWidth)) * maxRotation
        return min(maxRotation, max(-maxRotation, rotation))
    }
    
    private func show() {
        
        let animationDuration = 0.3
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
            cardScale = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
//            onAppear()
        }
    }
    
    private func hide() {
        
        let animationDuration = 0.3
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
            cardScale = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            onDissaper()
        }
    }
    
    private func onDragChanged(from:CGSize, to:CGSize) {
        print("---")
        print(from)
        print(dragAmount)
        
        if(from.width != 0 && to.width == 0){
            print("-HERE")
        }
        else{
            
            if(flipped){
                
            }
            else{
                flip = calculateYRotation(from: dragAmount.width)
            }
        }
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
            color: Color.black
        )
        
        dummyDeckData.cardList = [
            CardData(frontText: "Front", backText: "Back"),
            CardData(frontText: "F", backText: "B")
        ]
        
        return NavigationView {FlashCardsView(deck: .constant(dummyDeckData))}
    }
}
