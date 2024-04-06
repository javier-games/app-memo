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
    
    @State var lastDrag: CGSize = .zero
    
    @State var cardScale: CGFloat = 0
    @State var flipAngle: CGFloat = 0
    @State var rotationAngle: CGFloat = 0
    @State var flipAngleLast : CGFloat = 0

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
                        backView.rotation3DEffect(
                            .degrees(180.0),
                            axis: (x: 0.0, y: 1.0, z: 0.0)
                        )
                    }
                }
            }
            .frame(width: 200, height: 300)
            .background(.white)
            .cornerRadius(10)
            .shadow(radius: 10)
            .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0))
            .rotationEffect(.degrees(rotationAngle))
            .onAppear(){flipAngle = isReveled ? 0 : 180}
            
            ZStack{
                // TODO: Find a better way to avoid 3D rotation problems on drag.
                Color.black.opacity(0.00000000001)
            }
            .gesture(dragGesture)
            .gesture(tapGesture)
        }
    }
    
    var dragGesture: some Gesture {
        
        DragGesture()
            .onChanged { gesture in
                
                let currentDrag = gesture.translation;
                let delta = CGSizeMake(
                    currentDrag.width - lastDrag.width,
                    currentDrag.height - lastDrag.height
                )
                
                if interactivity.contains(.flipDrag){
                
                    
                    let increment = map(
                        value: delta.width,
                        fromMax: UIScreen.main.bounds.width,
                        toMax: 180.0
                    )
                    
                    flipAngle += increment
                    if flipAngle > 360 {
                        flipAngle -= 360
                    } else if flipAngle < -360 {
                        flipAngle += 360
                    }
                    
                    isReveled = (flipAngle > -90 && flipAngle < 90)
                        || flipAngle > 270
                        || flipAngle < -270
                    print(flipAngle)
                }
                
                if interactivity.contains(.angularDrag){
                    
                }
                
                lastDrag = currentDrag
            }
            .onEnded { _ in
                
                lastDrag = .zero
                
                if interactivity.contains(.flipDrag){
                    
                }
                
                if interactivity.contains(.angularDrag){
                    
                }
            }
    }
    
    var tapGesture: some Gesture{
        TapGesture().onEnded { _ in
            
            if interactivity.contains(.flipTap){
                
            }
        }
    }
    
    private func flipCard(){
        
    }
    
    private func map(value : Double, fromMax: Double, toMax: Double) -> Double {
        let newVal = (value / fromMax) * toMax
        return min(toMax, max(-toMax, newVal))
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
            isVisible: .constant(false),
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
