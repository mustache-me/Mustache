//
//  StatisticsManager.swift
//  Mustache
//
//  Manages usage statistics persistence and access
//

import Combine
import Foundation

/// Manages statistics tracking and persistence
@MainActor
class StatisticsManager: ObservableObject {
    @Published var statistics: UsageStatistics

    private let statisticsKey = "com.Mustache.statistics"

    init() {
        statistics = Self.loadStatistics() ?? UsageStatistics()
    }

    /// Record a new app switch
    func recordSwitch(bundleIdentifier: String, appName: String, shortcutKey: String, responseTimeMs: Int? = nil) {
        statistics.recordSwitch(
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            shortcutKey: shortcutKey,
            responseTimeMs: responseTimeMs
        )
        saveStatistics()
    }

    /// Load statistics from disk
    private static func loadStatistics() -> UsageStatistics? {
        guard let data = UserDefaults.standard.data(forKey: "com.Mustache.statistics") else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(UsageStatistics.self, from: data)
    }

    /// Save statistics to disk
    private func saveStatistics() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(statistics) else {
            print("Failed to encode statistics")
            return
        }

        UserDefaults.standard.set(data, forKey: statisticsKey)
    }

    /// Clear all statistics
    func clearStatistics() {
        statistics = UsageStatistics()
        saveStatistics()
    }

    /// Export statistics as JSON
    func exportStatistics() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(statistics)
    }
}
