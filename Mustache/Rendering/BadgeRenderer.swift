//
//  BadgeRenderer.swift
//  Mustache
//
//  Numbered App Switcher - Badge Renderer
//

import AppKit
import Combine
import Foundation
import SwiftUI

/// Renders and manages numbered badge overlays
@MainActor
class BadgeRenderer: ObservableObject {
    // MARK: - Published Properties

    @Published var badges: [BadgeViewModel] = []
    @Published var isVisible: Bool = false

    // MARK: - Properties

    var style: BadgeStyle
    private var appSwitcherWindow: AppSwitcherWindow?
    private var highlightTimer: Timer?
    private var currentHighlightedNumber: Int?

    // MARK: - Initialization

    init(style: BadgeStyle? = nil) {
        // Initialize inside the actor, so this call is safe
        self.style = style ?? BadgeStyle()
    }

    // MARK: - Badge Display

    /// Show badges for the given applications
    /// - Parameter applications: Array of tracked applications to show badges for
    func showBadges(for applications: [TrackedApplication]) {
        print("showBadges called with \(applications.count) applications")

        // Create or update app switcher window
        if appSwitcherWindow == nil {
            appSwitcherWindow = AppSwitcherWindow()
        }

        guard let window = appSwitcherWindow else { return }

        // Update content with applications
        window.updateContent(applications: applications, highlightedNumber: currentHighlightedNumber)

        // Show with fade-in animation
        if !isVisible {
            window.alphaValue = 0
            window.orderFront(nil)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                window.animator().alphaValue = 1.0
            }
        }

        isVisible = true
    }

    /// Hide all badges
    func hideBadges() {
        print("hideBadges called")

        guard let window = appSwitcherWindow else {
            isVisible = false
            return
        }

        // Fade out and close
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })

        isVisible = false
        currentHighlightedNumber = nil
    }

    /// Highlight a specific badge
    /// - Parameters:
    ///   - number: The number of the badge to highlight
    ///   - duration: How long to show the highlight (in seconds)
    func highlightBadge(number: Int, duration: TimeInterval = 0.2) {
        currentHighlightedNumber = number

        // Update window to show highlight
        if let _ = appSwitcherWindow, isVisible {
            print("Highlighting badge #\(number)")
        }

        highlightTimer?.invalidate()

        highlightTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.currentHighlightedNumber = nil
            }
        }
    }

    /// Update badge positions for the given applications
    /// - Parameter applications: Array of tracked applications with updated positions
    func updateBadgePositions(for _: [TrackedApplication]) {
        // With the centered overlay, we don't need to update positions
    }

    deinit {
        highlightTimer?.invalidate()
        let window = appSwitcherWindow
        Task { @MainActor in
            window?.close()
        }
    }
}
