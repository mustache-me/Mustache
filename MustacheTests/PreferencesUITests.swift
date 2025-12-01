//
//  PreferencesUITests.swift
//  MustacheTests
//
//  Unit tests for preferences UI interactions
//

@testable import Mustache
import XCTest

final class PreferencesUITests: XCTestCase {
    var preferencesManager: PreferencesManager!
    var applicationMonitor: ApplicationMonitor!

    @MainActor
    override func setUp() async throws {
        preferencesManager = PreferencesManager()
        applicationMonitor = ApplicationMonitor()
    }

    override func tearDown() {
        preferencesManager = nil
        applicationMonitor = nil
    }

    // MARK: - Modifier Key Selection Tests

    @MainActor
    func testModifierKeySelectionUpdatesConfiguration() {
        // Test changing modifier key
        let originalModifier = preferencesManager.preferences.hotkeyConfiguration.eventFlags

        // Change to Control
        preferencesManager.preferences.hotkeyConfiguration.modifierFlags = CGEventFlags.maskControl.rawValue
        preferencesManager.savePreferences()

        XCTAssertNotEqual(preferencesManager.preferences.hotkeyConfiguration.eventFlags, originalModifier,
                          "Modifier should be changed")
        XCTAssertEqual(preferencesManager.preferences.hotkeyConfiguration.eventFlags, .maskControl,
                       "Modifier should be Control")

        // Change to Command
        preferencesManager.preferences.hotkeyConfiguration.modifierFlags = CGEventFlags.maskCommand.rawValue
        preferencesManager.savePreferences()

        XCTAssertEqual(preferencesManager.preferences.hotkeyConfiguration.eventFlags, .maskCommand,
                       "Modifier should be Command")
    }

    @MainActor
    func testModifierKeyPersistence() {
        // Set a specific modifier
        preferencesManager.preferences.hotkeyConfiguration.modifierFlags = CGEventFlags.maskShift.rawValue
        preferencesManager.savePreferences()

        // Create new manager to load from disk
        let newManager = PreferencesManager()

        XCTAssertEqual(newManager.preferences.hotkeyConfiguration.eventFlags, .maskShift,
                       "Modifier should be persisted and loaded")
    }

    // MARK: - Application Reordering Tests

    @MainActor
    func testApplicationReorderingUpdatesNumberAssignments() async {
        await applicationMonitor.refreshApplicationList()
        let originalApps = await applicationMonitor.trackedApplications

        guard originalApps.count >= 2 else {
            // Need at least 2 apps to test reordering
            return
        }

        // Get original order
        let originalPids = originalApps.map(\.id)

        // Reverse the order
        let reversedPids = originalPids.reversed()
        await applicationMonitor.updateApplicationOrdering(Array(reversedPids))

        let reorderedApps = await applicationMonitor.trackedApplications

        // Verify order changed
        XCTAssertEqual(reorderedApps.first?.id, originalApps.last?.id,
                       "First app should now be the last app from original order")

        // Verify numbers are still sequential
        for (index, app) in reorderedApps.prefix(10).enumerated() {
            let expectedNumber = index == 9 ? 0 : index + 1
            XCTAssertEqual(app.assignedNumber, expectedNumber,
                           "App at index \(index) should have number \(expectedNumber)")
        }
    }

    // MARK: - Exclusion Logic Tests

    @MainActor
    func testExclusionLogic() async {
        await applicationMonitor.refreshApplicationList()
        let apps = await applicationMonitor.trackedApplications

        guard let firstApp = apps.first else {
            // No apps to test
            return
        }

        // Exclude the first app
        preferencesManager.preferences.excludedApplications.insert(firstApp.bundleIdentifier)
        preferencesManager.savePreferences()

        // Verify it's in the excluded set
        XCTAssertTrue(preferencesManager.preferences.excludedApplications.contains(firstApp.bundleIdentifier),
                      "App should be in excluded set")

        // Include it again
        preferencesManager.preferences.excludedApplications.remove(firstApp.bundleIdentifier)
        preferencesManager.savePreferences()

        // Verify it's not in the excluded set
        XCTAssertFalse(preferencesManager.preferences.excludedApplications.contains(firstApp.bundleIdentifier),
                       "App should not be in excluded set")
    }

    @MainActor
    func testMultipleExclusions() {
        let bundleIds = ["com.apple.Safari", "com.google.Chrome", "com.microsoft.VSCode"]

        // Exclude multiple apps
        for bundleId in bundleIds {
            preferencesManager.preferences.excludedApplications.insert(bundleId)
        }
        preferencesManager.savePreferences()

        // Verify all are excluded
        for bundleId in bundleIds {
            XCTAssertTrue(preferencesManager.preferences.excludedApplications.contains(bundleId),
                          "\(bundleId) should be excluded")
        }

        // Clear exclusions
        preferencesManager.preferences.excludedApplications.removeAll()
        preferencesManager.savePreferences()

        // Verify all are included
        XCTAssertTrue(preferencesManager.preferences.excludedApplications.isEmpty,
                      "Excluded set should be empty")
    }

    // MARK: - Badge Style Tests

    @MainActor
    func testBadgeStyleUpdates() {
        // Update font size
        preferencesManager.preferences.badgeStyle.fontSize = 36
        preferencesManager.savePreferences()

        XCTAssertEqual(preferencesManager.preferences.badgeStyle.fontSize, 36,
                       "Font size should be updated")

        // Update padding
        preferencesManager.preferences.badgeStyle.padding = 12
        preferencesManager.savePreferences()

        XCTAssertEqual(preferencesManager.preferences.badgeStyle.padding, 12,
                       "Padding should be updated")

        // Update corner radius
        preferencesManager.preferences.badgeStyle.cornerRadius = 12
        preferencesManager.savePreferences()

        XCTAssertEqual(preferencesManager.preferences.badgeStyle.cornerRadius, 12,
                       "Corner radius should be updated")

        // Update opacity
        preferencesManager.preferences.badgeStyle.opacity = 0.8
        preferencesManager.savePreferences()

        XCTAssertEqual(preferencesManager.preferences.badgeStyle.opacity, 0.8,
                       "Opacity should be updated")
    }

    @MainActor
    func testBadgeStylePersistence() {
        // Set custom style
        preferencesManager.preferences.badgeStyle.fontSize = 30
        preferencesManager.preferences.badgeStyle.padding = 10
        preferencesManager.preferences.badgeStyle.cornerRadius = 10
        preferencesManager.preferences.badgeStyle.opacity = 0.85
        preferencesManager.savePreferences()

        // Create new manager to load from disk
        let newManager = PreferencesManager()

        XCTAssertEqual(newManager.preferences.badgeStyle.fontSize, 30,
                       "Font size should be persisted")
        XCTAssertEqual(newManager.preferences.badgeStyle.padding, 10,
                       "Padding should be persisted")
        XCTAssertEqual(newManager.preferences.badgeStyle.cornerRadius, 10,
                       "Corner radius should be persisted")
        XCTAssertEqual(newManager.preferences.badgeStyle.opacity, 0.85,
                       "Opacity should be persisted")
    }

    // MARK: - Launch at Login Tests

    @MainActor
    func testLaunchAtLoginToggle() {
        // Enable launch at login
        preferencesManager.setLaunchAtLogin(true)

        XCTAssertTrue(preferencesManager.preferences.launchAtLogin,
                      "Launch at login should be enabled")

        // Disable launch at login
        preferencesManager.setLaunchAtLogin(false)

        XCTAssertFalse(preferencesManager.preferences.launchAtLogin,
                       "Launch at login should be disabled")
    }
}
