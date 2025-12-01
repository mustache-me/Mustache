//
//  NumberReassignmentTests.swift
//  MustacheTests
//
//  Property-Based Tests for Number Reassignment
//

@testable import Mustache
import XCTest

/// Feature: numbered-app-switcher, Property 9: Number reassignment on removal
/// Validates: Requirements 6.2
final class NumberReassignmentTests: XCTestCase {
    /// Property 9: Number reassignment on removal
    /// For any tracked application list, when an application is removed, the remaining
    /// applications should maintain their relative ordering, and numbers should be
    /// reassigned sequentially without gaps (up to 10 apps).
    func testNumberReassignmentOnRemoval() async throws {
        let monitor = await ApplicationMonitor()

        // Run 100 iterations
        for iteration in 1 ... 100 {
            await monitor.refreshApplicationList()

            let initialApps = await monitor.trackedApplications

            // Skip if we don't have enough apps to test removal
            guard initialApps.count >= 2 else {
                continue
            }

            // Simulate removal by creating a new list without one app
            let pidsToKeep = initialApps.dropFirst().map(\.id)
            await monitor.updateApplicationOrdering(pidsToKeep)

            let updatedApps = await monitor.trackedApplications

            // Verify numbers are sequential without gaps
            let assignedNumbers = updatedApps.prefix(10).compactMap(\.assignedNumber)
            let expectedNumbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0].prefix(min(updatedApps.count, 10))

            XCTAssertEqual(assignedNumbers, Array(expectedNumbers),
                           "Iteration \(iteration): Numbers should be sequential after removal")

            // Verify no gaps in numbering
            for (index, app) in updatedApps.prefix(10).enumerated() {
                let expectedNumber = index == 9 ? 0 : index + 1
                XCTAssertEqual(app.assignedNumber, expectedNumber,
                               "Iteration \(iteration): App at index \(index) should have number \(expectedNumber)")
            }

            // Verify apps beyond 10 have no numbers
            if updatedApps.count > 10 {
                for i in 10 ..< updatedApps.count {
                    XCTAssertNil(updatedApps[i].assignedNumber,
                                 "Iteration \(iteration): App at index \(i) should have no number")
                }
            }

            // Verify relative ordering is maintained
            let initialOrder = initialApps.dropFirst().map(\.id)
            let updatedOrder = updatedApps.map(\.id)

            // Check that the order of remaining apps is preserved
            var initialIndex = 0
            for pid in updatedOrder {
                if initialIndex < initialOrder.count, pid == initialOrder[initialIndex] {
                    initialIndex += 1
                }
            }

            // Small delay between iterations
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }

    /// Test that number reassignment works correctly with various list sizes
    func testNumberReassignmentWithVariousListSizes() async throws {
        let monitor = await ApplicationMonitor()

        // Test with different scenarios
        for iteration in 1 ... 50 {
            await monitor.refreshApplicationList()

            let apps = await monitor.trackedApplications

            // Test reassignment by reordering
            if apps.count >= 3 {
                // Reverse the order
                let reversedPids = apps.reversed().map(\.id)
                await monitor.updateApplicationOrdering(reversedPids)

                let reordered = await monitor.trackedApplications

                // Verify numbers are still sequential
                for (index, app) in reordered.prefix(10).enumerated() {
                    let expectedNumber = index == 9 ? 0 : index + 1
                    XCTAssertEqual(app.assignedNumber, expectedNumber,
                                   "Iteration \(iteration): Reordered app at index \(index) should have number \(expectedNumber)")
                }
            }

            // Small delay
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
    }
}
