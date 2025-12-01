//
//  UsageStatistics.swift
//  Mustache
//
//  Usage statistics tracking and storage
//

import Foundation

/// Single app switch event
struct SwitchEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let bundleIdentifier: String
    let appName: String
    let shortcutKey: String // "0"-"9", "a"-"z"
    let responseTimeMs: Int? // Time from keypress to activation

    init(bundleIdentifier: String, appName: String, shortcutKey: String, responseTimeMs: Int? = nil) {
        id = UUID()
        timestamp = Date()
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.shortcutKey = shortcutKey
        self.responseTimeMs = responseTimeMs
    }
}

/// Aggregated statistics
struct UsageStatistics: Codable {
    var events: [SwitchEvent]
    var totalSwitches: Int
    var firstRecordedDate: Date?

    init() {
        events = []
        totalSwitches = 0
        firstRecordedDate = nil
    }

    /// Add a new switch event
    mutating func recordSwitch(bundleIdentifier: String, appName: String, shortcutKey: String, responseTimeMs: Int? = nil) {
        let event = SwitchEvent(
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            shortcutKey: shortcutKey,
            responseTimeMs: responseTimeMs
        )
        events.append(event)
        totalSwitches += 1

        if firstRecordedDate == nil {
            firstRecordedDate = Date()
        }

        // Keep only last 10,000 events to prevent unbounded growth
        if events.count > 10000 {
            events.removeFirst(events.count - 10000)
        }
    }

    /// Get events within a date range
    func events(from startDate: Date, to endDate: Date) -> [SwitchEvent] {
        events.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Get events for the last N days
    func eventsForLastDays(_ days: Int) -> [SwitchEvent] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return events(from: startDate, to: Date())
    }

    /// Get app usage counts
    func appUsageCounts(for events: [SwitchEvent]) -> [(appName: String, count: Int)] {
        let grouped = Dictionary(grouping: events) { $0.appName }
        return grouped.map { (appName: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// Get shortcut key usage counts
    func shortcutUsageCounts(for events: [SwitchEvent]) -> [(key: String, count: Int)] {
        let grouped = Dictionary(grouping: events) { $0.shortcutKey }
        return grouped.map { (key: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// Get daily usage counts
    func dailyUsageCounts(for events: [SwitchEvent]) -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        return grouped.map { (date: $0.key, count: $0.value.count) }
            .sorted { $0.date < $1.date }
    }

    /// Get hourly usage distribution (0-23)
    func hourlyUsageDistribution(for events: [SwitchEvent]) -> [Int: Int] {
        let calendar = Calendar.current
        var distribution: [Int: Int] = [:]

        for event in events {
            let hour = calendar.component(.hour, from: event.timestamp)
            distribution[hour, default: 0] += 1
        }

        return distribution
    }

    /// Get average response time in milliseconds
    func averageResponseTime(for events: [SwitchEvent]) -> Double? {
        let responseTimes = events.compactMap(\.responseTimeMs)
        guard !responseTimes.isEmpty else { return nil }
        return Double(responseTimes.reduce(0, +)) / Double(responseTimes.count)
    }
}
