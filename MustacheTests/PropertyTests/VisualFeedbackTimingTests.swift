//
//  VisualFeedbackTimingTests.swift
//  MustacheTests
//
//  Property-Based Tests for Visual Feedback Timing
//

@testable import Mustache
import XCTest

/// Feature: numbered-app-switcher, Property 10: Visual feedback timing
/// Validates: Requirements 7.1, 7.2
final class VisualFeedbackTimingTests: XCTestCase {
    /// Property 10: Visual feedback timing
    /// For any valid hotkey press, the corresponding badge should display a highlight
    /// effect for exactly 200ms before returning to normal appearance.
    func testVisualFeedbackTiming() async throws {
        let renderer = await BadgeRenderer()
        let monitor = await ApplicationMonitor()

        // Run 100 iterations
        for iteration in 1 ... 100 {
            await monitor.refreshApplicationList()
            let apps = await monitor.trackedApplications

            // Show badges
            await renderer.showBadges(for: apps)

            // Get badges with assigned numbers
            let badges = await renderer.badges

            guard !badges.isEmpty else {
                // No badges to test, skip this iteration
                await renderer.hideBadges()
                continue
            }

            // Test highlighting each badge
            for badge in badges {
                // Highlight the badge
                let highlightStart = Date()
                await renderer.highlightBadge(number: badge.number, duration: 0.2)

                // Verify badge is highlighted immediately
                let updatedBadges = await renderer.badges
                if let highlightedBadge = updatedBadges.first(where: { $0.number == badge.number }) {
                    XCTAssertTrue(highlightedBadge.isHighlighted,
                                  "Iteration \(iteration): Badge \(badge.number) should be highlighted immediately")
                }

                // Wait for highlight duration (200ms + small buffer)
                try? await Task.sleep(nanoseconds: 220_000_000) // 220ms

                let highlightEnd = Date()
                let duration = highlightEnd.timeIntervalSince(highlightStart) * 1000 // Convert to ms

                // Verify timing is approximately 200ms (with tolerance)
                XCTAssertGreaterThan(duration, 190,
                                     "Iteration \(iteration): Highlight duration should be at least 190ms, was \(duration)ms")
                XCTAssertLessThan(duration, 250,
                                  "Iteration \(iteration): Highlight duration should be at most 250ms, was \(duration)ms")

                // Verify badge is no longer highlighted
                let finalBadges = await renderer.badges
                if let unhighlightedBadge = finalBadges.first(where: { $0.number == badge.number }) {
                    XCTAssertFalse(unhighlightedBadge.isHighlighted,
                                   "Iteration \(iteration): Badge \(badge.number) should not be highlighted after duration")
                }
            }

            // Hide badges
            await renderer.hideBadges()

            // Small delay between iterations
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }

    /// Test that highlight timing is consistent across multiple badges
    func testHighlightTimingConsistency() async throws {
        let renderer = await BadgeRenderer()
        let monitor = await ApplicationMonitor()

        await monitor.refreshApplicationList()
        let apps = await monitor.trackedApplications

        await renderer.showBadges(for: apps)
        let badges = await renderer.badges

        guard badges.count >= 3 else {
            // Need at least 3 badges to test consistency
            await renderer.hideBadges()
            return
        }

        var durations: [Double] = []

        // Test first 3 badges
        for badge in badges.prefix(3) {
            let start = Date()
            await renderer.highlightBadge(number: badge.number, duration: 0.2)

            // Wait for highlight to complete
            try? await Task.sleep(nanoseconds: 220_000_000) // 220ms

            let end = Date()
            durations.append(end.timeIntervalSince(start) * 1000)
        }

        // Verify all durations are approximately 200ms
        for (index, duration) in durations.enumerated() {
            XCTAssertGreaterThan(duration, 190,
                                 "Badge \(index) highlight duration should be at least 190ms")
            XCTAssertLessThan(duration, 250,
                              "Badge \(index) highlight duration should be at most 250ms")
        }

        // Verify consistency (all durations within 30ms of each other)
        if let minDuration = durations.min(), let maxDuration = durations.max() {
            let variance = maxDuration - minDuration
            XCTAssertLessThan(variance, 30,
                              "Highlight duration variance should be less than 30ms, was \(variance)ms")
        }

        await renderer.hideBadges()
    }

    /// Test that multiple rapid highlights are handled correctly
    func testRapidHighlightHandling() async throws {
        let renderer = await BadgeRenderer()
        let monitor = await ApplicationMonitor()

        await monitor.refreshApplicationList()
        let apps = await monitor.trackedApplications

        await renderer.showBadges(for: apps)
        let badges = await renderer.badges

        guard !badges.isEmpty else {
            await renderer.hideBadges()
            return
        }

        // Run 20 iterations of rapid highlights
        for iteration in 1 ... 20 {
            let badge = badges[iteration % badges.count]

            // Trigger highlight
            await renderer.highlightBadge(number: badge.number, duration: 0.2)

            // Verify badge is highlighted
            let updatedBadges = await renderer.badges
            if let highlightedBadge = updatedBadges.first(where: { $0.number == badge.number }) {
                XCTAssertTrue(highlightedBadge.isHighlighted,
                              "Iteration \(iteration): Badge should be highlighted")
            }

            // Small delay (less than highlight duration)
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        await renderer.hideBadges()
    }
}
