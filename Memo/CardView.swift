//
//  Test.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/04/02.
//

import Foundation
import SwiftUI

enum CardInteractivity {
    case flip, angularDrag
}

struct BackView: View {
    var body: some View {
        Text("frontText").rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }
}

struct FrontView: View {
    var body: some View {
        Text("backText")
    }
}

struct CardView<FrontContent,BackContent>: View
where FrontContent: View, BackContent:View {
    
    @Binding var isVisible: Bool
    @Binding var isReveled: Bool
    @Binding var flipDirection: Bool
    
    let frontView: FrontContent
    let backView: BackContent
    
    let interactivity: CardInteractivity
    let dragAmount: CGSize
    
    @State var cardScale: CGFloat = 0
    @State var flip: CGFloat = 0

    let onFlip: () -> Void
    let onAppear:() -> Void
    let onDissaper: () -> Void
    
    var body: some View {
        VStack {
            ZStack{
                if isReveled {
                    frontView
                } else {
                    backView
                }
            }
            .frame(width: 200, height: 300)
            .background(.white)
            .cornerRadius(10)
            .shadow(radius: 10)
        }
        .rotation3DEffect(.degrees(isReveled ? flipDirection ? -180 : 180 : flip), axis: (x: 0, y: 1, z: 0))
        .rotationEffect(.degrees(isReveled ? calculateZRotation(from: dragAmount.width) : 0))
        .scaleEffect(cardScale)
        .onTapGesture (perform: flipCard)
        .offset( x: isReveled ? dragAmount.width : 0, y: 0)
        .onChange(of: isVisible) { if isVisible { show() } else { hide() }}
        .onChange(of: dragAmount) { old, new in onDragChanged(from: old, to: new)}
        .onChange(of: isReveled){flip = 0}
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
        withAnimation {
            isReveled.toggle()
        }
        
        onFlip()
    }
    
    private func onDragChanged(from:CGSize, to:CGSize) {
        if(from.width != 0 && to.width == 0){
            
        }
        else{
            if(isReveled){
                
            }
            else{
                flip = calculateYRotation(from: dragAmount.width)
            }
        }
    }
}


//struct MyView_Previews: PreviewProvider {
//    static var previews: some View {
//        return  CardView (content: MySecondView())
//    }
//}
