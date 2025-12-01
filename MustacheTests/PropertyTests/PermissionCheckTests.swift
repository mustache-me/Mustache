//
//  PermissionCheckTests.swift
//  MustacheTests
//
//  Property-Based Tests for Permission Check Accuracy
//

import ApplicationServices
@testable import Mustache
import XCTest

/// Feature: numbered-app-switcher, Property 11: Permission check accuracy
/// Validates: Requirements 8.1, 8.3
final class PermissionCheckTests: XCTestCase {
    /// Property 11: Permission check accuracy
    /// For any permission state, the system's reported permission status should match
    /// the actual Accessibility API permission state as reported by AXIsProcessTrusted().
    func testPermissionCheckAccuracy() {
        // Run 100 iterations
        for iteration in 1 ... 100 {
            // Get actual permission state from system
            let actualTrusted = AXIsProcessTrusted()

            // Get reported permission state from our helper
            let reportedStatus = AccessibilityHelper.checkPermissionStatus()

            // Verify they match
            if actualTrusted {
                XCTAssertEqual(reportedStatus, .granted,
                               "Iteration \(iteration): When AXIsProcessTrusted() returns true, status should be .granted")
            } else {
                XCTAssertEqual(reportedStatus, .denied,
                               "Iteration \(iteration): When AXIsProcessTrusted() returns false, status should be .denied")
            }

            // Small delay between iterations
            Thread.sleep(forTimeInterval: 0.01) // 10ms
        }
    }

    /// Test that coordinator's permission check matches system state
    func testCoordinatorPermissionCheckAccuracy() async {
        let coordinator = await ApplicationCoordinator()

        // Run 100 iterations
        for iteration in 1 ... 100 {
            // Get actual permission state from system
            let actualTrusted = AXIsProcessTrusted()

            // Get reported permission state from coordinator
            let reportedStatus = await coordinator.checkPermissions()

            // Verify they match
            if actualTrusted {
                XCTAssertEqual(reportedStatus, .granted,
                               "Iteration \(iteration): Coordinator should report .granted when system grants access")
            } else {
                XCTAssertEqual(reportedStatus, .denied,
                               "Iteration \(iteration): Coordinator should report .denied when system denies access")
            }

            // Small delay
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }

    /// Test that permission status is consistent across multiple checks
    func testPermissionStatusConsistency() {
        var statuses: [PermissionStatus] = []

        // Check permission status 50 times
        for _ in 1 ... 50 {
            let status = AccessibilityHelper.checkPermissionStatus()
            statuses.append(status)
            Thread.sleep(forTimeInterval: 0.01) // 10ms
        }

        // Verify all statuses are the same (permission state shouldn't change during test)
        let firstStatus = statuses.first!
        for (index, status) in statuses.enumerated() {
            XCTAssertEqual(status, firstStatus,
                           "Check \(index): Permission status should be consistent across multiple checks")
        }
    }

    /// Test that permission status never returns .notDetermined after initial check
    func testPermissionStatusNeverNotDetermined() {
        // Run 100 checks
        for iteration in 1 ... 100 {
            let status = AccessibilityHelper.checkPermissionStatus()

            // Status should always be either granted or denied, never notDetermined
            XCTAssertTrue(status == .granted || status == .denied,
                          "Iteration \(iteration): Permission status should be either .granted or .denied, got \(status)")
            XCTAssertNotEqual(status, .notDetermined,
                              "Iteration \(iteration): Permission status should never be .notDetermined")

            Thread.sleep(forTimeInterval: 0.01) // 10ms
        }
    }

    /// Test that coordinator's initial permission status is accurate
    func testCoordinatorInitialPermissionStatus() async {
        // Create multiple coordinators and verify initial status
        for iteration in 1 ... 20 {
            let coordinator = await ApplicationCoordinator()
            let actualTrusted = AXIsProcessTrusted()
            let reportedStatus = await coordinator.permissionStatus

            if actualTrusted {
                XCTAssertEqual(reportedStatus, .granted,
                               "Iteration \(iteration): Initial permission status should be .granted")
            } else {
                XCTAssertEqual(reportedStatus, .denied,
                               "Iteration \(iteration): Initial permission status should be .denied")
            }

            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }

    /// Test permission check timing
    func testPermissionCheckTiming() {
        var durations: [Double] = []

        // Measure permission check time 100 times
        for _ in 1 ... 100 {
            let start = Date()
            _ = AccessibilityHelper.checkPermissionStatus()
            let end = Date()

            let duration = end.timeIntervalSince(start) * 1000 // Convert to ms
            durations.append(duration)
        }

        // Verify all checks complete quickly (< 10ms)
        for (index, duration) in durations.enumerated() {
            XCTAssertLessThan(duration, 10,
                              "Check \(index): Permission check should complete in < 10ms, took \(duration)ms")
        }

        // Calculate average
        let average = durations.reduce(0, +) / Double(durations.count)
        XCTAssertLessThan(average, 5,
                          "Average permission check time should be < 5ms, was \(average)ms")
    }
}
