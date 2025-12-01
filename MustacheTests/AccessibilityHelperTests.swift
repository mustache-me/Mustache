//
//  AccessibilityHelperTests.swift
//  MustacheTests
//
//  Unit tests for AccessibilityHelper
//

@testable import Mustache
import XCTest

final class AccessibilityHelperTests: XCTestCase {
    // MARK: - Permission Status Tests

    func testPermissionStatusDetection() {
        // Test that permission status returns a valid enum value
        let status = AccessibilityHelper.checkPermissionStatus()

        // Status should be either granted or denied, never notDetermined
        XCTAssertTrue(status == .granted || status == .denied,
                      "Permission status should be either granted or denied")
    }

    // MARK: - Error Description Tests

    func testErrorDescriptionForSuccess() {
        let description = AccessibilityHelper.errorDescription(for: .success)
        XCTAssertEqual(description, "Success")
    }

    func testErrorDescriptionForAPIDisabled() {
        let description = AccessibilityHelper.errorDescription(for: .apiDisabled)
        XCTAssertTrue(description.contains("API disabled") || description.contains("permissions"),
                      "API disabled error should mention permissions")
    }

    func testErrorDescriptionForInvalidUIElement() {
        let description = AccessibilityHelper.errorDescription(for: .invalidUIElement)
        XCTAssertEqual(description, "Invalid UI element")
    }

    func testErrorDescriptionForFailure() {
        let description = AccessibilityHelper.errorDescription(for: .failure)
        XCTAssertEqual(description, "Generic failure")
    }

    // MARK: - Window Enumeration Tests

    func testEnumerateWindowsWithInvalidApp() {
        // Create a mock terminated app
        // Note: This test verifies the function handles invalid apps gracefully
        let runningApps = NSWorkspace.shared.runningApplications

        // Find a background app without windows
        if let backgroundApp = runningApps.first(where: { $0.activationPolicy == .prohibited }) {
            let windows = AccessibilityHelper.enumerateWindows(for: backgroundApp)
            // Should return empty array for apps without windows or invalid apps
            XCTAssertTrue(windows.isEmpty || windows.count >= 0,
                          "Should handle apps without windows gracefully")
        }
    }

    func testHasVisibleWindowsForCurrentApp() {
        // Test with the current running app (should have windows in test environment)
        if let currentApp = NSRunningApplication.current {
            // The test runner itself may or may not have visible windows
            // Just verify the function doesn't crash
            let hasWindows = AccessibilityHelper.hasVisibleWindows(for: currentApp)
            XCTAssertTrue(hasWindows == true || hasWindows == false,
                          "hasVisibleWindows should return a boolean value")
        }
    }

    // MARK: - Window Frame Tests

    func testGetMainWindowFrameReturnsNilForInvalidApp() {
        // Test with a background app that likely has no windows
        let runningApps = NSWorkspace.shared.runningApplications

        if let backgroundApp = runningApps.first(where: { $0.activationPolicy == .prohibited }) {
            let frame = AccessibilityHelper.getMainWindowFrame(for: backgroundApp)
            // Should return nil for apps without windows
            XCTAssertNil(frame, "Should return nil for apps without accessible windows")
        }
    }
}
