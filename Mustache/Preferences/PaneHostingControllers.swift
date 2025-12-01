
//
//  PaneHostingControllers.swift
//  Mustache
//

import SwiftUI

final class GeneralPreferencesHostingController: NSHostingController<GeneralPreferencesView> {
    init(preferencesManager: PreferencesManager) {
        super.init(rootView: GeneralPreferencesView(preferencesManager: preferencesManager))
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class SizePreferencesHostingController: NSHostingController<SizeConfigurationView> {
    init(preferencesManager: PreferencesManager) {
        super.init(rootView: SizeConfigurationView(preferencesManager: preferencesManager))
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ApplicationsPreferencesHostingController: NSHostingController<ApplicationsPreferencesView> {
    init(preferencesManager: PreferencesManager, applicationMonitor: ApplicationMonitor) {
        super.init(rootView: ApplicationsPreferencesView(
            preferencesManager: preferencesManager,
            applicationMonitor: applicationMonitor
        ))
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class StatisticsPreferencesHostingController: NSHostingController<StatisticsView> {
    init(statisticsManager: StatisticsManager) {
        super.init(rootView: StatisticsView(statisticsManager: statisticsManager))
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
