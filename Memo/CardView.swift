//
//  CardView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/04/02.
//

import Foundation
import SwiftUI

enum CardInteractivity {
    case flipTap, flipDrag, horizontalDrag
}

struct CardView<FrontContent,BackContent>: View
where FrontContent: View, BackContent:View {
    
    @Binding var flip: Bool
    
    let frontView: FrontContent
    let backView: BackContent
    
    @Binding var interactivity: [CardInteractivity]
    
    @Binding var offset: CGSize
    @Binding var scale: CGFloat
    
    @State var flipAngle: CGFloat = 0
    
    @State private var rotationAngle: CGFloat = 0
    @State private var lastDrag: CGSize = .zero
    @State private var startDraggedAngle: CGFloat = 0

    let onFlip: (_ isReveled : Bool) -> Void
    let onRelease: (_ isReveled : Bool) -> Void
    
    var body: some View {
        
        ZStack {
            if isReveled() {
                frontView
            } else {
                backView.rotation3DEffect(
                    .degrees(180.0),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
            }
        }
        .background(.white)
        .frame(width: 200, height: 300)
        .cornerRadius(10)
        .shadow(radius: 10)
        .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0))
        .rotationEffect(.degrees(rotationAngle))
        .scaleEffect(scale)
        .offset(offset)
        .gesture(dragGesture)
        .gesture(tapGesture)
        .onChange(of: flip){ if flip { doFlip() } }
        .onAppear(){ if flip { doFlip() } }
    }
    
    var dragGesture: some Gesture {
        
        DragGesture()
        
            .onChanged { gesture in
                
                if lastDrag == .zero {
                    startDraggedAngle = flipAngle
                }
                
                let currentDrag = gesture.translation;
                let delta = CGSizeMake(
                    currentDrag.width - lastDrag.width,
                    currentDrag.height - lastDrag.height
                )
                
                if interactivity.contains(.flipDrag){
                
                    
                    let increment = map(
                        value: delta.width,
                        fromMax: UIScreen.main.bounds.width,
                        toMax: 200.0
                    )
                    
                    flipAngle += increment
                    if flipAngle > 360 {
                        flipAngle -= 360
                    } else if flipAngle < -360 {
                        flipAngle += 360
                    }
                }
                
                if interactivity.contains(.horizontalDrag){
                    rotationAngle = map(
                        value: Double(currentDrag.width),
                        fromMax: Double(UIScreen.main.bounds.width),
                        toMax:15.0
                    )
                    
                    offset.width += delta.width                }
                
                lastDrag = currentDrag
            }
        
            .onEnded { gesture in
                
                lastDrag = .zero
                
                let angle = map(
                    value: gesture.translation.width,
                    fromMax: UIScreen.main.bounds.width,
                    toMax: 180
                )
                
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
                
                if interactivity.contains(.horizontalDrag){
                    withAnimation{
                        rotationAngle = 0
                    }
                }
                
                if abs(startDraggedAngle - flipAngle) > 90 {
                    onFlip(isReveled())
                }
                
                onRelease(isReveled())
            }
    }
    
    var tapGesture: some Gesture{
        TapGesture().onEnded { _ in
            
            if interactivity.contains(.flipTap){
                doFlip()
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
    
    public func doFlip(){
        let isReveled = isReveled()
        
            withAnimation {
                flipAngle = isReveled ? 180 : 0
            }
            
            onFlip(!isReveled)
        flip = false
    }
}

struct MyView_Previews: PreviewProvider {
    
    @State static var interactivity: [CardInteractivity] = [.flipTap, .horizontalDrag]
    
    static let cardOrigin = CGPoint(
        x: UIScreen.main.bounds.midX,
        y: UIScreen.main.bounds.midY - 100
    )
    
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
            flip: .constant(true),
            frontView: frontView,
            backView: backView,
            interactivity: $interactivity,
            offset: .constant(.zero),
            scale: .constant(1),
            onFlip: { isReveled in },
            onRelease: { isReveled in }
        )
    }
}

extension Color {
    func invertedColor() -> Color {
        guard let ciColor = UIColor(self).cgColor.components else {
            return self
        }
        
        let invertedRed = 1.0 - ciColor[0]
        let invertedGreen = 1.0 - ciColor[1]
        let invertedBlue = 1.0 - ciColor[2]
        
        return Color(red: Double(invertedRed), green: Double(invertedGreen), blue: Double(invertedBlue))
    }
}
