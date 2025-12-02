//
//  PreferencesManager.swift
//  Mustache
//
//  Numbered App Switcher - Preferences Manager
//

import Combine
import Foundation
import LaunchAtLogin
import os.log

@MainActor
class PreferencesManager: ObservableObject {
    @Published var preferences: AppSwitcherPreferences

    private let preferencesKey = "com.Mustache.preferences"
    private static let logger = Logger.make(category: .preferences)

    init() {
        var loadedPreferences = Self.loadPreferencesFromDisk() ?? .defaults
        loadedPreferences.migrateLegacySettings()
        preferences = loadedPreferences

        if Self.loadPreferencesFromDisk()?.maxItemsPerRow != nil {
            Self.logger.info("Migrating legacy settings")
            savePreferences()
        }

        Self.logger.info("Preferences manager initialized")
    }

    func loadPreferences() {
        if let loaded = Self.loadPreferencesFromDisk() {
            preferences = loaded
        } else {
            preferences = .defaults
        }
    }

    private static func loadPreferencesFromDisk() -> AppSwitcherPreferences? {
        guard let data = UserDefaults.standard.data(forKey: "com.Mustache.preferences") else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(AppSwitcherPreferences.self, from: data)
    }

    func savePreferences() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(preferences) else {
            Self.logger.error("Failed to encode preferences")
            return
        }

        UserDefaults.standard.set(data, forKey: preferencesKey)
        UserDefaults.standard.synchronize()
        Self.logger.debug("Preferences saved successfully")
    }

    func resetToDefaults() {
        Self.logger.info("Resetting preferences to defaults")
        preferences = .defaults
        savePreferences()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        preferences.launchAtLogin = enabled
        savePreferences()
        LaunchAtLogin.isEnabled = enabled
    }

    func updateCustomApplicationOrder(_ order: [String]?) {
        preferences.customApplicationOrder = order
        savePreferences()
    }

    func updateExcludedApplications(_ excluded: Set<String>) {
        preferences.excludedApplications = excluded
        savePreferences()
    }

    func updateBadgeStyle(_ style: BadgeStyle) {
        preferences.badgeStyle = style
        savePreferences()
    }

    // MARK: - Export/Import

    func exportSettings() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(preferences)
    }

    func importSettings(from data: Data) -> Bool {
        let decoder = JSONDecoder()
        guard let imported = try? decoder.decode(AppSwitcherPreferences.self, from: data) else {
            Self.logger.error("Failed to decode imported settings")
            return false
        }

        preferences = imported
        savePreferences()

        // Apply imported settings immediately
        LaunchAtLogin.isEnabled = imported.launchAtLogin

        // Notify all observers to refresh
        NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
        NotificationCenter.default.post(name: .menuBarIconVisibilityChanged, object: nil)

        Self.logger.info("Successfully imported settings")
        return true
    }

    func exportSettingsToFile(url: URL) -> Bool {
        guard let data = exportSettings() else {
            Self.logger.error("Failed to export settings")
            return false
        }

        do {
            try data.write(to: url)
            Self.logger.info("Settings exported to \(url.path)")
            return true
        } catch {
            Self.logger.error("Failed to write settings to file: \(error.localizedDescription)")
            return false
        }
    }

    func importSettingsFromFile(url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            return importSettings(from: data)
        } catch {
            Self.logger.error("Failed to read settings from file: \(error.localizedDescription)")
            return false
        }
    }
}
