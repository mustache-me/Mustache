//
//  BadgeWindow.swift
//  Mustache
//
//  Numbered App Switcher - Badge Window
//

import AppKit
import SwiftUI

/// Borderless, transparent window for displaying badges
class BadgeWindow: NSWindow {
    init(badge: BadgeViewModel, style: BadgeStyle) {
        // Create window at badge position
        let windowRect = NSRect(
            x: badge.position.x,
            y: badge.position.y,
            width: 60, // Fixed size for badge
            height: 60
        )

        super.init(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window properties
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating // Float above all other windows
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        ignoresMouseEvents = true // Don't intercept mouse events

        // Create SwiftUI view
        let badgeView = BadgeView(
            key: "\(badge.number)",
            style: style,
            isHighlighted: badge.isHighlighted
        )

        // Wrap in hosting view
        let hostingView = NSHostingView(rootView: badgeView)
        hostingView.frame = contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]

        contentView = hostingView
    }

    /// Update badge position
    func updatePosition(_ position: CGPoint) {
        setFrameOrigin(position)
    }

    /// Update badge highlight state
    func updateHighlight(_ isHighlighted: Bool, style: BadgeStyle, number: Int) {
        let badgeView = BadgeView(
            key: "\(number)",
            style: style,
            isHighlighted: isHighlighted
        )

        let hostingView = NSHostingView(rootView: badgeView)
        hostingView.frame = contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]

        contentView = hostingView
    }
}
