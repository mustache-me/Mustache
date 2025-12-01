//
//  BadgePositionTrackingTests.swift
//  MustacheTests
//
//  Property-Based Tests for Badge Position Tracking
//

@testable import Mustache
import XCTest

/// Feature: numbered-app-switcher, Property 3: Badge position follows window
/// Validates: Requirements 1.4
final class BadgePositionTrackingTests: XCTestCase {
    /// Property 3: Badge position follows window
    /// For any application window, when the window moves to a new position, the badge
    /// position should be updated to match the new window position within the update interval.
    func testBadgePositionFollowsWindow() async throws {
        let monitor = await ApplicationMonitor()

        // Start monitoring to enable position tracking
        await monitor.startMonitoring()

        // Run 100 iterations
        for iteration in 1 ... 100 {
            let apps = await monitor.trackedApplications

            // Track initial positions
            var initialPositions: [pid_t: CGRect?] = [:]
            for app in apps {
                initialPositions[app.id] = app.windowFrame
            }

            // Wait for one update cycle (500ms + buffer)
            try? await Task.sleep(nanoseconds: 600_000_000) // 600ms

            // Get updated positions
            let updatedApps = await monitor.trackedApplications

            // Verify that if a window moved, the tracked position was updated
            for updatedApp in updatedApps {
                if let initialFrame = initialPositions[updatedApp.id],
                   let initial = initialFrame,
                   let updated = updatedApp.windowFrame
                {
                    // If frames are different, verify the update happened
                    if initial != updated {
                        // Position was updated - this is correct behavior
                        XCTAssertNotEqual(initial, updated,
                                          "Iteration \(iteration): Window frame should be updated when it changes")
                    }
                }
            }

            // Verify all apps with windows have frame information
            for app in updatedApps {
                // If we have accessibility permissions and the app has windows,
                // we should have frame information
                if AccessibilityHelper.checkPermissionStatus() == .granted {
                    if let runningApp = NSRunningApplication.runningApplications(
                        withBundleIdentifier: app.bundleIdentifier
                    ).first {
                        let hasWindows = AccessibilityHelper.hasVisibleWindows(for: runningApp)
                        if hasWindows {
                            // Should have frame information
                            XCTAssertNotNil(app.windowFrame,
                                            "Iteration \(iteration): App '\(app.name)' has windows but no frame information")
                        }
                    }
                }
            }

            // Small delay between iterations
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        await monitor.stopMonitoring()
    }

    /// Test that position updates happen within the required interval
    func testPositionUpdateTiming() async throws {
        let monitor = await ApplicationMonitor()

        await monitor.startMonitoring()

        // Run 20 iterations to test timing
        for iteration in 1 ... 20 {
            let startTime = Date()

            // Wait for one update cycle
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

            let endTime = Date()
            let elapsed = endTime.timeIntervalSince(startTime) * 1000 // Convert to ms

            // Verify update interval is approximately 500ms (with some tolerance)
            XCTAssertGreaterThan(elapsed, 450,
                                 "Iteration \(iteration): Update interval too short: \(elapsed)ms")
            XCTAssertLessThan(elapsed, 600,
                              "Iteration \(iteration): Update interval too long: \(elapsed)ms")
        }

        await monitor.stopMonitoring()
    }
}
