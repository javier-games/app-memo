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
    
    @State var isVisible: Bool
    
    let frontView: FrontContent
    let backView: BackContent
    
    @State var interactivity: [CardInteractivity]
    
    @State var flipAngle: CGFloat = 0
    @State var rotationAngle: CGFloat = 0
    @State var lastDrag: CGSize = .zero

    let onFlip: (_ isReveled : Bool) -> Void
    let onAppear:() -> Void
    let onDissaper: () -> Void
    
    var body: some View {
        ZStack {
            
            ZStack{
                ZStack{
                    if isReveled() {
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
            
            ZStack{
                // TODO: Find a better way to avoid 3D rotation problems on drag.
                Color.black.opacity(0.00000000001)
            }
            .frame(width: 200, height: 300)
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
                }
                
                if interactivity.contains(.angularDrag){
                    rotationAngle = map(
                        value: Double(currentDrag.width),
                        fromMax: Double(UIScreen.main.bounds.width),
                        toMax:15.0
                    )
                }
                
                lastDrag = currentDrag
            }
        
            .onEnded { gesture in
                
                lastDrag = .zero
                
                let angle = map(
                    value: gesture.translation.width,
                    fromMax: UIScreen.main.bounds.width,
                    toMax: 180
                )
                
                if abs(angle) > 90 {
                    onFlip(isReveled())
                }
                
                if interactivity.contains(.flipDrag){
                    
                    withAnimation {
                        if flipAngle > 270 && flipAngle < 360 {
                            flipAngle = 360
                        }
                        else if flipAngle > 90 && flipAngle < 270 {
                            flipAngle = 180
                        }
                        else if flipAngle > -90 && flipAngle < 90 {
                            flipAngle = 0
                        }
                        else if flipAngle > -270 && flipAngle < -90{
                            flipAngle = -180
                        }
                        else {
                            flipAngle = -360
                        }
                    }
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
            
            let isReveled = isReveled()
            
            if interactivity.contains(.flipTap){
                withAnimation {
                    flipAngle = isReveled ? 180 : 0
                }
                
                onFlip(!isReveled)
            }
        }
    }
    
    private func map(value : Double, fromMax: Double, toMax: Double) -> Double {
        let newVal = (value / fromMax) * toMax
        return min(toMax, max(-toMax, newVal))
    }
    
    public func isReveled() -> Bool {
        return (flipAngle > -90 && flipAngle < 90)
        || flipAngle > 270
        || flipAngle < -270
    }
}

struct MyView_Previews: PreviewProvider {
    
    @State static var interactivity: [CardInteractivity] = [.flipTap, .angularDrag]
    
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
            isVisible: true,
            frontView: frontView,
            backView: backView,
            interactivity: interactivity,
            flipAngle: 180,
            onFlip: { isReveled in print(isReveled) },
            onAppear: {},
            onDissaper: {}
        )
    }
}
