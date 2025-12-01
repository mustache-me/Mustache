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
    private static let logger = Logger(subsystem: "com.mustache.app", category: "PreferencesManager")

    init() {
        var loadedPreferences = Self.loadPreferencesFromDisk() ?? .defaults
        loadedPreferences.migrateLegacySettings()
        preferences = loadedPreferences

        if Self.loadPreferencesFromDisk()?.maxItemsPerRow != nil {
            savePreferences()
        }
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
    }

    func resetToDefaults() {
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
}
