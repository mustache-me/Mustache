//
//  SingleOverlayTests.swift
//  MustacheTests
//
//  Property-Based Tests for Single Overlay Per Application
//

@testable import Mustache
import XCTest

/// Feature: numbered-app-switcher, Property 12: Single overlay per application
/// Validates: Requirements 10.2
final class SingleOverlayTests: XCTestCase {
    /// Property 12: Single overlay per application
    /// For any application with multiple windows, the Badge Renderer should display
    /// exactly one numbered overlay for that application.
    func testSingleOverlayPerApplication() async {
        let renderer = await BadgeRenderer()
        let monitor = await ApplicationMonitor()

        // Run 100 iterations
        for iteration in 1 ... 100 {
            await monitor.refreshApplicationList()
            let apps = await monitor.trackedApplications

            // Show badges
            await renderer.showBadges(for: apps)

            let badges = await renderer.badges

            // Verify each application has at most one badge
            var appIds = Set<pid_t>()
            var duplicates: [pid_t] = []

            for badge in badges {
                if appIds.contains(badge.id) {
                    duplicates.append(badge.id)
                }
                appIds.insert(badge.id)
            }

            XCTAssertTrue(duplicates.isEmpty,
                          "Iteration \(iteration): Found duplicate badges for app IDs: \(duplicates)")

            // Verify badge count equals unique app count
            XCTAssertEqual(badges.count, appIds.count,
                           "Iteration \(iteration): Badge count should equal unique app count")

            // Verify each app with a number has exactly one badge
            for app in apps where app.assignedNumber != nil && app.windowFrame != nil {
                let badgesForApp = badges.filter { $0.id == app.id }
                XCTAssertEqual(badgesForApp.count, 1,
                               "Iteration \(iteration): App '\(app.name)' should have exactly 1 badge, has \(badgesForApp.count)")
            }

            // Hide badges
            await renderer.hideBadges()

            // Small delay
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
    }

    /// Test that applications without windows don't get badges
    func testNoOverlayForAppsWithoutWindows() async {
        let renderer = await BadgeRenderer()
        let monitor = await ApplicationMonitor()

        // Run 50 iterations
        for iteration in 1 ... 50 {
            await monitor.refreshApplicationList()
            let apps = await monitor.trackedApplications

            await renderer.showBadges(for: apps)
            let badges = await renderer.badges

            // Verify only apps with window frames have badges
            for badge in badges {
                if let app = apps.first(where: { $0.id == badge.id }) {
                    XCTAssertNotNil(app.windowFrame,
                                    "Iteration \(iteration): App with badge should have a window frame")
                }
            }

            await renderer.hideBadges()

            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
    }

    /// Test that badge uniqueness is maintained during updates
    func testBadgeUniquenessAfterUpdates() async {
        let renderer = await BadgeRenderer()
        let monitor = await ApplicationMonitor()

        await monitor.refreshApplicationList()
        let apps = await monitor.trackedApplications

        // Show badges initially
        await renderer.showBadges(for: apps)

        // Run 50 update cycles
        for iteration in 1 ... 50 {
            // Update badge positions
            await renderer.updateBadgePositions(for: apps)

            let badges = await renderer.badges

            // Verify uniqueness after update
            let appIds = badges.map(\.id)
            let uniqueIds = Set(appIds)

            XCTAssertEqual(appIds.count, uniqueIds.count,
                           "Iteration \(iteration): All badge app IDs should be unique after update")

            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }

        await renderer.hideBadges()
    }

    /// Test that showing badges multiple times doesn't create duplicates
    func testMultipleShowCallsNoDuplicates() async {
        let renderer = await BadgeRenderer()
        let monitor = await ApplicationMonitor()

        await monitor.refreshApplicationList()
        let apps = await monitor.trackedApplications

        // Call showBadges multiple times
        for iteration in 1 ... 20 {
            await renderer.showBadges(for: apps)

            let badges = await renderer.badges

            // Verify no duplicates
            let appIds = badges.map(\.id)
            let uniqueIds = Set(appIds)

            XCTAssertEqual(appIds.count, uniqueIds.count,
                           "Iteration \(iteration): Multiple showBadges calls should not create duplicates")

            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        await renderer.hideBadges()
    }

    /// Test that each number is assigned to at most one application
    func testEachNumberAssignedOnce() async {
        let monitor = await ApplicationMonitor()

        // Run 100 iterations
        for iteration in 1 ... 100 {
            await monitor.refreshApplicationList()
            let apps = await monitor.trackedApplications

            // Count how many apps have each number
            var numberCounts: [Int: Int] = [:]

            for app in apps {
                if let number = app.assignedNumber {
                    numberCounts[number, default: 0] += 1
                }
            }

            // Verify each number appears at most once
            for (number, count) in numberCounts {
                XCTAssertEqual(count, 1,
                               "Iteration \(iteration): Number \(number) should be assigned to exactly 1 app, assigned to \(count)")
            }

            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }

    /// Test that badge IDs match application IDs
    func testBadgeIDsMatchApplicationIDs() async {
        let renderer = await BadgeRenderer()
        let monitor = await ApplicationMonitor()

        // Run 50 iterations
        for iteration in 1 ... 50 {
            await monitor.refreshApplicationList()
            let apps = await monitor.trackedApplications

            await renderer.showBadges(for: apps)
            let badges = await renderer.badges

            // Verify each badge ID corresponds to an app
            for badge in badges {
                let appExists = apps.contains { $0.id == badge.id }
                XCTAssertTrue(appExists,
                              "Iteration \(iteration): Badge ID \(badge.id) should correspond to an existing app")
            }

            await renderer.hideBadges()

            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
    }
}
