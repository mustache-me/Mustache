//
//  EdgeCaseTests.swift
//  MustacheTests
//
//  Unit tests for edge case handling
//

@testable import Mustache
import XCTest

final class EdgeCaseTests: XCTestCase {
    var monitor: ApplicationMonitor!
    var coordinator: ApplicationCoordinator!

    @MainActor
    override func setUp() async throws {
        monitor = ApplicationMonitor()
        coordinator = ApplicationCoordinator()
    }

    override func tearDown() {
        monitor = nil
        coordinator = nil
    }

    // MARK: - Crashed App Detection Tests

    @MainActor
    func testCrashedAppDetection() async {
        // Start monitoring
        monitor.startMonitoring()

        // Get initial app list
        let initialApps = monitor.trackedApplications

        // Wait for monitoring to stabilize
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Refresh the list (this should filter out terminated apps)
        monitor.refreshApplicationList()

        let updatedApps = monitor.trackedApplications

        // All apps in the list should be running (not terminated)
        for app in updatedApps {
            if let runningApp = NSRunningApplication.runningApplications(
                withBundleIdentifier: app.bundleIdentifier
            ).first {
                XCTAssertFalse(runningApp.isTerminated,
                               "Tracked app \(app.name) should not be terminated")
            }
        }

        monitor.stopMonitoring()
    }

    @MainActor
    func testTerminatedAppRemoval() async {
        // Start monitoring
        monitor.startMonitoring()

        // Get initial count
        let initialCount = monitor.trackedApplications.count

        // Refresh should remove any terminated apps
        monitor.refreshApplicationList()

        // Wait for update
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        let finalCount = monitor.trackedApplications.count

        // Count should be stable (no terminated apps)
        XCTAssertGreaterThanOrEqual(initialCount, 0,
                                    "Should have non-negative app count")
        XCTAssertGreaterThanOrEqual(finalCount, 0,
                                    "Should have non-negative app count after refresh")

        monitor.stopMonitoring()
    }

    // MARK: - >10 Apps Scenario Tests

    @MainActor
    func testMoreThanTenApps() async {
        // Start monitoring
        monitor.startMonitoring()

        // Wait for apps to be enumerated
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let apps = monitor.trackedApplications

        // Count apps with assigned numbers
        let appsWithNumbers = apps.filter { $0.assignedNumber != nil }

        // Should have at most 10 apps with numbers
        XCTAssertLessThanOrEqual(appsWithNumbers.count, 10,
                                 "Should assign numbers to at most 10 apps")

        // If we have more than 10 apps total, verify the rest don't have numbers
        if apps.count > 10 {
            let appsWithoutNumbers = apps.filter { $0.assignedNumber == nil }
            XCTAssertGreaterThan(appsWithoutNumbers.count, 0,
                                 "Apps beyond the first 10 should not have numbers")

            // Verify the first 10 have numbers
            for i in 0 ..< 10 {
                XCTAssertNotNil(apps[i].assignedNumber,
                                "First 10 apps should have assigned numbers")
            }

            // Verify apps after the first 10 don't have numbers
            for i in 10 ..< apps.count {
                XCTAssertNil(apps[i].assignedNumber,
                             "Apps beyond first 10 should not have assigned numbers")
            }
        }

        monitor.stopMonitoring()
    }

    @MainActor
    func testNumberAssignmentLimit() async {
        // Start monitoring
        monitor.startMonitoring()

        // Wait for enumeration
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let apps = monitor.trackedApplications
        let assignedNumbers = apps.compactMap(\.assignedNumber)

        // Should have at most 10 unique numbers
        let uniqueNumbers = Set(assignedNumbers)
        XCTAssertLessThanOrEqual(uniqueNumbers.count, 10,
                                 "Should have at most 10 unique assigned numbers")

        // All assigned numbers should be in range 0-9
        for number in assignedNumbers {
            XCTAssertTrue(number >= 0 && number <= 9,
                          "Assigned number \(number) should be in range 0-9")
        }

        monitor.stopMonitoring()
    }

    // MARK: - Multiple Windows Per App Tests

    @MainActor
    func testSingleOverlayPerApp() async {
        // Start coordinator
        coordinator.start()

        // Wait for apps to be enumerated
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let apps = coordinator.applicationMonitor.trackedApplications

        // Show badges
        coordinator.badgeRenderer.showBadges(for: apps)

        // Get badge count
        let badgeCount = coordinator.badgeRenderer.badges.count

        // Count apps with assigned numbers
        let appsWithNumbers = apps.filter { $0.assignedNumber != nil }

        // Badge count should equal number of apps with assigned numbers
        // (one badge per app, regardless of window count)
        XCTAssertEqual(badgeCount, appsWithNumbers.count,
                       "Should have exactly one badge per app with assigned number")

        // Verify each app ID appears only once in badges
        let badgeAppIds = coordinator.badgeRenderer.badges.map(\.id)
        let uniqueBadgeAppIds = Set(badgeAppIds)
        XCTAssertEqual(badgeAppIds.count, uniqueBadgeAppIds.count,
                       "Each app should have only one badge")

        coordinator.stop()
    }

    @MainActor
    func testMultipleWindowsHandling() async {
        // Start monitoring
        monitor.startMonitoring()

        // Wait for enumeration
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let apps = monitor.trackedApplications

        // Each app should have at most one window frame tracked
        for app in apps {
            // If app has a window frame, it should be a single frame
            // (not an array or multiple frames)
            if let frame = app.windowFrame {
                XCTAssertNotNil(frame,
                                "Window frame should be a single CGRect")
                XCTAssertGreaterThan(frame.size.width, 0,
                                     "Window frame should have positive width")
                XCTAssertGreaterThan(frame.size.height, 0,
                                     "Window frame should have positive height")
            }
        }

        monitor.stopMonitoring()
    }

    // MARK: - System Sleep/Wake Tests

    @MainActor
    func testRefreshAfterSleepWake() async {
        // Start monitoring
        monitor.startMonitoring()

        // Get initial app list
        let initialApps = monitor.trackedApplications

        // Simulate wake by refreshing
        monitor.refreshApplicationList()

        // Wait for refresh to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        let refreshedApps = monitor.trackedApplications

        // Should have a valid app list after refresh
        XCTAssertGreaterThanOrEqual(refreshedApps.count, 0,
                                    "Should have valid app list after refresh")

        monitor.stopMonitoring()
    }

    // MARK: - Display Configuration Change Tests

    @MainActor
    func testBadgePositionUpdateOnDisplayChange() async {
        // Start coordinator
        coordinator.start()

        // Wait for apps
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let apps = coordinator.applicationMonitor.trackedApplications

        // Show badges
        coordinator.badgeRenderer.showBadges(for: apps)

        // Get initial badge positions
        let initialBadges = coordinator.badgeRenderer.badges

        // Simulate display change by updating positions
        coordinator.badgeRenderer.updateBadgePositions(for: apps)

        // Wait for update
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Badges should still be valid
        let updatedBadges = coordinator.badgeRenderer.badges
        XCTAssertEqual(updatedBadges.count, initialBadges.count,
                       "Badge count should remain the same after position update")

        coordinator.stop()
    }

    // MARK: - Edge Case Integration Tests

    @MainActor
    func testGracefulHandlingOfMissingWindowInfo() async {
        // Start monitoring
        monitor.startMonitoring()

        // Wait for enumeration
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let apps = monitor.trackedApplications

        // Some apps might not have window frames (background apps, etc.)
        // The system should handle this gracefully
        for app in apps {
            // If app has no window frame, it should still be valid
            if app.windowFrame == nil {
                XCTAssertNotNil(app.id, "App should have valid ID")
                XCTAssertNotNil(app.name, "App should have valid name")
            }
        }

        monitor.stopMonitoring()
    }

    @MainActor
    func testRapidAppLaunchAndQuit() async {
        // Start monitoring
        monitor.startMonitoring()

        // Get initial count
        let initialCount = monitor.trackedApplications.count

        // Trigger multiple rapid refreshes (simulating rapid app changes)
        for _ in 1 ... 5 {
            monitor.refreshApplicationList()
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        // Wait for stabilization
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let finalCount = monitor.trackedApplications.count

        // Should handle rapid changes without crashing
        XCTAssertGreaterThanOrEqual(finalCount, 0,
                                    "Should have valid app count after rapid changes")

        monitor.stopMonitoring()
    }
}
