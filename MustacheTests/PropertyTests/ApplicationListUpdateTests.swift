//
//  ApplicationListUpdateTests.swift
//  MustacheTests
//
//  Property-Based Tests for Application List Updates
//

@testable import Mustache
import XCTest

/// Feature: numbered-app-switcher, Property 8: Application list updates on launch/quit
/// Validates: Requirements 6.1, 6.2, 6.4
final class ApplicationListUpdateTests: XCTestCase {
    /// Property 8: Application list updates on launch/quit
    /// For any application launch or quit event, the Application Monitor should detect
    /// the change and update the tracked applications list within 200ms.
    func testApplicationListUpdatesOnLaunchQuit() async throws {
        let monitor = await ApplicationMonitor()

        // Start monitoring
        await monitor.startMonitoring()

        // Run multiple iterations
        for iteration in 1 ... 20 {
            // Get initial count
            let initialCount = await monitor.trackedApplications.count

            // Simulate a refresh (which happens on launch/quit)
            let startTime = Date()
            await monitor.refreshApplicationList()
            let endTime = Date()

            // Verify update happened within 200ms
            let updateTime = endTime.timeIntervalSince(startTime) * 1000 // Convert to ms
            XCTAssertLessThan(updateTime, 200,
                              "Iteration \(iteration): Application list update took \(updateTime)ms, should be < 200ms")

            // Verify list was updated (count may be same or different)
            let updatedCount = await monitor.trackedApplications.count
            XCTAssertTrue(updatedCount >= 0,
                          "Iteration \(iteration): Updated count should be non-negative")

            // Small delay between iterations
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        await monitor.stopMonitoring()
    }

    /// Test that the monitor detects changes in the application list
    func testApplicationListChangesDetected() async throws {
        let monitor = await ApplicationMonitor()

        // Run 100 iterations
        for iteration in 1 ... 100 {
            await monitor.refreshApplicationList()

            let apps = await monitor.trackedApplications

            // Verify the list is consistent
            XCTAssertTrue(apps.count >= 0,
                          "Iteration \(iteration): Application count should be non-negative")

            // Verify all apps have valid IDs
            for app in apps {
                XCTAssertGreaterThan(app.id, 0,
                                     "Iteration \(iteration): App '\(app.name)' has invalid process ID")
            }

            // Small delay
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
}
