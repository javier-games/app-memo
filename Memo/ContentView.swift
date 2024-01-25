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
    @State private var rotationAngle: Double = 0  // New state for rotation angle
    @State private var cardScale: CGFloat = 0  // For pop animation

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
            CardView(flipped: $flipped, inTrigger: $inTrigger, inLeftTrigger: $inLeftTrigger)
                            .offset(x: dragAmount.width, y: 0)
                            .rotationEffect(.degrees(rotationAngle))
                            .scaleEffect(cardScale)
                            .position(cardPosition)
                            .gesture(flipped ? dragGesture : nil)
                            .onAppear {
                                appearWithPop()
                            }
                            
        }
    }

    var dragGesture: some Gesture {
            DragGesture()
                .onChanged { gesture in
                    dragAmount = CGSize(width: gesture.translation.width, height: 0)
                    rotationAngle = calculateRotation(from: dragAmount.width)  // Calculate rotation
                    updateTriggers()
                }
                .onEnded { _ in
                    cardPosition.x += dragAmount.width
                    dragAmount = .zero  // Reset rotation
                    checkDropTrigger()
                }
        }

    private func calculateRotation(from dragWidth: CGFloat) -> Double {
            let maxRotation = 15.0  // Maximum rotation angle in degrees
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
        rotationAngle = 0
        appearWithPop()
    }
    

    private func updateTriggers() {
        let cardCenter = CGPoint(x: cardPosition.x + dragAmount.width, y: cardPosition.y + dragAmount.height)
        inLeftTrigger = cardCenter.x < 100
        inRightTrigger = cardCenter.x > UIScreen.main.bounds.width - 100
        inTrigger = inLeftTrigger || inRightTrigger
    }

    private func checkDropTrigger() {
        
        if inLeftTrigger {
            print("Card dropped in left trigger")
            disappearWithPop()
            // Handle left trigger event
        } else if inRightTrigger {
           disappearWithPop()
            print("Card dropped in right trigger")
            // Handle right trigger event
        } else {
            // Return card to center if not in any trigger
            withAnimation {
                cardPosition = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
                
                rotationAngle = 0
            }
        }
        inLeftTrigger = false
        inRightTrigger = false
        inTrigger = false
    }
}

struct TriggerView: View {
    var body: some View {
        Rectangle().opacity(0) // Adjust for visibility
    }
}


struct CardView: View {
    @Binding var flipped: Bool
    @Binding var inTrigger: Bool
    @Binding var inLeftTrigger: Bool
    var frontContent: some View {
        Text("Front")
            .frame(width: 200, height: 300)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 10)
    }
    var backContent: some View {
        Text("Back")
            .frame(width: 200, height: 300)
            .background(inTrigger ? inLeftTrigger ? Color.red : Color.green : Color.yellow)
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
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            withAnimation {
                flipped.toggle()
            }
        }
    }
}

#Preview {
    ContentView()
}
