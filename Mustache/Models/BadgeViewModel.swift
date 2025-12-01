//
//  BadgeViewModel.swift
//  Mustache
//
//  Numbered App Switcher
//

import CoreGraphics
import Foundation

/// View model for a single badge overlay
struct BadgeViewModel: Identifiable {
    let id: pid_t // Process ID of the application
    let number: Int // Assigned number (0-9)
    var position: CGPoint // Screen position for the badge
    var isHighlighted: Bool // Whether the badge is currently highlighted
}
