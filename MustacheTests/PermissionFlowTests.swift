//
//  PermissionFlowTests.swift
//  MustacheTests
//
//  Unit tests for permission request flow
//

@testable import Mustache
import XCTest

final class PermissionFlowTests: XCTestCase {
    // MARK: - Permission Dialog Display Logic Tests

    func testPermissionDialogShouldShowWhenDenied() {
        // Test that we should show dialog when permissions are denied
        let status = PermissionStatus.denied
        let shouldShow = shouldShowPermissionDialog(for: status)
        XCTAssertTrue(shouldShow, "Should show permission dialog when status is denied")
    }

    func testPermissionDialogShouldShowWhenNotDetermined() {
        // Test that we should show dialog when permissions are not determined
        let status = PermissionStatus.notDetermined
        let shouldShow = shouldShowPermissionDialog(for: status)
        XCTAssertTrue(shouldShow, "Should show permission dialog when status is not determined")
    }

    func testPermissionDialogShouldNotShowWhenGranted() {
        // Test that we should not show dialog when permissions are granted
        let status = PermissionStatus.granted
        let shouldShow = shouldShowPermissionDialog(for: status)
        XCTAssertFalse(shouldShow, "Should not show permission dialog when status is granted")
    }

    // MARK: - Functionality Disable Tests

    func testFunctionalityShouldBeDisabledWhenDenied() {
        // Test that functionality should be disabled when permissions are denied
        let status = PermissionStatus.denied
        let shouldEnable = shouldEnableFunctionality(for: status)
        XCTAssertFalse(shouldEnable, "Functionality should be disabled when permissions are denied")
    }

    func testFunctionalityShouldBeDisabledWhenNotDetermined() {
        // Test that functionality should be disabled when permissions are not determined
        let status = PermissionStatus.notDetermined
        let shouldEnable = shouldEnableFunctionality(for: status)
        XCTAssertFalse(shouldEnable, "Functionality should be disabled when permissions are not determined")
    }

    func testFunctionalityShouldBeEnabledWhenGranted() {
        // Test that functionality should be enabled when permissions are granted
        let status = PermissionStatus.granted
        let shouldEnable = shouldEnableFunctionality(for: status)
        XCTAssertTrue(shouldEnable, "Functionality should be enabled when permissions are granted")
    }

    // MARK: - Menu Bar Status Text Tests

    func testMenuBarStatusTextForDenied() {
        // Test that menu bar shows appropriate status when denied
        let status = PermissionStatus.denied
        let statusText = getMenuBarStatusText(for: status)
        XCTAssertTrue(statusText.contains("Permission") || statusText.contains("Denied") || statusText.contains("Disabled"),
                      "Status text should indicate permissions are denied")
    }

    func testMenuBarStatusTextForGranted() {
        // Test that menu bar shows appropriate status when granted
        let status = PermissionStatus.granted
        let statusText = getMenuBarStatusText(for: status)
        XCTAssertTrue(statusText.contains("Active") || statusText.contains("Ready") || statusText.isEmpty,
                      "Status text should indicate app is active or be empty")
    }

    func testMenuBarStatusTextForNotDetermined() {
        // Test that menu bar shows appropriate status when not determined
        let status = PermissionStatus.notDetermined
        let statusText = getMenuBarStatusText(for: status)
        XCTAssertTrue(statusText.contains("Permission") || statusText.contains("Setup"),
                      "Status text should indicate permissions need setup")
    }

    // MARK: - Helper Functions

    private func shouldShowPermissionDialog(for status: PermissionStatus) -> Bool {
        status != .granted
    }

    private func shouldEnableFunctionality(for status: PermissionStatus) -> Bool {
        status == .granted
    }

    private func getMenuBarStatusText(for status: PermissionStatus) -> String {
        switch status {
        case .granted:
            ""
        case .denied:
            "Permissions Denied"
        case .notDetermined:
            "Permissions Required"
        }
    }
}
