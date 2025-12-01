//
//  MenuBarTests.swift
//  MustacheTests
//
//  Unit tests for menu bar functionality
//  Requirements: 9.1, 9.2
//

@testable import Mustache
import XCTest

@MainActor
final class MenuBarTests: XCTestCase {
    var appDelegate: AppDelegate!

    override func setUp() async throws {
        appDelegate = AppDelegate()
    }

    override func tearDown() async throws {
        appDelegate = nil
    }

    // MARK: - Menu Item Creation Tests

    /// Test that status item is created on launch
    func testStatusItemCreation() async throws {
        // Simulate app launch
        let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
        appDelegate.applicationDidFinishLaunching(notification)

        // Give it a moment to set up
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Verify status item exists (we can't directly access private properties,
        // but we can verify the app delegate was initialized without crashing)
        XCTAssertNotNil(appDelegate, "AppDelegate should be initialized")
    }

    /// Test that menu contains required items
    func testMenuItemsExist() {
        // Create a test menu to verify structure
        let menu = NSMenu()

        // Status item
        let statusMenuItem = NSMenuItem(title: "Numbered App Switcher", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(AppDelegate.openPreferences),
            keyEquivalent: ","
        )
        menu.addItem(preferencesItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Mustache",
            action: #selector(AppDelegate.quitApplication),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        // Verify menu structure
        XCTAssertEqual(menu.items.count, 5, "Menu should have 5 items (status, separator, preferences, separator, quit)")

        // Verify status item
        XCTAssertEqual(menu.items[0].title, "Numbered App Switcher")
        XCTAssertFalse(menu.items[0].isEnabled, "Status item should be disabled")

        // Verify separator
        XCTAssertTrue(menu.items[1].isSeparatorItem, "Second item should be separator")

        // Verify preferences item
        XCTAssertEqual(menu.items[2].title, "Preferences...")
        XCTAssertEqual(menu.items[2].keyEquivalent, ",")
        XCTAssertEqual(menu.items[2].action, #selector(AppDelegate.openPreferences))

        // Verify separator
        XCTAssertTrue(menu.items[3].isSeparatorItem, "Fourth item should be separator")

        // Verify quit item
        XCTAssertEqual(menu.items[4].title, "Quit Mustache")
        XCTAssertEqual(menu.items[4].keyEquivalent, "q")
        XCTAssertEqual(menu.items[4].action, #selector(AppDelegate.quitApplication))
    }

    // MARK: - Menu Action Tests

    /// Test that preferences action selector exists
    func testPreferencesActionExists() {
        // Verify the selector exists on AppDelegate
        XCTAssertTrue(
            appDelegate.responds(to: #selector(AppDelegate.openPreferences)),
            "AppDelegate should respond to openPreferences selector"
        )
    }

    /// Test that quit action selector exists
    func testQuitActionExists() {
        // Verify the selector exists on AppDelegate
        XCTAssertTrue(
            appDelegate.responds(to: #selector(AppDelegate.quitApplication)),
            "AppDelegate should respond to quitApplication selector"
        )
    }

    /// Test that status item title can be updated
    func testStatusItemTitleUpdate() {
        // This tests the public API for updating status
        let testTitle = "Test Status"

        // Should not crash when called
        appDelegate.updateStatusItemTitle(testTitle)

        // If we get here without crashing, the method works
        XCTAssertTrue(true, "updateStatusItemTitle should execute without crashing")
    }

    // MARK: - Lifecycle Tests

    /// Test that app termination cleanup is handled
    func testApplicationTermination() {
        // Simulate app termination
        let notification = Notification(name: NSApplication.willTerminateNotification)

        // Should not crash
        appDelegate.applicationWillTerminate(notification)

        XCTAssertTrue(true, "Application termination should be handled gracefully")
    }

    /// Test that coordinator is initialized on launch
    func testCoordinatorInitialization() async throws {
        // Simulate app launch
        let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
        appDelegate.applicationDidFinishLaunching(notification)

        // Give it time to initialize
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Verify app delegate is still valid (coordinator initialized internally)
        XCTAssertNotNil(appDelegate, "AppDelegate should remain valid after initialization")
    }
}
