//
//  SettingsView.swift
//  Mustache
//
//  Numbered App Switcher - Settings View
//

import SwiftUI

/// SwiftUI view for settings panel
struct SettingsView: View {
    enum SettingsTab: CaseIterable, Identifiable {
        case general
        case size
        case applications
        case statistics

        var id: Self { self }

        var title: String {
            switch self {
            case .general:
                "General"
            case .size:
                "Size"
            case .applications:
                "Applications"
            case .statistics:
                "Statistics"
            }
        }

        var iconName: String {
            switch self {
            case .general:
                "gear"
            case .size:
                "textformat.size"
            case .applications:
                "app.badge"
            case .statistics:
                "chart.bar"
            }
        }
    }

    @ObservedObject var preferencesManager: PreferencesManager
    @ObservedObject var applicationMonitor: ApplicationMonitor
    @StateObject private var statisticsManager = StatisticsManager()
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.iconName)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
            .padding(.top, 12)
        } detail: {
            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .general:
            GeneralPreferencesView(preferencesManager: preferencesManager)
        case .size:
            SizeConfigurationView(preferencesManager: preferencesManager)
        case .applications:
            ApplicationsPreferencesView(
                preferencesManager: preferencesManager,
                applicationMonitor: applicationMonitor
            )
        case .statistics:
            StatisticsView(statisticsManager: statisticsManager)
        }
    }
}

#Preview {
    SettingsView(
        preferencesManager: PreferencesManager(),
        applicationMonitor: ApplicationMonitor()
    )
}
