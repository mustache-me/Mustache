//
//  BadgeStyle.swift
//  Mustache
//
//  Numbered App Switcher
//

import SwiftUI

/// Defines the visual appearance of numbered badges
struct BadgeStyle: Codable, Equatable {
    var backgroundColor: CodableColor
    var textColor: CodableColor
    var fontSize: CGFloat
    var padding: CGFloat
    var cornerRadius: CGFloat // Kept for backward compatibility with rectangular badges
    var borderWidth: CGFloat
    var opacity: Double

    init(
        backgroundColor: Color = Color.black.opacity(0.75),
        textColor: Color = .white,
        fontSize: CGFloat = 16,
        padding: CGFloat = 5,
        cornerRadius: CGFloat = 8,
        borderWidth: CGFloat = 2,
        opacity: Double = 1.0
    ) {
        self.backgroundColor = CodableColor(color: backgroundColor)
        self.textColor = CodableColor(color: textColor)
        self.fontSize = fontSize
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.opacity = opacity
    }
}

/// Helper struct to make Color Codable
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(color: Color) {
        // Convert SwiftUI Color to components
        // Note: This is a simplified version; in production, you'd use NSColor/UIColor
        let nsColor = NSColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Double(r)
        green = Double(g)
        blue = Double(b)
        alpha = Double(a)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
