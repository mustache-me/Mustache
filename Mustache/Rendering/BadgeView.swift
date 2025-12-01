//
//  BadgeView.swift
//  Mustache
//
//  Numbered App Switcher - Badge SwiftUI View
//

import SwiftUI

/// SwiftUI view for displaying a numbered badge (rectangular with rounded corners)
struct BadgeView: View {
    let key: String
    let style: BadgeStyle
    let isHighlighted: Bool

    var body: some View {
        Text(key)
            .font(.system(size: style.fontSize, weight: .bold, design: .rounded))
            .foregroundColor(isHighlighted ? Color.yellow : style.textColor.color)
            .padding(style.padding)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(isHighlighted ? Color.blue.opacity(0.9) : style.backgroundColor.color)
            )
            .opacity(style.opacity)
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

/// SwiftUI view for displaying a circular numbered badge (used in app switcher)
struct CircularBadgeView: View {
    let key: String
    let style: BadgeStyle
    let isHighlighted: Bool
    let showBorder: Bool

    init(key: String, style: BadgeStyle, isHighlighted: Bool = false, showBorder: Bool = true) {
        self.key = key
        self.style = style
        self.isHighlighted = isHighlighted
        self.showBorder = showBorder
    }

    var body: some View {
        let badgeColor = isHighlighted ? Color.blue : style.backgroundColor.color
        let textColor = isHighlighted ? Color.white : style.textColor.color
        let badgeSize = style.fontSize + (style.padding * 2)

        Text(key)
            .font(.system(size: style.fontSize, weight: .bold, design: .rounded))
            .foregroundColor(textColor)
            .frame(width: badgeSize, height: badgeSize)
            .background(
                Circle()
                    .fill(badgeColor)
                    .overlay(
                        showBorder ? Circle().stroke(Color.white, lineWidth: style.borderWidth) : nil
                    )
            )
            .opacity(style.opacity)
            .shadow(color: Color.black.opacity(0.5), radius: 3, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        BadgeView(key: "1", style: BadgeStyle(), isHighlighted: false)
        BadgeView(key: "2", style: BadgeStyle(), isHighlighted: true)
        BadgeView(key: "a", style: BadgeStyle(), isHighlighted: false)

        Divider()

        CircularBadgeView(key: "1", style: BadgeStyle(), isHighlighted: false)
        CircularBadgeView(key: "2", style: BadgeStyle(), isHighlighted: true)
        CircularBadgeView(key: "a", style: BadgeStyle(), isHighlighted: false)
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
