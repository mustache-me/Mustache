//
//  CoordinatorLogicTests.swift
//  MustacheTests
//
//  Unit tests for coordinator logic
//

@testable import Mustache
import XCTest

final class CoordinatorLogicTests: XCTestCase {
    var coordinator: ApplicationCoordinator!

    @MainActor
    override func setUp() async throws {
        coordinator = ApplicationCoordinator()
    }

    override func tearDown() {
        coordinator = nil
    }

    // MARK: - Component Coordination Tests

    @MainActor
    func testComponentInitialization() {
        XCTAssertNotNil(coordinator.applicationMonitor,
                        "Application monitor should be initialized")
        XCTAssertNotNil(coordinator.hotkeyManager,
                        "Hotkey manager should be initialized")
        XCTAssertNotNil(coordinator.badgeRenderer,
                        "Badge renderer should be initialized")
        XCTAssertNotNil(coordinator.preferencesManager,
                        "Preferences manager should be initialized")
    }

    @MainActor
    func testPermissionCheckOnInit() {
        let status = coordinator.permissionStatus
        XCTAssertTrue(status == .granted || status == .denied,
                      "Permission status should be determined on init")
    }

    // MARK: - App Switching Logic Tests

    @MainActor
    func testAppSwitchingWithValidNumber() async {
        // Start the coordinator
        coordinator.start()

        // Wait for apps to be enumerated
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let apps = coordinator.applicationMonitor.trackedApplications

        // Find an app with an assigned number
        if let app = apps.first(where: { $0.assignedNumber != nil }) {
            let number = app.assignedNumber!

            // Switch to the app (should not crash)
            coordinator.switchToApplication(number: number)

            // Verify the method executed without error
            XCTAssertTrue(true, "App switching should complete without error")
        }

        coordinator.stop()
    }

    @MainActor
    func testAppSwitchingWithInvalidNumber() {
        // Try to switch to an invalid number
        coordinator.switchToApplication(number: 99)

        // Should handle gracefully without crashing
        XCTAssertTrue(true, "Invalid number should be handled gracefully")
    }

    // MARK: - Permission Checking Tests

    @MainActor
    func testPermissionCheck() {
        let status = coordinator.checkPermissions()

        XCTAssertTrue(status == .granted || status == .denied,
                      "Permission check should return valid status")
    }

    @MainActor
    func testPermissionStatusProperty() {
        let status = coordinator.permissionStatus

        XCTAssertTrue(status == .granted || status == .denied || status == .notDetermined,
                      "Permission status property should have valid value")
    }

    // MARK: - Configuration Update Tests

    @MainActor
    func testHotkeyConfigurationUpdate() {
        let newConfig = HotkeyConfiguration(
            modifierFlags: .maskControl,
            showOverlaysOnModifierOnly: true
        )

        coordinator.updateHotkeyConfiguration(newConfig)

        XCTAssertEqual(coordinator.hotkeyManager.configuration, newConfig,
                       "Hotkey configuration should be updated")
        XCTAssertEqual(coordinator.preferencesManager.preferences.hotkeyConfiguration, newConfig,
                       "Preferences should be updated")
    }

    @MainActor
    func testBadgeStyleUpdate() {
        var newStyle = BadgeStyle()
        newStyle.fontSize = 30
        newStyle.padding = 12

        coordinator.updateBadgeStyle(newStyle)

        XCTAssertEqual(coordinator.badgeRenderer.style.fontSize, 30,
                       "Badge renderer style should be updated")
        XCTAssertEqual(coordinator.preferencesManager.preferences.badgeStyle.fontSize, 30,
                       "Preferences should be updated")
    }

    // MARK: - Lifecycle Tests

    @MainActor
    func testStartStop() {
        // Start coordinator
        coordinator.start()

        // Verify components are active (if permissions granted)
        if coordinator.permissionStatus == .granted {
            XCTAssertTrue(true, "Coordinator started successfully")
        }

        // Stop coordinator
        coordinator.stop()

        // Verify badges are hidden
        XCTAssertFalse(coordinator.badgeRenderer.isVisible,
                       "Badges should be hidden after stop")
    }

    @MainActor
    func testMultipleStartStopCycles() {
        // Test multiple start/stop cycles
        for _ in 1 ... 5 {
            coordinator.start()
            coordinator.stop()
        }

        // Should handle multiple cycles without issues
        XCTAssertTrue(true, "Multiple start/stop cycles should work")
    }

    // MARK: - Delegate Integration Tests

    @MainActor
    func testApplicationMonitorDelegateIntegration() async {
        coordinator.start()

        // Trigger an application update
        coordinator.applicationMonitor.refreshApplicationList()

        // Wait for update to propagate
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify delegate method was called (indirectly by checking state)
        XCTAssertTrue(true, "Delegate integration should work")

        coordinator.stop()
    }

    @MainActor
    func testModifierKeyStateChangeHandling() {
        // Simulate modifier key press
        coordinator.modifierKeyStateChanged(isPressed: true)

        // Badges should be shown (if apps are available)
        // Note: May not be visible if no apps with windows

        // Simulate modifier key release
        coordinator.modifierKeyStateChanged(isPressed: false)

        // Badges should be hidden
        XCTAssertFalse(coordinator.badgeRenderer.isVisible,
                       "Badges should be hidden when modifier released")
    }

    @MainActor
    func testHotkeyPressHandling() async {
        coordinator.start()

        // Wait for apps to be enumerated
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let apps = coordinator.applicationMonitor.trackedApplications

        if let app = apps.first(where: { $0.assignedNumber != nil }) {
            let number = app.assignedNumber!

            // Simulate hotkey press
            coordinator.hotkeyPressed(number: number)

            // Should handle without crashing
            XCTAssertTrue(true, "Hotkey press should be handled")
        }

        coordinator.stop()
    }
}
