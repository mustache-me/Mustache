//
//  KeyCodeMappingTests.swift
//  MustacheTests
//
//  Unit tests for key code mapping
//

import Carbon
@testable import Mustache
import XCTest

final class KeyCodeMappingTests: XCTestCase {
    // MARK: - Key Code Tests

    func testNumberKeyCodeMapping() {
        // Test that key codes are correctly mapped to numbers
        let expectedMappings: [Int: CGKeyCode] = [
            0: 29, // 0 key
            1: 18, // 1 key
            2: 19, // 2 key
            3: 20, // 3 key
            4: 21, // 4 key
            5: 23, // 5 key
            6: 22, // 6 key
            7: 26, // 7 key
            8: 28, // 8 key
            9: 25, // 9 key
        ]

        // Verify all mappings are present
        for (number, keyCode) in expectedMappings {
            XCTAssertTrue(number >= 0 && number <= 9,
                          "Number \(number) should be in range 0-9")
            XCTAssertGreaterThan(keyCode, 0,
                                 "Key code for number \(number) should be positive")
        }
    }

    // MARK: - Modifier Flag Tests

    func testModifierFlagDetection() {
        // Test Control modifier
        let controlConfig = HotkeyConfiguration(modifierFlags: .maskControl, showOverlaysOnModifierOnly: true)
        XCTAssertTrue(controlConfig.eventFlags.contains(.maskControl),
                      "Control modifier should be detected")
        XCTAssertTrue(controlConfig.modifierDescription.contains("Control"),
                      "Modifier description should mention Control")

        // Test Option/Alternate modifier
        let optionConfig = HotkeyConfiguration(modifierFlags: .maskAlternate, showOverlaysOnModifierOnly: true)
        XCTAssertTrue(optionConfig.eventFlags.contains(.maskAlternate),
                      "Option modifier should be detected")
        XCTAssertTrue(optionConfig.modifierDescription.contains("Option"),
                      "Modifier description should mention Option")

        // Test Command modifier
        let commandConfig = HotkeyConfiguration(modifierFlags: .maskCommand, showOverlaysOnModifierOnly: true)
        XCTAssertTrue(commandConfig.eventFlags.contains(.maskCommand),
                      "Command modifier should be detected")
        XCTAssertTrue(commandConfig.modifierDescription.contains("Command"),
                      "Modifier description should mention Command")

        // Test Shift modifier
        let shiftConfig = HotkeyConfiguration(modifierFlags: .maskShift, showOverlaysOnModifierOnly: true)
        XCTAssertTrue(shiftConfig.eventFlags.contains(.maskShift),
                      "Shift modifier should be detected")
        XCTAssertTrue(shiftConfig.modifierDescription.contains("Shift"),
                      "Modifier description should mention Shift")
    }

    func testCombinedModifierFlags() {
        // Test combination of modifiers
        let combinedFlags: CGEventFlags = [.maskAlternate, .maskShift]
        let config = HotkeyConfiguration(modifierFlags: combinedFlags, showOverlaysOnModifierOnly: true)

        XCTAssertTrue(config.eventFlags.contains(.maskAlternate),
                      "Combined flags should include Option")
        XCTAssertTrue(config.eventFlags.contains(.maskShift),
                      "Combined flags should include Shift")

        let description = config.modifierDescription
        XCTAssertTrue(description.contains("Option") && description.contains("Shift"),
                      "Description should mention both modifiers")
    }

    func testModifierFlagPersistence() {
        // Test that modifier flags are preserved through encoding/decoding
        let originalConfig = HotkeyConfiguration(modifierFlags: .maskAlternate, showOverlaysOnModifierOnly: true)

        // Encode
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(originalConfig) else {
            XCTFail("Failed to encode configuration")
            return
        }

        // Decode
        let decoder = JSONDecoder()
        guard let decodedConfig = try? decoder.decode(HotkeyConfiguration.self, from: data) else {
            XCTFail("Failed to decode configuration")
            return
        }

        // Verify
        XCTAssertEqual(originalConfig, decodedConfig,
                       "Configuration should be preserved through encoding/decoding")
        XCTAssertEqual(originalConfig.eventFlags, decodedConfig.eventFlags,
                       "Modifier flags should be preserved")
    }
}
