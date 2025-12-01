//
//  AppDelegate.swift
//  Mustache
//
//  Numbered App Switcher - App Delegate
//

import Cocoa
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private var statusItem: NSStatusItem?
    var coordinator: ApplicationCoordinator?
    private var permissionRequestWindow: PermissionRequestWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_: Notification) {
        setupStatusItem()
        setupMenuBarIconObserver()

        Task { @MainActor in
            coordinator = ApplicationCoordinator()

            coordinator?.$permissionStatus
                .sink { [weak self] status in
                    self?.updateMenuBarForPermissionStatus(status)
                }
                .store(in: &cancellables)

            coordinator?.start()

            if coordinator?.shouldShowPermissionDialog() == true {
                showPermissionRequestDialog()
            }

            // Update menu bar icon visibility based on preferences
            updateMenuBarIconVisibility()
        }
    }

    func applicationWillTerminate(_: Notification) {
        Task { @MainActor in
            coordinator?.stop()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        // When user clicks the app icon again (e.g., from Spotlight or Finder), show settings
        openSettings()
        return true
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mustache.fill", accessibilityDescription: "Mustache")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "App Switcher", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let restartItem = NSMenuItem(
            title: "Restart Mustache",
            action: #selector(restartApplication),
            keyEquivalent: "r"
        )
        restartItem.target = self
        restartItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Restart")
        menu.addItem(restartItem)

        let quitItem = NSMenuItem(
            title: "Quit Mustache",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    @objc func openSettings() {
        guard
            let preferencesManager = coordinator?.preferencesManager,
            let applicationMonitor = coordinator?.applicationMonitor,
            let statisticsManager = coordinator?.statisticsManager
        else {
            return
        }

        SettingsWindowManager.shared.show(
            preferencesManager: preferencesManager,
            applicationMonitor: applicationMonitor,
            statisticsManager: statisticsManager
        )
    }

    @objc private func restartApplication() {
        guard let bundlePath = Bundle.main.bundlePath as String? else {
            showRestartError("Could not determine app location")
            return
        }

        print("Attempting to restart app from: \(bundlePath)")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]

        // Debug: print the full command
        print("Restart command: /usr/bin/open -n \"\(bundlePath)\"")

        do {
            try task.run()
            print("Restart command executed successfully")
            // Delay termination slightly to ensure new instance starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            print("Failed to restart app: \(error)")
            showRestartError(error.localizedDescription)
        }
    }

    private func showRestartError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Restart Failed"
        alert.informativeText = "Could not restart the application: \(message)\n\nPlease restart manually."
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Permission Management

    private func showPermissionRequestDialog() {
        guard permissionRequestWindow == nil else {
            permissionRequestWindow?.show()
            return
        }

        permissionRequestWindow = PermissionRequestWindow { [weak self] in
            Task { @MainActor in
                self?.coordinator?.openAccessibilitySettings()
            }
        }

        permissionRequestWindow?.show()
    }

    private func updateMenuBarForPermissionStatus(_ status: PermissionStatus) {
        Task { @MainActor in
            guard let coordinator else { return }
            let statusText = coordinator.getMenuBarStatusText()
            if let menu = statusItem?.menu {
                if let statusMenuItem = menu.item(withTitle: "Mustache") {
                    statusMenuItem.title = statusText.isEmpty ? "Mustache" : "Mustache - \(statusText)"
                }
                updatePermissionMenuItem(in: menu, status: status)
            }
        }
    }

    private func updatePermissionMenuItem(in menu: NSMenu, status: PermissionStatus) {
        if let existingItem = menu.items.first(where: { $0.identifier?.rawValue == "permission-status" }) {
            menu.removeItem(existingItem)
        }

        if status != .granted {
            let permissionItem = NSMenuItem(
                title: status == .denied ? "⚠️ Accessibility Permission Denied" : "⚠️ Accessibility Permission Required",
                action: #selector(showPermissionDialog),
                keyEquivalent: ""
            )
            permissionItem.identifier = NSUserInterfaceItemIdentifier("permission-status")
            permissionItem.target = self
            menu.insertItem(permissionItem, at: 1)
            menu.insertItem(NSMenuItem.separator(), at: 2)
        }
    }

    @objc private func showPermissionDialog() {
        showPermissionRequestDialog()
    }

    // MARK: - Menu Bar Icon Visibility

    private func setupMenuBarIconObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarIconVisibility),
            name: .menuBarIconVisibilityChanged,
            object: nil
        )
    }

    @objc private func updateMenuBarIconVisibility() {
        guard let coordinator else { return }
        let shouldShow = coordinator.preferencesManager.preferences.showMenuBarIcon

        if shouldShow {
            if statusItem == nil {
                setupStatusItem()
            }
        } else {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
        }
    }

    // MARK: - Public Methods

    func updateStatusItemTitle(_ title: String) {
        statusItem?.button?.title = title
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let menuBarIconVisibilityChanged = Notification.Name("menuBarIconVisibilityChanged")
    static let applicationSourceModeChanged = Notification.Name("applicationSourceModeChanged")
}
