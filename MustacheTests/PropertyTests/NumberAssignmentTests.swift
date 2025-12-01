//
//  NumberAssignmentTests.swift
//  MustacheTests
//
//  Property-Based Tests for Number Assignment
//

@testable import Mustache
import XCTest

/// Feature: numbered-app-switcher, Property 2: Number assignment uniqueness
/// Validates: Requirements 1.2
final class NumberAssignmentTests: XCTestCase {
    /// Property 2: Number assignment uniqueness
    /// For any tracked application list, each assigned number (1-9, 0) should map to
    /// exactly one application, and no two applications should have the same assigned number.
    func testNumberAssignmentUniqueness() async throws {
        let monitor = await ApplicationMonitor()

        // Run 100 iterations as specified in the design document
        for iteration in 1 ... 100 {
            await monitor.refreshApplicationList()

            let trackedApps = await monitor.trackedApplications

            // Get all assigned numbers
            let assignedNumbers = trackedApps.compactMap(\.assignedNumber)

            // Verify uniqueness: no duplicates
            let uniqueNumbers = Set(assignedNumbers)
            XCTAssertEqual(assignedNumbers.count, uniqueNumbers.count,
                           "Iteration \(iteration): Duplicate numbers found in assignment")

            // Verify each number maps to exactly one application
            for number in 0 ... 9 {
                let appsWithNumber = trackedApps.filter { $0.assignedNumber == number }
                XCTAssertTrue(appsWithNumber.count <= 1,
                              "Iteration \(iteration): Number \(number) assigned to \(appsWithNumber.count) apps, expected 0 or 1")
            }

            // Verify numbers are in valid range (0-9)
            for number in assignedNumbers {
                XCTAssertTrue(number >= 0 && number <= 9,
                              "Iteration \(iteration): Invalid number \(number) assigned (must be 0-9)")
            }

            // Verify only first 10 apps have numbers
            if trackedApps.count > 10 {
                for i in 10 ..< trackedApps.count {
                    XCTAssertNil(trackedApps[i].assignedNumber,
                                 "Iteration \(iteration): App at index \(i) should not have a number (only first 10 apps get numbers)")
                }
            }

            // Verify numbers 1-9, 0 are assigned in order for first 10 apps
            let expectedNumbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
            for (index, app) in trackedApps.prefix(10).enumerated() {
                XCTAssertEqual(app.assignedNumber, expectedNumbers[index],
                               "Iteration \(iteration): App at index \(index) should have number \(expectedNumbers[index])")
            }

            // Small delay between iterations
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
}
