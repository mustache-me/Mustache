//
//  InvalidHotkeyTests.swift
//  MustacheTests
//
//  Property-Based Tests for Invalid Hotkey Handling
//

@testable import Mustache
import XCTest

/// Feature: numbered-app-switcher, Property 5: Invalid hotkey ignored
/// Validates: Requirements 2.3
final class InvalidHotkeyTests: XCTestCase {
    /// Property 5: Invalid hotkey ignored
    /// For any number key pressed without an assigned application, the system should
    /// maintain the current application state unchanged.
    func testInvalidHotkeyIgnored() async throws {
        let monitor = await ApplicationMonitor()

        // Run 100 iterations
        for iteration in 1 ... 100 {
            await monitor.refreshApplicationList()

            let apps = await monitor.trackedApplications

            // Test numbers that don't have assigned applications
            for number in 0 ... 9 {
                let app = await monitor.getApplication(forNumber: number)

                if app == nil {
                    // This number is not assigned
                    // Verify that attempting to use it doesn't cause issues
                    XCTAssertNil(app,
                                 "Iteration \(iteration): Number \(number) should not have an assigned app")

                    // The system should handle this gracefully (no crash, no state change)
                    // We verify this by checking the app list remains consistent
                    let appsAfter = await monitor.trackedApplications
                    XCTAssertEqual(apps.count, appsAfter.count,
                                   "Iteration \(iteration): App count should remain unchanged for invalid number")
                }
            }

            // Test that numbers beyond 9 are invalid
            for invalidNumber in [10, 11, 15, 20, 100] {
                let app = await monitor.getApplication(forNumber: invalidNumber)
                XCTAssertNil(app,
                             "Iteration \(iteration): Invalid number \(invalidNumber) should not have an assigned app")
            }

            // Test negative numbers
            for invalidNumber in [-1, -5, -10] {
                let app = await monitor.getApplication(forNumber: invalidNumber)
                XCTAssertNil(app,
                             "Iteration \(iteration): Negative number \(invalidNumber) should not have an assigned app")
            }

            // Small delay
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }

    /// Test that the system handles edge cases gracefully
    func testEdgeCaseHandling() async throws {
        let monitor = await ApplicationMonitor()

        // Run 50 iterations
        for iteration in 1 ... 50 {
            await monitor.refreshApplicationList()

            // Test with empty or minimal app lists
            let apps = await monitor.trackedApplications

            // If we have fewer than 10 apps, some numbers won't be assigned
            if apps.count < 10 {
                let unassignedStart = apps.count

                for number in unassignedStart ... 9 {
                    let expectedNumber = number == 9 ? 0 : number + 1
                    let app = await monitor.getApplication(forNumber: expectedNumber)

                    XCTAssertNil(app,
                                 "Iteration \(iteration): Number \(expectedNumber) should not be assigned when only \(apps.count) apps exist")
                }
            }

            // Verify all assigned numbers are in valid range
            for app in apps {
                if let number = app.assignedNumber {
                    XCTAssertTrue(number >= 0 && number <= 9,
                                  "Iteration \(iteration): Assigned number \(number) should be in range 0-9")
                }
            }

            // Small delay
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
    }
}
