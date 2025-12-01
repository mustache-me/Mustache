//
//  OverlayVisibilityTests.swift
//  MustacheTests
//
//  Property-Based Tests for Overlay Visibility
//

@testable import Mustache
import XCTest

/// Feature: numbered-app-switcher, Property 6: Overlay visibility on modifier press
/// Validates: Requirements 3.1, 3.2, 3.3
final class OverlayVisibilityTests: XCTestCase {
    /// Property 6: Overlay visibility on modifier press
    /// For any modifier key state, when the modifier key is pressed and held, all badges
    /// should become visible within 50ms, and when released, all badges should become
    /// hidden within 50ms.
    func testOverlayVisibilityOnModifierPress() async throws {
        let renderer = await BadgeRenderer()
        let monitor = await ApplicationMonitor()

        // Run 100 iterations
        for iteration in 1 ... 100 {
            await monitor.refreshApplicationList()
            let apps = await monitor.trackedApplications

            // Test showing badges
            let showStartTime = Date()
            await renderer.showBadges(for: apps)
            let showEndTime = Date()

            let showDuration = showEndTime.timeIntervalSince(showStartTime) * 1000 // Convert to ms

            // Verify badges are shown within 50ms
            XCTAssertLessThan(showDuration, 50,
                              "Iteration \(iteration): Badges should appear within 50ms, took \(showDuration)ms")

            // Verify badges are visible
            let isVisible = await renderer.isVisible
            XCTAssertTrue(isVisible,
                          "Iteration \(iteration): Badges should be visible after showBadges()")

            // Verify badge count matches apps with numbers
            let badgeCount = await renderer.badges.count
            let appsWithNumbers = apps.filter { $0.assignedNumber != nil && $0.windowFrame != nil }
            XCTAssertEqual(badgeCount, appsWithNumbers.count,
                           "Iteration \(iteration): Badge count should match apps with assigned numbers and window frames")

            // Small delay to let animations complete
            try? await Task.sleep(nanoseconds: 60_000_000) // 60ms

            // Test hiding badges
            let hideStartTime = Date()
            await renderer.hideBadges()
            let hideEndTime = Date()

            let hideDuration = hideEndTime.timeIntervalSince(hideStartTime) * 1000 // Convert to ms

            // Verify badges are hidden within 50ms
            XCTAssertLessThan(hideDuration, 50,
                              "Iteration \(iteration): Badges should hide within 50ms, took \(hideDuration)ms")

            // Verify badges are not visible
            let isHidden = await !renderer.isVisible
            XCTAssertTrue(isHidden,
                          "Iteration \(iteration): Badges should not be visible after hideBadges()")

            // Verify badge list is cleared
            let badgesAfterHide = await renderer.badges.count
            XCTAssertEqual(badgesAfterHide, 0,
                           "Iteration \(iteration): Badge list should be empty after hiding")

            // Small delay between iterations
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
    }

    /// Test that badges remain visible while modifier is held
    func testBadgesRemainVisibleWhileModifierHeld() async throws {
        let renderer = await BadgeRenderer()
        let monitor = await ApplicationMonitor()

        // Run 50 iterations
        for iteration in 1 ... 50 {
            await monitor.refreshApplicationList()
            let apps = await monitor.trackedApplications

            // Show badges
            await renderer.showBadges(for: apps)

            // Verify badges are visible
            var isVisible = await renderer.isVisible
            XCTAssertTrue(isVisible,
                          "Iteration \(iteration): Badges should be visible initially")

            // Simulate holding modifier for 200ms
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

            // Verify badges are still visible
            isVisible = await renderer.isVisible
            XCTAssertTrue(isVisible,
                          "Iteration \(iteration): Badges should remain visible while modifier held")

            // Hide badges
            await renderer.hideBadges()

            // Small delay
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
    }

    /// Test badge visibility timing consistency
    func testBadgeVisibilityTimingConsistency() async throws {
        let renderer = await BadgeRenderer()
        let monitor = await ApplicationMonitor()

        await monitor.refreshApplicationList()
        let apps = await monitor.trackedApplications

        var showDurations: [Double] = []
        var hideDurations: [Double] = []

        // Run 20 iterations to measure timing
        for _ in 1 ... 20 {
            // Measure show time
            let showStart = Date()
            await renderer.showBadges(for: apps)
            let showEnd = Date()
            showDurations.append(showEnd.timeIntervalSince(showStart) * 1000)

            try? await Task.sleep(nanoseconds: 60_000_000) // 60ms

            // Measure hide time
            let hideStart = Date()
            await renderer.hideBadges()
            let hideEnd = Date()
            hideDurations.append(hideEnd.timeIntervalSince(hideStart) * 1000)

            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }

        // Verify all show operations were within 50ms
        for (index, duration) in showDurations.enumerated() {
            XCTAssertLessThan(duration, 50,
                              "Show operation \(index) took \(duration)ms, should be < 50ms")
        }

        // Verify all hide operations were within 50ms
        for (index, duration) in hideDurations.enumerated() {
            XCTAssertLessThan(duration, 50,
                              "Hide operation \(index) took \(duration)ms, should be < 50ms")
        }
    }
}
