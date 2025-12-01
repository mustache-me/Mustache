//
//  StatisticsView.swift
//  Mustache
//
//  Statistics visualization view
//

import Charts
import SwiftUI
import UniformTypeIdentifiers

struct StatisticsView: View {
    @ObservedObject var statisticsManager: StatisticsManager
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingClearAlert = false

    enum TimeRange: String, CaseIterable {
        case day = "24 Hours"
        case week = "7 Days"
        case month = "30 Days"
        case all = "All Time"

        var days: Int? {
            switch self {
            case .day: 1
            case .week: 7
            case .month: 30
            case .all: nil
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Statistics")
                            .font(.title2)
                            .fontWeight(.bold)

                        if let firstDate = statisticsManager.statistics.firstRecordedDate {
                            Text("Tracking since \(firstDate, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Time range picker
                    HStack(spacing: 8) {
//                        Text("Time Range")
//                            .font(.subheadline)
//                            .foregroundColor(.secondary)

                        Picker("", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 360)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // Summary cards
                summaryCards
                    .padding(.horizontal)

                // Two column layout for charts
                HStack(alignment: .top, spacing: 16) {
                    // Left column
                    VStack(spacing: 16) {
                        dailyActivityChart
                        shortcutUsageChart
                    }
                    .frame(maxWidth: .infinity)

                    // Right column
                    VStack(spacing: 16) {
                        topAppsChart
                        hourlyHeatmap
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)

                Divider()
                    .padding(.top, 8)

                // Actions
                HStack {
                    Spacer()

                    Button("Export Data") {
                        exportStatistics()
                    }

                    Button("Clear Statistics", role: .destructive) {
                        showingClearAlert = true
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 800)
        .alert("Clear All Statistics?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                statisticsManager.clearStatistics()
            }
        } message: {
            Text("This will permanently delete all usage statistics. This action cannot be undone.")
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        let events = filteredEvents
        let avgResponseTime = statisticsManager.statistics.averageResponseTime(for: events)

        return HStack(spacing: 12) {
            StatCard(
                title: "Total Switches",
                value: "\(events.count)",
                icon: "arrow.left.arrow.right"
            )

            StatCard(
                title: "Unique Apps",
                value: "\(Set(events.map(\.bundleIdentifier)).count)",
                icon: "app.badge"
            )

            StatCard(
                title: "Avg per Day",
                value: String(format: "%.1f", averageSwitchesPerDay),
                icon: "chart.line.uptrend.xyaxis"
            )

            if let avgTime = avgResponseTime {
                StatCard(
                    title: "Avg Response",
                    value: "\(Int(avgTime))ms",
                    icon: "timer"
                )
            }
        }
    }

    // MARK: - Daily Activity Chart

    private var dailyActivityChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Activity")
                .font(.subheadline)
                .fontWeight(.semibold)

            let dailyCounts = statisticsManager.statistics.dailyUsageCounts(for: filteredEvents)

            if dailyCounts.isEmpty {
                compactEmptyStateView
            } else {
                Chart(dailyCounts, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Switches", item.count)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Switches", item.count)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day(), centered: true)
                    }
                }
                .frame(height: 140)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(minWidth: 600)
    }

    // MARK: - Top Apps Chart

    private var topAppsChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most Used Apps")
                .font(.subheadline)
                .fontWeight(.semibold)

            let appCounts = statisticsManager.statistics.appUsageCounts(for: filteredEvents)
                .prefix(8)

            if appCounts.isEmpty {
                compactEmptyStateView
            } else {
                Chart(Array(appCounts), id: \.appName) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("App", item.appName)
                    )
                    .foregroundStyle(.green)
                }
                .frame(height: CGFloat(max(140, appCounts.count * 22)))
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Shortcut Usage Chart

    private var shortcutUsageChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shortcut Key Usage")
                .font(.subheadline)
                .fontWeight(.semibold)

            let shortcutCounts = statisticsManager.statistics.shortcutUsageCounts(for: filteredEvents)
                .prefix(15)

            if shortcutCounts.isEmpty {
                compactEmptyStateView
            } else {
                Chart(Array(shortcutCounts), id: \.key) { item in
                    BarMark(
                        x: .value("Key", item.key),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(.orange)
                }
                .frame(height: 140)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Hourly Heatmap

    private var hourlyHeatmap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage by Hour")
                .font(.subheadline)
                .fontWeight(.semibold)

            let hourlyDist = statisticsManager.statistics.hourlyUsageDistribution(for: filteredEvents)
            let maxCount = hourlyDist.values.max() ?? 1

            if hourlyDist.isEmpty {
                compactEmptyStateView
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 12), spacing: 3) {
                    ForEach(0 ..< 24, id: \.self) { hour in
                        let count = hourlyDist[hour] ?? 0
                        let intensity = Double(count) / Double(maxCount)

                        VStack(spacing: 1) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.blue.opacity(max(0.1, intensity)))
                                .frame(height: 32)
                                .overlay(
                                    Text("\(count)")
                                        .font(.system(size: 9))
                                        .foregroundColor(intensity > 0.5 ? .white : .primary)
                                )

                            Text("\(hour)")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Helper Views

    private var compactEmptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("No data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }

    // MARK: - Computed Properties

    private var filteredEvents: [SwitchEvent] {
        if let days = selectedTimeRange.days {
            statisticsManager.statistics.eventsForLastDays(days)
        } else {
            statisticsManager.statistics.events
        }
    }

    private var averageSwitchesPerDay: Double {
        let events = filteredEvents
        guard !events.isEmpty else { return 0 }

        let days = selectedTimeRange.days ?? {
            guard let firstDate = events.first?.timestamp else { return 1 }
            let daysDiff = Calendar.current.dateComponents([.day], from: firstDate, to: Date()).day ?? 1
            return max(1, daysDiff)
        }()

        return Double(events.count) / Double(days)
    }

    // MARK: - Actions

    private func exportStatistics() {
        guard let data = statisticsManager.exportStatistics() else {
            print("Failed to export statistics")
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "mustache-statistics-\(Date().ISO8601Format()).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try data.write(to: url)
                    print("Statistics exported to: \(url.path)")
                } catch {
                    print("Failed to write statistics: \(error)")
                }
            }
        }
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview {
    StatisticsView(statisticsManager: StatisticsManager())
        .frame(width: 800, height: 600)
}
