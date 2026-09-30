//
//  Color+Memo.swift
//  Memo
//
//  Bridges between the model layer's plain colour components and SwiftUI.
//  This is deliberately the only place that knows about both.
//

import SwiftUI

extension Deck {

    /// The deck's colour as SwiftUI sees it.
    var color: Color {
        get {
            Color(
                .sRGB,
                red: colorRed,
                green: colorGreen,
                blue: colorBlue,
                opacity: colorAlpha
            )
        }
        set { setColor(newValue) }
    }

    func setColor(_ color: Color) {
        let components = color.rgbaComponents
        colorRed = components.red
        colorGreen = components.green
        colorBlue = components.blue
        colorAlpha = components.alpha
    }

    /// A foreground colour that stays legible on top of ``color``.
    ///
    /// Chosen by relative luminance rather than by inverting each channel: a
    /// naive `1 - x` inversion maps mid grey onto itself, which rendered the
    /// card text invisible on any desaturated deck colour.
    var contrastingTextColor: Color {
        let luminance = 0.2126 * colorRed + 0.7152 * colorGreen + 0.0722 * colorBlue
        return luminance > 0.55 ? .black : .white
    }
}

extension Color {

    /// Decomposes the colour into sRGB components.
    ///
    /// `UIColor.getRed(_:green:blue:alpha:)` handles greyscale and wide-gamut
    /// colour spaces, unlike reading `cgColor.components` directly — that array
    /// holds only two entries for greyscale colours, so indexing it positionally
    /// is an unchecked assumption about the source colour space.
    var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        let uiColor = UIColor(self)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (
                Double(red).clampedToUnitRange,
                Double(green).clampedToUnitRange,
                Double(blue).clampedToUnitRange,
                Double(alpha).clampedToUnitRange
            )
        }

        var white: CGFloat = 0
        if uiColor.getWhite(&white, alpha: &alpha) {
            let value = Double(white).clampedToUnitRange
            return (value, value, value, Double(alpha).clampedToUnitRange)
        }

        return (0, 0, 0, 1)
    }
}

private extension Double {
    /// Wide-gamut colours can report components outside 0...1 in extended sRGB.
    var clampedToUnitRange: Double { Swift.min(1, Swift.max(0, self)) }
}
