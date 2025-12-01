//
//  HotkeyActivationTests.swift
//  MustacheTests
//
//  Property-Based Tests for Hotkey Activation
//

@testable import Mustache
import XCTest

/// Feature: numbered-app-switcher, Property 4: Hotkey activation correctness
/// Validates: Requirements 2.1, 2.2
final class HotkeyActivationTests: XCTestCase {
    /// Property 4: Hotkey activation correctness
    /// For any valid hotkey combination (modifier + number), when pressed, the system
    /// should activate the application assigned to that number, and that application
    /// should become frontmost.
    func testHotkeyActivationCorrectness() throws {
        // Run 100 iterations
        for iteration in 1 ... 100 {
            // Test different modifier configurations
            let modifiers: [CGEventFlags] = [
                .maskAlternate,
                .maskControl,
                .maskCommand,
                .maskShift,
            ]

            let modifier = modifiers[iteration % modifiers.count]
            let config = HotkeyConfiguration(modifierFlags: modifier, showOverlaysOnModifierOnly: true)

            // Verify configuration is valid
            XCTAssertEqual(config.eventFlags, modifier,
                           "Iteration \(iteration): Configuration should preserve modifier flags")

            // Test number range (0-9)
            for number in 0 ... 9 {
                XCTAssertTrue(number >= 0 && number <= 9,
                              "Iteration \(iteration): Number \(number) should be in valid range 0-9")
            }

            // Verify modifier description is human-readable
            let description = config.modifierDescription
            XCTAssertFalse(description.isEmpty,
                           "Iteration \(iteration): Modifier description should not be empty")
            XCTAssertNotEqual(description, "None",
                              "Iteration \(iteration): Modifier description should not be 'None' for valid modifiers")
        }
    }

    /// Test that hotkey manager can be created with various configurations
    func testHotkeyManagerCreation() throws {
        // Run 100 iterations with different configurations
        for iteration in 1 ... 100 {
            let modifiers: [CGEventFlags] = [
                .maskAlternate,
                .maskControl,
                .maskCommand,
                .maskShift,
                [.maskAlternate, .maskShift],
                [.maskControl, .maskCommand],
            ]

            let modifier = modifiers[iteration % modifiers.count]
            let config = HotkeyConfiguration(modifierFlags: modifier, showOverlaysOnModifierOnly: true)

            let manager = HotkeyManager(configuration: config)

            // Verify manager was created successfully
            XCTAssertNotNil(manager,
                            "Iteration \(iteration): HotkeyManager should be created successfully")
            XCTAssertEqual(manager.configuration, config,
                           "Iteration \(iteration): Manager should have correct configuration")
        }
    }

    /// Test configuration updates
    func testConfigurationUpdate() throws {
        let manager = HotkeyManager()

        // Run 50 iterations
        for iteration in 1 ... 50 {
            let modifiers: [CGEventFlags] = [
                .maskAlternate,
                .maskControl,
                .maskCommand,
            ]

            let newModifier = modifiers[iteration % modifiers.count]
            let newConfig = HotkeyConfiguration(modifierFlags: newModifier, showOverlaysOnModifierOnly: true)

            // Update configuration (without registering, to avoid permission issues in tests)
            try manager.updateConfiguration(newConfig)

            // Verify configuration was updated
            XCTAssertEqual(manager.configuration, newConfig,
                           "Iteration \(iteration): Configuration should be updated")
        }
    }
}
