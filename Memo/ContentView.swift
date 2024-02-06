//
//  ContentView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/01/25.
//

import SwiftUI

struct ContentView: View {
    @State private var flipped = false
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
            CardView(flipped: $flipped, isAnswered: $isAnswered, isCorrect: $isCorrect, flipDirection: $flipDirection, flipAmount: $yRotationAngle)
                .offset( x: flipped ? dragAmount.width : 0, y: 0)
                .rotationEffect(.degrees(zRotationAngle))
                .scaleEffect(cardScale)
                .position(cardPosition)
                .gesture(flipGesture)
                .onAppear {
                    appearWithPop()
                }
        }
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
                disappearWithPop()
            } else if inRightTrigger {
                disappearWithPop()
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
                    flipped.toggle()
                    yRotationAngle = 0
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
            withAnimation {
                flipped.toggle()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
