//
//  SettingsWindowManager.swift
//  Mustache
//

import Cocoa
import Settings

@MainActor
final class SettingsWindowManager {
    static let shared = SettingsWindowManager()

    private var controller: SettingsWindowController?
    private var currentStatisticsManager: StatisticsManager?

    private init() {}

    func show(preferencesManager: PreferencesManager, applicationMonitor: ApplicationMonitor, statisticsManager: StatisticsManager, initialTab _: SettingsView.SettingsTab? = nil) {
        currentStatisticsManager = statisticsManager

        // Recreate controller if it doesn't exist or if the window was closed
        if controller == nil || controller?.window == nil {
            controller = makeController(
                preferencesManager: preferencesManager,
                applicationMonitor: applicationMonitor,
                statisticsManager: statisticsManager
            )
        }

        // Activate the app and bring window to front
        NSApp.activate(ignoringOtherApps: true)
        controller?.show()

        // Use orderFrontRegardless for more reliable window ordering
        if let window = controller?.window {
            window.orderFrontRegardless()
            window.makeKey()
        }
    }

    private func makeController(preferencesManager: PreferencesManager, applicationMonitor: ApplicationMonitor, statisticsManager: StatisticsManager) -> SettingsWindowController {
        let panes: [SettingsPane] = [
            GeneralPreferencesPaneController(preferencesManager: preferencesManager),
            SizePreferencesPaneController(preferencesManager: preferencesManager),
            ApplicationsPreferencesPaneController(
                preferencesManager: preferencesManager,
                applicationMonitor: applicationMonitor
            ),
            StatisticsPreferencesPaneController(statisticsManager: statisticsManager),
        ]

        let controller = SettingsWindowController(panes: panes)

        if let window = controller.window {
            // Set minimum window size to prevent text wrapping
            window.minSize = NSSize(width: 900, height: 600)
            window.setContentSize(NSSize(width: 950, height: 650))

            if !window.styleMask.contains(.resizable) {
                window.styleMask.insert(.resizable)
            }
        }

        return controller
    }
}
