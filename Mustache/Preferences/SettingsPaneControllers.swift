
//
//  SettingsPaneControllers.swift
//  Mustache
//

import Cocoa
import Settings

private enum PaneIdentifiers {
    static let general = Settings.PaneIdentifier("general")
    static let size = Settings.PaneIdentifier("size")
    static let applications = Settings.PaneIdentifier("applications")
    static let statistics = Settings.PaneIdentifier("statistics")
}

final class GeneralPreferencesPaneController: NSViewController, SettingsPane {
    let paneIdentifier = PaneIdentifiers.general
    let paneTitle = "General"
    let toolbarItemIcon = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")!

    private let hostingController: GeneralPreferencesHostingController

    init(preferencesManager: PreferencesManager) {
        hostingController = GeneralPreferencesHostingController(preferencesManager: preferencesManager)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder _: NSCoder) {
        nil
    }

    override func loadView() {
        view = hostingController.view
    }
}

final class SizePreferencesPaneController: NSViewController, SettingsPane {
    let paneIdentifier = PaneIdentifiers.size
    let paneTitle = "Size"
    let toolbarItemIcon = NSImage(systemSymbolName: "textformat.size", accessibilityDescription: "Size")!

    private let hostingController: SizePreferencesHostingController

    init(preferencesManager: PreferencesManager) {
        hostingController = SizePreferencesHostingController(preferencesManager: preferencesManager)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder _: NSCoder) {
        nil
    }

    override func loadView() {
        view = hostingController.view
    }
}

final class ApplicationsPreferencesPaneController: NSViewController, SettingsPane {
    let paneIdentifier = PaneIdentifiers.applications
    let paneTitle = "Applications"
    let toolbarItemIcon = NSImage(systemSymbolName: "app.badge", accessibilityDescription: "Applications")!

    private let hostingController: ApplicationsPreferencesHostingController

    init(preferencesManager: PreferencesManager, applicationMonitor: ApplicationMonitor) {
        hostingController = ApplicationsPreferencesHostingController(
            preferencesManager: preferencesManager,
            applicationMonitor: applicationMonitor
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder _: NSCoder) {
        nil
    }

    override func loadView() {
        view = hostingController.view
    }
}

final class StatisticsPreferencesPaneController: NSViewController, SettingsPane {
    let paneIdentifier = PaneIdentifiers.statistics
    let paneTitle = "Statistics"
    let toolbarItemIcon = NSImage(systemSymbolName: "chart.bar", accessibilityDescription: "Statistics")!

    private let hostingController: StatisticsPreferencesHostingController

    init(statisticsManager: StatisticsManager) {
        hostingController = StatisticsPreferencesHostingController(statisticsManager: statisticsManager)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder _: NSCoder) {
        nil
    }

    override func loadView() {
        view = hostingController.view
    }
}
