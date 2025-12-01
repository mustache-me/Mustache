//
//  ApplicationEnumerationTests.swift
//  MustacheTests
//
//  Property-Based Tests for Application Enumeration
//

@testable import Mustache
import XCTest

/// Feature: numbered-app-switcher, Property 1: Application enumeration completeness
/// Validates: Requirements 1.1
final class ApplicationEnumerationTests: XCTestCase {
    /// Property 1: Application enumeration completeness
    /// For any set of running applications with visible windows, when the Application Monitor
    /// enumerates applications, all applications with visible windows should appear in the
    /// tracked applications list.
    func testApplicationEnumerationCompleteness() async throws {
        let monitor = await ApplicationMonitor()

        // Run 100 iterations as specified in the design document
        for iteration in 1 ... 100 {
            await monitor.refreshApplicationList()

            let trackedApps = await monitor.trackedApplications
            let runningApps = NSWorkspace.shared.runningApplications

            // Filter to regular apps (same filter as ApplicationMonitor)
            let regularApps = runningApps.filter { app in
                app.activationPolicy == .regular &&
                    app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }

            // Verify all regular apps are tracked (or have no windows)
            for app in regularApps {
                let isTracked = trackedApps.contains { $0.id == app.processIdentifier }

                if !isTracked {
                    // If not tracked, verify it has no visible windows
                    let hasWindows = AccessibilityHelper.hasVisibleWindows(for: app)
                    XCTAssertFalse(hasWindows,
                                   "Iteration \(iteration): App '\(app.localizedName ?? "unknown")' has windows but is not tracked")
                }
            }

            // Small delay between iterations
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
}
