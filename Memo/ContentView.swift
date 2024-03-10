//
//  ContentView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/01/25.
//

import SwiftUI

struct ContentView: View {
    @State private var flipped = false
    @State private var hasBeenFlipped = false
    @State private var dragAmount = CGSize.zero
    @State private var cardPosition = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
    @State private var inLeftTrigger = false
    @State private var inRightTrigger = false
    @State private var inTrigger = false
    @State private var flipDirection = false
    @State private var isCorrect = false
    @State private var isAnswered = false
    @State private var zRotationAngle: Double = 0
    @State private var yRotationAngle: Double = 0
    @State private var cardScale: CGFloat = 0
    @State private var shakeAmount: CGFloat = 0
    @State private var flagMarked = false;



    var body: some View {
        ZStack {
            
            // Left Trigger
            TriggerView()
                .frame(width: 100, height: UIScreen.main.bounds.height)
                .position(x: 50, y: UIScreen.main.bounds.midY)

            // Right Trigger
            TriggerView()
                .frame(width: 100, height: UIScreen.main.bounds.height)
                .position(x: UIScreen.main.bounds.width - 50, y: UIScreen.main.bounds.midY)

            // Draggable Card
            CardView(
                flipped: $flipped,
                isAnswered: $isAnswered,
                isCorrect: $isCorrect,
                flipDirection: $flipDirection,
                flipAmount: $yRotationAngle,
                onTapGesture: flip
            )
            .modifier(ShakeEffect(animatableData: shakeAmount))
            .offset( x: flipped ? dragAmount.width : 0, y: 0)
            .rotationEffect(.degrees(zRotationAngle))
            .scaleEffect(cardScale)
            .position(cardPosition)
            .gesture(flipGesture)
            .onAppear {
                appearWithPop()
            }
            
//            CircleButtonView(
//                iconName: "flag.fill",
//                buttonColor: flagMarked ? Color.indigo: Color.accentColor,
//                isEnabled: .constant(true),
//                action: {
//                    markFlagged()
//                }
//            )
            
            VStack {
                
                Spacer()

                HStack(spacing: 20) {
                    
                    
                    // Skip
                    CircleButtonView(
                        iconName: "forward.fill",
                        buttonColor: Color.accentColor,
                        isEnabled: .constant(true),
                        action: {
                            skip()
                        }
                    )
                    

                    // Mark as Wrong
                    CircleButtonView(
                        iconName: "xmark",
                        buttonColor: Color.red,
                        isEnabled: $hasBeenFlipped,
                        action: {
                            markIncorrect()
                        }
                    )

                    // Mark as Correct
                    CircleButtonView(
                        iconName: "checkmark",
                        buttonColor: Color.green,
                        isEnabled: $hasBeenFlipped,
                        action: {
                            markCorrect()
                        }
                    )
                    
                    // Flip
                    CircleButtonView(
                        iconName: "arrow.2.squarepath",
                        buttonColor: Color.accentColor,
                        isEnabled: .constant(true),
                        action: {
                            flip()
                        }
                    )
                }
                .padding(.bottom, 20) // Add some padding at the bottom
            }
        }
    }
    
    private func flip(){
        withAnimation {
            flipped.toggle()
            yRotationAngle = 0
        }
        
        hasBeenFlipped = true
    }
    
    var flipGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                dragAmount = CGSize(width: gesture.translation.width, height: 0)
                updateTriggers()
                if(flipped){
                    zRotationAngle = calculateZRotation(from: dragAmount.width)
                }
                else{
                    yRotationAngle = calculateYRotation(from: dragAmount.width)
                }
            }
            .onEnded { _ in
                if(flipped){
                    cardPosition.x += dragAmount.width
                }
                else{
                    
                }
                dragAmount = .zero
                checkDropTrigger()
            }
    }
    
    private func calculateZRotation(from dragWidth: CGFloat) -> Double {
        let maxRotation = 15.0  // Maximum rotation angle in degrees
        let screenWidth = UIScreen.main.bounds.width
        let rotation = (Double(dragWidth) / Double(screenWidth)) * maxRotation
        return min(maxRotation, max(-maxRotation, rotation))
    }
    
    private func calculateYRotation(from dragWidth: CGFloat) -> Double {
        let maxRotation = 180.0  // Maximum rotation angle in degrees
        let screenWidth = UIScreen.main.bounds.width
        let rotation = (Double(dragWidth) / Double(screenWidth)) * maxRotation
        return min(maxRotation, max(-maxRotation, rotation))
    }
    
        
    private func appearWithPop() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
            cardScale = 1.0
        }
    }

    private func disappearWithPop() {
        let animationDuration = 0.3
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
            cardScale = 0
        }

        // Schedule the reset to be called after the animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) { // Delay includes animation delay and duration
            reset()
        }
    }

    private func reset() {
        // Reset the state as needed
        cardPosition = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        flipped = false
        hasBeenFlipped = false
        updateTriggers()
        zRotationAngle = 0
        yRotationAngle = 0
        appearWithPop()
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
        disappearWithPop()
    }
    
    private func markIncorrect(){
        withAnimation(.linear(duration: 0.2)) {
            self.shakeAmount += 10
        }
        
        disappearWithPop()
    }
    
    private func skip(){
        withAnimation(.linear(duration: 0.5)) {
            self.shakeAmount += 1
        }
        
        disappearWithPop()
    }
    
    private func markFlagged(){
        withAnimation(.linear(duration: 0.5)) {
            flagMarked.toggle()
        }
    }
    
}

struct TriggerView: View {
    var body: some View {
        Rectangle().opacity(0) // Adjust for visibility
    }
}


struct CardView: View {
    
    @Binding var flipped: Bool
    @Binding var isAnswered: Bool
    @Binding var isCorrect: Bool
    @Binding var flipDirection: Bool
    @Binding var flipAmount: Double
    let onTapGesture: () -> Void
    
    var frontContent: some View {
        Text("Front")
            .foregroundColor(Color.black)
            .frame(width: 200, height: 300)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 10)
    }
    
    var backContent: some View {
        Text("Back")
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
        .rotation3DEffect(.degrees(flipped ? flipDirection ? -180 : 180 : flipAmount), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            onTapGesture()
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
        .padding()
        .background(isEnabled ? buttonColor : Color.gray) // Use the color parameter here
        .clipShape(Circle())
        .shadow(radius: 10)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
