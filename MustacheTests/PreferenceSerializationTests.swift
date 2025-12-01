//
//  PreferenceSerializationTests.swift
//  MustacheTests
//
//  Unit tests for preference serialization
//

@testable import Mustache
import XCTest

final class PreferenceSerializationTests: XCTestCase {
    // MARK: - JSON Encoding/Decoding Tests

    func testPreferencesEncodingDecoding() throws {
        let preferences = AppSwitcherPreferences.defaults

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(preferences)

        XCTAssertGreaterThan(data.count, 0, "Encoded data should not be empty")

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSwitcherPreferences.self, from: data)

        // Verify
        XCTAssertEqual(preferences, decoded, "Decoded preferences should match original")
    }

    func testHotkeyConfigurationSerialization() throws {
        let config = HotkeyConfiguration(modifierFlags: .maskAlternate, showOverlaysOnModifierOnly: true)

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HotkeyConfiguration.self, from: data)

        // Verify
        XCTAssertEqual(config, decoded, "Decoded config should match original")
        XCTAssertEqual(config.eventFlags, decoded.eventFlags, "Modifier flags should be preserved")
    }

    func testBadgeStyleSerialization() throws {
        let style = BadgeStyle()

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(style)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BadgeStyle.self, from: data)

        // Verify
        XCTAssertEqual(style, decoded, "Decoded style should match original")
        XCTAssertEqual(style.fontSize, decoded.fontSize, "Font size should be preserved")
        XCTAssertEqual(style.padding, decoded.padding, "Padding should be preserved")
        XCTAssertEqual(style.cornerRadius, decoded.cornerRadius, "Corner radius should be preserved")
        XCTAssertEqual(style.opacity, decoded.opacity, "Opacity should be preserved")
    }

    func testCustomApplicationOrderSerialization() throws {
        let preferences = AppSwitcherPreferences(
            hotkeyConfiguration: HotkeyConfiguration(),
            customApplicationOrder: ["com.apple.Safari", "com.google.Chrome", "com.microsoft.VSCode"],
            excludedApplications: [],
            launchAtLogin: false,
            badgeStyle: BadgeStyle()
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(preferences)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSwitcherPreferences.self, from: data)

        // Verify
        XCTAssertEqual(preferences.customApplicationOrder, decoded.customApplicationOrder,
                       "Custom application order should be preserved")
    }

    func testExcludedApplicationsSerialization() throws {
        let preferences = AppSwitcherPreferences(
            hotkeyConfiguration: HotkeyConfiguration(),
            customApplicationOrder: nil,
            excludedApplications: Set(["com.apple.Mail", "com.apple.Notes"]),
            launchAtLogin: false,
            badgeStyle: BadgeStyle()
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(preferences)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSwitcherPreferences.self, from: data)

        // Verify
        XCTAssertEqual(preferences.excludedApplications, decoded.excludedApplications,
                       "Excluded applications should be preserved")
    }

    // MARK: - Default Values Tests

    func testDefaultPreferences() {
        let defaults = AppSwitcherPreferences.defaults

        XCTAssertEqual(defaults.hotkeyConfiguration.eventFlags, .maskAlternate,
                       "Default modifier should be Option")
        XCTAssertTrue(defaults.hotkeyConfiguration.showOverlaysOnModifierOnly,
                      "Default should show overlays on modifier only")
        XCTAssertNil(defaults.customApplicationOrder,
                     "Default custom order should be nil")
        XCTAssertTrue(defaults.excludedApplications.isEmpty,
                      "Default excluded apps should be empty")
        XCTAssertFalse(defaults.launchAtLogin,
                       "Default launch at login should be false")

        // Verify badge style defaults
        XCTAssertEqual(defaults.badgeStyle.fontSize, 24,
                       "Default font size should be 24")
        XCTAssertEqual(defaults.badgeStyle.padding, 8,
                       "Default padding should be 8")
        XCTAssertEqual(defaults.badgeStyle.cornerRadius, 8,
                       "Default corner radius should be 8")
        XCTAssertEqual(defaults.badgeStyle.opacity, 0.9,
                       "Default opacity should be 0.9")
    }

    func testDefaultsRoundTrip() throws {
        let defaults = AppSwitcherPreferences.defaults

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(defaults)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSwitcherPreferences.self, from: data)

        // Verify
        XCTAssertEqual(defaults, decoded, "Default preferences should survive round-trip")
    }

    // MARK: - Edge Cases

    func testEmptyCustomOrderSerialization() throws {
        let preferences = AppSwitcherPreferences(
            hotkeyConfiguration: HotkeyConfiguration(),
            customApplicationOrder: [],
            excludedApplications: [],
            launchAtLogin: false,
            badgeStyle: BadgeStyle()
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(preferences)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSwitcherPreferences.self, from: data)

        // Verify
        XCTAssertEqual(preferences.customApplicationOrder, decoded.customApplicationOrder,
                       "Empty custom order should be preserved")
    }

    func testNilCustomOrderSerialization() throws {
        let preferences = AppSwitcherPreferences(
            hotkeyConfiguration: HotkeyConfiguration(),
            customApplicationOrder: nil,
            excludedApplications: [],
            launchAtLogin: false,
            badgeStyle: BadgeStyle()
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(preferences)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSwitcherPreferences.self, from: data)

        // Verify
        XCTAssertNil(decoded.customApplicationOrder,
                     "Nil custom order should be preserved")
    }
}
