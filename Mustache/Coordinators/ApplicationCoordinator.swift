//
//  ApplicationCoordinator.swift
//  Mustache
//
//  Numbered App Switcher - Application Coordinator
//

import AppKit
import Combine
import Foundation
import KeyboardShortcuts
import os.log

/// Coordinates all components of the application
@MainActor
class ApplicationCoordinator: ObservableObject {
    let applicationMonitor: ApplicationMonitor
    let badgeRenderer: BadgeRenderer
    let preferencesManager: PreferencesManager
    let statisticsManager: StatisticsManager
    private var appSwitcherWindow: AppSwitcherWindow?

    @Published var permissionStatus: PermissionStatus = .notDetermined

    private var permissionMonitorTimer: Timer?
    private var isFunctionalityEnabled: Bool = false
    private var isAppSwitcherVisible: Bool = false
    private var keyDownMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var localFlagsChangedMonitor: Any?
    private var isModifierKeyPressed: Bool = false
    private var currentModifierFlags: NSEvent.ModifierFlags = []
    private var cancellables = Set<AnyCancellable>()
    private var eventTap: CFMachPort?
    private var eventTapCheckTimer: Timer?
    private var lastAppListRefresh: Date?
    private let appListRefreshInterval: TimeInterval = 2.0

    private static let logger = Logger(subsystem: "com.mustache.app", category: "ApplicationCoordinator")

    init() {
        preferencesManager = PreferencesManager()
        applicationMonitor = ApplicationMonitor()
        badgeRenderer = BadgeRenderer(style: preferencesManager.preferences.badgeStyle)
        statisticsManager = StatisticsManager()
        applicationMonitor.delegate = self
        permissionStatus = checkPermissions()
        setupBadgeStyleObserver()
    }

    private func setupBadgeStyleObserver() {
        preferencesManager.$preferences
            .map(\.badgeStyle)
            .removeDuplicates()
            .sink { [weak self] newStyle in
                guard let self else { return }
                Task { @MainActor in
                    self.badgeRenderer.style = newStyle
                    if self.isAppSwitcherVisible {
                        self.appSwitcherWindow?.updateContent(
                            applications: self.applicationMonitor.trackedApplications,
                            badgeStyle: newStyle,
                            layoutMode: self.preferencesManager.preferences.layoutMode,
                            gridRows: self.preferencesManager.preferences.gridRows,
                            gridColumns: self.preferencesManager.preferences.gridColumns
                        )
                    }
                }
            }
            .store(in: &cancellables)
    }

    func start() {
        permissionStatus = checkPermissions()

        guard permissionStatus == .granted else {
            disableFunctionality()
            startPermissionMonitoring()
            return
        }

        enableFunctionality()
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationSourceModeChanged),
            name: .applicationSourceModeChanged,
            object: nil
        )
    }

    @objc private func handleApplicationSourceModeChanged() {
        applicationMonitor.applicationSourceMode = preferencesManager.preferences.applicationSourceMode
        applicationMonitor.maxTrackedApplications = preferencesManager.preferences.maxTrackedApplications
        applicationMonitor.pinnedApps = preferencesManager.preferences.pinnedApps
        applicationMonitor.showPinnedAppsFirst = preferencesManager.preferences.showPinnedAppsFirst
        applicationMonitor.refreshApplicationList()
    }

    private func enableFunctionality(showRestartPrompt: Bool = false) {
        guard !isFunctionalityEnabled else { return }

        applicationMonitor.applicationSourceMode = preferencesManager.preferences.applicationSourceMode
        applicationMonitor.maxTrackedApplications = preferencesManager.preferences.maxTrackedApplications
        applicationMonitor.pinnedApps = preferencesManager.preferences.pinnedApps
        applicationMonitor.showPinnedAppsFirst = preferencesManager.preferences.showPinnedAppsFirst

        applicationMonitor.startMonitoring()
        setupKeyboardShortcuts()
        setupGlobalEventMonitors()

        isFunctionalityEnabled = true

        if showRestartPrompt {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "Permission Granted"
                alert.informativeText = "Mustache now has accessibility permissions. Please restart the app for full functionality."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Restart Now")
                alert.addButton(withTitle: "Later")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    guard let bundlePath = Bundle.main.bundlePath as String? else {
                        Self.logger.error("Failed to restart app: Could not determine app location")
                        return
                    }

                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    task.arguments = ["-n", bundlePath]

                    do {
                        try task.run()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NSApplication.shared.terminate(nil)
                        }
                    } catch {
                        Self.logger.error("Failed to restart app: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func disableFunctionality() {
        guard isFunctionalityEnabled else { return }

        applicationMonitor.stopMonitoring()
        removeKeyboardShortcuts()
        removeGlobalEventMonitors()
        hideAppSwitcher()

        isFunctionalityEnabled = false
    }

    func stop() {
        stopPermissionMonitoring()
        disableFunctionality()
        NotificationCenter.default.removeObserver(self)
    }

    func checkPermissions() -> PermissionStatus {
        AccessibilityHelper.checkPermissionStatus()
    }

    func requestPermissions() {
        AccessibilityHelper.requestPermissions()
    }

    private func startPermissionMonitoring() {
        guard permissionStatus != .granted else { return }

        permissionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAndUpdatePermissionStatus()
            }
        }
    }

    private func stopPermissionMonitoring() {
        permissionMonitorTimer?.invalidate()
        permissionMonitorTimer = nil
    }

    private func checkAndUpdatePermissionStatus() {
        let newStatus = checkPermissions()
        guard newStatus != permissionStatus else { return }

        let oldStatus = permissionStatus
        permissionStatus = newStatus

        if newStatus == .granted, oldStatus != .granted {
            enableFunctionality(showRestartPrompt: true)
            stopPermissionMonitoring()
        } else if newStatus != .granted, oldStatus == .granted {
            disableFunctionality()
            startPermissionMonitoring()
        }
    }

    func getMenuBarStatusText() -> String {
        switch permissionStatus {
        case .granted: ""
        case .denied: "Permissions Denied"
        case .notDetermined: "Permissions Required"
        }
    }

    func shouldShowPermissionDialog() -> Bool {
        permissionStatus != .granted
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyDown(for: .toggleAppSwitcher) { [weak self] in
            guard let self else { return }
            if !isAppSwitcherVisible {
                showAppSwitcher()
            }
        }
    }

    private func removeKeyboardShortcuts() {
        KeyboardShortcuts.disable(.toggleAppSwitcher)
    }

    // MARK: - Event Monitoring

    private func setupGlobalEventMonitors() {
        setupEventTap()

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let shouldConsume = handleLocalKeyDown(event: event)
            return shouldConsume ? nil : event
        }

        flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event: event)
        }

        localFlagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event: event)
            return event
        }
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let coordinator = Unmanaged<ApplicationCoordinator>.fromOpaque(refcon).takeUnretainedValue()

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let isEscKey = keyCode == 53

                guard coordinator.isAppSwitcherVisible || isEscKey else {
                    return Unmanaged.passRetained(event)
                }

                let keyboardSequenceKeyCodes: Set<Int64> = [
                    // Numbers and symbols
                    18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24,
                    // Letters (q-p, a-l, z-m)
                    12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30,
                    0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39,
                    6, 7, 8, 9, 11, 45, 46, 43, 47, 44,
                    // Additional symbols
                    50, 42,
                ]

                let isNumberOrLetterKey = keyboardSequenceKeyCodes.contains(keyCode)

                if coordinator.isAppSwitcherVisible, coordinator.isModifierKeyPressed, isNumberOrLetterKey {
                    if let nsEvent = NSEvent(cgEvent: event) {
                        _ = coordinator.processKeyDown(event: nsEvent)
                    }
                    return nil
                }

                if let nsEvent = NSEvent(cgEvent: event) {
                    let shouldConsume = coordinator.processKeyDown(event: nsEvent)
                    if shouldConsume {
                        return nil
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Self.logger.error("Failed to create event tap")
            return
        }

        self.eventTap = eventTap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func removeGlobalEventMonitors() {
        eventTapCheckTimer?.invalidate()
        eventTapCheckTimer = nil

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = localKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyDownMonitor = nil
        }
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }
        if let monitor = flagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedMonitor = nil
        }
        if let monitor = localFlagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            localFlagsChangedMonitor = nil
        }
    }

    private func handleLocalKeyDown(event: NSEvent) -> Bool {
        processKeyDown(event: event)
    }

    private func processKeyDown(event: NSEvent) -> Bool {
        let keyCode = event.keyCode

        if keyCode == 53, isAppSwitcherVisible {
            hideAppSwitcher()
            return true
        }

        if isAppSwitcherVisible, isModifierKeyPressed {
            let keyCodeToIndex: [UInt16: Int] = [
                18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8, 29: 9, 27: 10, 24: 11,
                12: 12, 13: 13, 14: 14, 15: 15, 17: 16, 16: 17, 32: 18, 34: 19, 31: 20, 35: 21, 33: 22, 30: 23,
                0: 24, 1: 25, 2: 26, 3: 27, 5: 28, 4: 29, 38: 30, 40: 31, 37: 32, 41: 33, 39: 34,
                6: 35, 7: 36, 8: 37, 9: 38, 11: 39, 45: 40, 46: 41, 43: 42, 47: 43, 44: 44,
                50: 45, 42: 46,
            ]

            if let index = keyCodeToIndex[keyCode] {
                if applicationMonitor.trackedApplications.contains(where: { $0.assignedNumber == index }) {
                    switchToApplication(index: index)
                }
                hideAppSwitcher()
                return true
            }
        }

        return false
    }

    private func handleFlagsChanged(event: NSEvent) {
        let wasModifierPressed = isModifierKeyPressed
        currentModifierFlags = event.modifierFlags
        isModifierKeyPressed = event.modifierFlags.intersection([.control, .option, .command, .shift]).isEmpty == false

        if wasModifierPressed, !isModifierKeyPressed, isAppSwitcherVisible {
            hideAppSwitcher()
        }
    }

    private func showAppSwitcher() {
        guard !isAppSwitcherVisible else { return }

        if let eventTap, !CGEvent.tapIsEnabled(tap: eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }

        let now = Date()
        let shouldRefresh = lastAppListRefresh == nil || now.timeIntervalSince(lastAppListRefresh!) >= appListRefreshInterval

        if shouldRefresh {
            applicationMonitor.refreshApplicationList()
            lastAppListRefresh = now
        }

        if appSwitcherWindow == nil {
            appSwitcherWindow = AppSwitcherWindow(badgeStyle: preferencesManager.preferences.badgeStyle)
        }

        appSwitcherWindow?.updateContent(
            applications: applicationMonitor.trackedApplications,
            badgeStyle: preferencesManager.preferences.badgeStyle,
            layoutMode: preferencesManager.preferences.layoutMode,
            gridRows: preferencesManager.preferences.gridRows,
            gridColumns: preferencesManager.preferences.gridColumns
        )

        appSwitcherWindow?.orderFrontRegardless()

        isAppSwitcherVisible = true
        isModifierKeyPressed = true
    }

    private func hideAppSwitcher() {
        guard isAppSwitcherVisible else { return }

        appSwitcherWindow?.orderOut(nil)
        isAppSwitcherVisible = false
    }

    private func showAlreadyActiveFeedback(for index: Int) {
        if isAppSwitcherVisible {
            appSwitcherWindow?.updateContent(
                applications: applicationMonitor.trackedApplications,
                highlightedNumber: index,
                badgeStyle: preferencesManager.preferences.badgeStyle,
                layoutMode: preferencesManager.preferences.layoutMode,
                gridRows: preferencesManager.preferences.gridRows,
                gridColumns: preferencesManager.preferences.gridColumns
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.hideAppSwitcher()
            }
        } else {
            if appSwitcherWindow == nil {
                appSwitcherWindow = AppSwitcherWindow(badgeStyle: preferencesManager.preferences.badgeStyle)
            }

            appSwitcherWindow?.updateContent(
                applications: applicationMonitor.trackedApplications,
                highlightedNumber: index,
                badgeStyle: preferencesManager.preferences.badgeStyle
            )

            appSwitcherWindow?.orderFrontRegardless()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.appSwitcherWindow?.orderOut(nil)
            }
        }
    }

    func switchToApplication(index: Int) {
        guard let app = applicationMonitor.trackedApplications.first(where: { $0.assignedNumber == index }) else {
            if isAppSwitcherVisible {
                hideAppSwitcher()
            }
            return
        }

        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           frontmostApp.bundleIdentifier == app.bundleIdentifier
        {
            focusMainWindowOrReopen(for: frontmostApp, appName: app.name)
            showAlreadyActiveFeedback(for: index)
            return
        }

        if let shortcutKey = app.assignedKey {
            statisticsManager.recordSwitch(
                bundleIdentifier: app.bundleIdentifier,
                appName: app.name,
                shortcutKey: shortcutKey
            )
        }

        if app.isRunning {
            guard let runningApp = NSRunningApplication.runningApplications(
                withBundleIdentifier: app.bundleIdentifier
            ).first else {
                return
            }

            if runningApp.isHidden {
                runningApp.unhide()
            }

            runningApp.activate(options: [.activateAllWindows])

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.focusMainWindowOrReopen(for: runningApp, appName: app.name)
            }
        } else {
            launchApplication(bundleIdentifier: app.bundleIdentifier, name: app.name)
        }

        if isAppSwitcherVisible {
            appSwitcherWindow?.updateContent(
                applications: applicationMonitor.trackedApplications,
                highlightedNumber: index,
                badgeStyle: preferencesManager.preferences.badgeStyle,
                layoutMode: preferencesManager.preferences.layoutMode,
                gridRows: preferencesManager.preferences.gridRows,
                gridColumns: preferencesManager.preferences.gridColumns
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.hideAppSwitcher()
            }
        }
    }

    func switchToApplication(number: Int) {
        switchToApplication(index: number)
    }

    private func focusMainWindowOrReopen(for app: NSRunningApplication, appName: String) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        var focusedWindowRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)

        if focusedResult == .success, let focusedWindow = focusedWindowRef {
            var minimizedValue: CFTypeRef?
            let minimizedResult = AXUIElementCopyAttributeValue(focusedWindow as! AXUIElement, kAXMinimizedAttribute as CFString, &minimizedValue)
            if minimizedResult == .success, let isMinimized = minimizedValue as? Bool, isMinimized {
                AXUIElementSetAttributeValue(focusedWindow as! AXUIElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }

            AXUIElementPerformAction(focusedWindow as! AXUIElement, kAXRaiseAction as CFString)
            return
        }

        var mainWindowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWindowRef)

        if result == .success, let mainWindow = mainWindowRef {
            var minimizedValue: CFTypeRef?
            let minimizedResult = AXUIElementCopyAttributeValue(mainWindow as! AXUIElement, kAXMinimizedAttribute as CFString, &minimizedValue)
            if minimizedResult == .success, let isMinimized = minimizedValue as? Bool, isMinimized {
                AXUIElementSetAttributeValue(mainWindow as! AXUIElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }

            AXUIElementSetAttributeValue(mainWindow as! AXUIElement, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(mainWindow as! AXUIElement, kAXRaiseAction as CFString)
        } else {
            var windowsRef: CFTypeRef?
            let windowsResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

            if windowsResult == .success, let windows = windowsRef as? [AXUIElement], !windows.isEmpty {
                var targetWindow: AXUIElement?
                for window in windows {
                    var minimizedValue: CFTypeRef?
                    let minimizedResult = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue)
                    if minimizedResult == .success, let isMinimized = minimizedValue as? Bool, !isMinimized {
                        targetWindow = window
                        break
                    }
                }

                if targetWindow == nil, let firstWindow = windows.first {
                    AXUIElementSetAttributeValue(firstWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                    targetWindow = firstWindow
                }

                if let window = targetWindow {
                    AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                }
            } else {
                sendReopenEvent(to: app, appName: appName)
            }
        }
    }

    private func launchApplication(bundleIdentifier: String, name: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            Self.logger.warning("Could not find application URL for: \(bundleIdentifier)")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        // Capture logger outside of the Sendable closure
        let logger = Self.logger

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            if let error {
                logger.error("Failed to launch \(name): \(error.localizedDescription)")
            }
        }
    }

    private func sendReopenEvent(to app: NSRunningApplication, appName: String) {
        let target = NSAppleEventDescriptor(processIdentifier: app.processIdentifier)
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEReopenApplication),
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )

        do {
            try event.sendEvent(options: .noReply, timeout: TimeInterval(kAEDefaultTimeout))
        } catch {
            Self.logger.error("Failed to send reopen event to \(appName): \(error.localizedDescription)")
        }
    }

    func updateBadgeStyle(_ style: BadgeStyle) {
        badgeRenderer.style = style
        preferencesManager.updateBadgeStyle(style)

        if isAppSwitcherVisible {
            appSwitcherWindow?.updateContent(
                applications: applicationMonitor.trackedApplications,
                badgeStyle: style,
                layoutMode: preferencesManager.preferences.layoutMode,
                gridRows: preferencesManager.preferences.gridRows,
                gridColumns: preferencesManager.preferences.gridColumns
            )
        }

        if badgeRenderer.isVisible {
            badgeRenderer.showBadges(for: applicationMonitor.trackedApplications)
        }
    }
}

extension ApplicationCoordinator: ApplicationMonitorDelegate {
    func applicationsDidUpdate(_ applications: [TrackedApplication]) {
        if badgeRenderer.isVisible {
            badgeRenderer.updateBadgePositions(for: applications)
        }
    }

    func applicationDidActivate(_: TrackedApplication) {}
}
