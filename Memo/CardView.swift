//
//  CardView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/04/02.
//

import SwiftUI

/// Which gestures a card currently responds to.
///
/// An `OptionSet` rather than an array: this is a set of independent flags, and
/// modelling it as an array meant every read and write went through
/// `contains` / `append` / `removeAll`, with nothing preventing duplicates.
struct CardInteractivity: OptionSet {

    let rawValue: Int

    static let flipTap        = CardInteractivity(rawValue: 1 << 0)
    static let flipDrag       = CardInteractivity(rawValue: 1 << 1)
    static let horizontalDrag = CardInteractivity(rawValue: 1 << 2)
}

struct CardView<FrontContent: View, BackContent: View>: View {

    @Binding var flip: Bool

    let frontView: FrontContent
    let backView: BackContent

    @Binding var interactivity: CardInteractivity

    @Binding var offset: CGSize
    @Binding var scale: CGFloat

    @State var flipAngle: CGFloat = 0

    @State private var rotationAngle: CGFloat = 0
    @State private var lastDrag: CGSize = .zero
    @State private var startDraggedAngle: CGFloat = 0

    let onFlip: (_ isRevealed: Bool) -> Void
    let onRelease: (_ isRevealed: Bool) -> Void

    /// Horizontal distance treated as a "full" drag when converting a gesture
    /// into rotation.
    ///
    /// A fixed reference rather than the live screen width: this only sets
    /// gesture sensitivity, so it does not need to track the device, and
    /// reading `UIScreen.main.bounds` for it was both deprecated and wrong
    /// whenever the app was not full-screen.
    var referenceWidth: CGFloat = 393

    // Computed rather than stored: this type is generic, and generic types
    // cannot hold static stored properties.
    private static var cardSize: CGSize { CGSize(width: 200, height: 300) }

    var body: some View {

        ZStack {
            if isRevealed {
                frontView
            } else {
                backView.rotation3DEffect(
                    .degrees(180),
                    axis: (x: 0, y: 1, z: 0)
                )
            }
        }
        .background(.white)
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .clipShape(.rect(cornerRadius: 10))
        .shadow(radius: 10)
        .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0))
        .rotationEffect(.degrees(rotationAngle))
        .scaleEffect(scale)
        .offset(offset)
        .gesture(dragGesture)
        .gesture(tapGesture)
        .onChange(of: flip) { _, newValue in
            if newValue { doFlip() }
        }
        .onAppear { if flip { doFlip() } }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {

        DragGesture()
            .onChanged { gesture in

                if lastDrag == .zero {
                    startDraggedAngle = flipAngle
                }

                let currentDrag = gesture.translation
                let delta = CGSize(
                    width: currentDrag.width - lastDrag.width,
                    height: currentDrag.height - lastDrag.height
                )

                if interactivity.contains(.flipDrag) {
                    flipAngle += map(value: delta.width, toMax: 200)

                    if flipAngle > 360 {
                        flipAngle -= 360
                    } else if flipAngle < -360 {
                        flipAngle += 360
                    }
                }

                if interactivity.contains(.horizontalDrag) {
                    rotationAngle = map(value: currentDrag.width, toMax: 15)
                    offset.width += delta.width
                }

                lastDrag = currentDrag
            }
            .onEnded { _ in

                lastDrag = .zero

                if interactivity.contains(.flipDrag) {
                    withAnimation { flipAngle = settledAngle(from: flipAngle) }
                }

                if interactivity.contains(.horizontalDrag) {
                    withAnimation { rotationAngle = 0 }
                }

                if abs(startDraggedAngle - flipAngle) > 90 {
                    onFlip(isRevealed)
                }

                onRelease(isRevealed)
            }
    }

    private var tapGesture: some Gesture {
        TapGesture().onEnded { _ in
            if interactivity.contains(.flipTap) { doFlip() }
        }
    }

    // MARK: - Geometry

    /// Scales a drag distance into a rotation, clamped to ±`toMax`.
    private func map(value: CGFloat, toMax: CGFloat) -> CGFloat {
        let scaled = (value / referenceWidth) * toMax
        return min(toMax, max(-toMax, scaled))
    }

    /// Snaps a free-dragged angle to the nearest resting face.
    private func settledAngle(from angle: CGFloat) -> CGFloat {
        switch angle {
        case 270..<360:   360
        case 90..<270:    180
        case -90..<90:    0
        case -270 ..< -90: -180
        default:          -360
        }
    }

    /// Whether the front face is the one currently pointing at the viewer.
    var isRevealed: Bool {
        (flipAngle > -90 && flipAngle < 90)
            || flipAngle > 270
            || flipAngle < -270
    }

    func doFlip() {
        let revealed = isRevealed

        withAnimation { flipAngle = revealed ? 180 : 0 }

        onFlip(!revealed)
        flip = false
    }
}

#Preview {
    @Previewable @State var interactivity: CardInteractivity = [.flipTap, .horizontalDrag]

    CardView(
        flip: .constant(false),
        frontView: Text("Front")
            .frame(width: 200, height: 300)
            .background(Color.teal),
        backView: Text("Back")
            .frame(width: 200, height: 300)
            .background(Color.purple),
        interactivity: $interactivity,
        offset: .constant(.zero),
        scale: .constant(1),
        onFlip: { _ in },
        onRelease: { _ in }
    )
}
