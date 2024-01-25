//
//  ContentView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/01/25.
//

import SwiftUI

import SwiftUI

struct ContentView: View {
    @State private var flipped = false
    @State private var dragAmount = CGSize.zero
    @State private var cardPosition = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
    @State private var inLeftTrigger = false
    @State private var inRightTrigger = false

    var body: some View {
        ZStack {
            // Left Trigger
            TriggerView(inTrigger: $inLeftTrigger)
                .frame(width: 100, height: UIScreen.main.bounds.height)
                .position(x: 50, y: UIScreen.main.bounds.midY)

            // Right Trigger
            TriggerView(inTrigger: $inRightTrigger)
                .frame(width: 100, height: UIScreen.main.bounds.height)
                .position(x: UIScreen.main.bounds.width - 50, y: UIScreen.main.bounds.midY)

            // Draggable Card
            CardView(flipped: $flipped)
                .offset(x: dragAmount.width, y: dragAmount.height)
                .position(cardPosition)
                .gesture(flipped ? dragGesture : nil)
        }
    }

    var dragGesture: some Gesture {
            DragGesture()
                .onChanged { gesture in
                    dragAmount = CGSize(width: gesture.translation.width, height: 0) // Update only the width
                    updateTriggers()
                }
                .onEnded { _ in
                    cardPosition.x += dragAmount.width
                    // Keep the vertical position unchanged
                    dragAmount = .zero
                    checkDropTrigger()
                }
        }


    private func updateTriggers() {
        let cardCenter = CGPoint(x: cardPosition.x + dragAmount.width, y: cardPosition.y + dragAmount.height)
        inLeftTrigger = cardCenter.x < 100
        inRightTrigger = cardCenter.x > UIScreen.main.bounds.width - 100
    }

    private func checkDropTrigger() {
        if inLeftTrigger {
            print("Card dropped in left trigger")
            // Handle left trigger event
        } else if inRightTrigger {
            print("Card dropped in right trigger")
            // Handle right trigger event
        } else {
            // Return card to center if not in any trigger
            withAnimation {
                cardPosition = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
            }
        }
        inLeftTrigger = false
        inRightTrigger = false
    }
}

struct TriggerView: View {
    @Binding var inTrigger: Bool
    var body: some View {
        Rectangle()
            .opacity(inTrigger ? 0.5 : 0.1) // Adjust for visibility
    }
}



struct CardView: View {
    @Binding var flipped: Bool
    var frontContent: some View {
        Text("Front")
            .frame(width: 200, height: 300)
            .background(Color.blue)
            .cornerRadius(10)
            .shadow(radius: 10)
    }
    var backContent: some View {
        Text("Back")
            .frame(width: 200, height: 300)
            .background(Color.red)
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
