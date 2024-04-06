//
//  Test.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/04/02.
//

import Foundation
import SwiftUI

enum CardInteractivity {
    case flipTap, flipDrag, angularDrag
}

struct CardView<FrontContent,BackContent>: View
where FrontContent: View, BackContent:View {
    
    @Binding var isVisible: Bool
    @State var isReveled: Bool
    
    let frontView: FrontContent
    let backView: BackContent
    
    @State var interactivity: [CardInteractivity]
    @State var dragAmount: CGSize = CGSize.zero
    
    @State var cardScale: CGFloat = 0
    @State var flipAngle: CGFloat = 0
    @State var rotationAngle: CGFloat = 0

    let onFlip: () -> Void
    let onAppear:() -> Void
    let onDissaper: () -> Void
    
    var body: some View {
        ZStack {
            
            ZStack{
                ZStack{
                    if isReveled {
                        frontView
                    } else {
                        backView
                    }
                }
                .rotation3DEffect(
                    .degrees(flipAngle < -90 || flipAngle > 90 ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
            }
            .frame(width: 200, height: 300)
            .background(.white)
            .cornerRadius(10)
            .shadow(radius: 10)
            .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0))
            .rotationEffect(.degrees(rotationAngle))
            
            ZStack{
                // TODO: Find a better way to avoid 3D rotation problems on drag.
                Color.black.opacity(0.00000000001)
            }
            .gesture(dragGesture)
            .gesture(tapGesture)
        }
        
//        .scaleEffect(cardScale)
//        .onChange(of: isVisible) { if isVisible { show() } else { hide() }}
//        .onChange(of: dragAmount) { old, new in onDragChanged(from: old, to: new)}
//        .onChange(of: isReveled){flip = 180}
        
    }
    
    var dragGesture: some Gesture {
        
        DragGesture()
            .onChanged { gesture in
                dragAmount = CGSize(width: gesture.translation.width, height: 0)
                
                if interactivity.contains(.flipDrag){
                    flipAngle = map(
                        value: Double(dragAmount.width),
                        fromMax: Double(UIScreen.main.bounds.width),
                        toMax:180.0
                    )
                }
                
                if interactivity.contains(.angularDrag){
                    rotationAngle = map(
                        value: Double(dragAmount.width),
                        fromMax: Double(UIScreen.main.bounds.width),
                        toMax:15.0
                    )
                }
            }
            .onEnded { _ in
                dragAmount = CGSize.zero
                
                if interactivity.contains(.flipDrag){
                    if (flipAngle < -90 || flipAngle > 90) { flipCard() }
                    else { withAnimation { flipAngle = 0 } }
                }
                
                if interactivity.contains(.angularDrag){
                    withAnimation{
                        rotationAngle = 0
                    }
                }
            }
    }
    
    var tapGesture: some Gesture{
        TapGesture().onEnded { _ in
            
            if interactivity.contains(.flipTap){
                flipAngle = 0
                flipCard()
            }
        }
    }
    
    private func map(value : Double, fromMax: Double, toMax: Double) -> Double {
        let newVal = (value / fromMax) * toMax
        return min(toMax, max(-toMax, newVal))
    }
    
    private func show() {
        
        let animationDuration = 0.3
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
            cardScale = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            onAppear()
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
    
    private func flipCard(){
        isReveled = !isReveled
        withAnimation {
            flipAngle = flipAngle > 0 ? 180 : -180
        }
        onFlip()
    }
    
}

struct MyView_Previews: PreviewProvider {
    
    @State static var isRevealed = false
    @State static var interactivity: [CardInteractivity] = [.flipTap, .flipDrag]
    
    static var backView : some View {
        Text("backText")
            .frame(width: 200, height: 300)
            .background(Color.purple)
    }
    
    static var frontView : some View {
        Text("frontText")
            .frame(width: 200, height: 300)
            .background(Color.teal)
    }
    
    static var previews: some View {
        CardView (
            isVisible: .constant(true),
            isReveled: isRevealed,
            frontView: frontView,
            backView: backView,
            interactivity: interactivity,
            onFlip: { print(isRevealed) },
            onAppear: {},
            onDissaper: {}
        )
    }
}
