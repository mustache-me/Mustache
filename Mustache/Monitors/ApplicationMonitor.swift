//
//  ApplicationMonitor.swift
//  Mustache
//
//  Numbered App Switcher - Application Monitor
//

import AppKit
import Combine
import Foundation
import os.log

/// Delegate protocol for application monitor events
protocol ApplicationMonitorDelegate: AnyObject {
    func applicationsDidUpdate(_ applications: [TrackedApplication])
    func applicationDidActivate(_ application: TrackedApplication)
}

/// Monitors running applications and assigns numbers to them
@MainActor
class ApplicationMonitor: ObservableObject {
    @Published var trackedApplications: [TrackedApplication] = []

    weak var delegate: ApplicationMonitorDelegate?
    private var isMonitoring = false
    private var windowPositionTimer: Timer?
    var applicationSourceMode: ApplicationSourceMode = .runningApplications
    var maxTrackedApplications: Int = 10
    var pinnedApps: [PinnedApp] = []
    var showPinnedAppsFirst: Bool = true

    private var iconCache: [String: NSImage] = [:]
    private struct AppMetadata {
        let name: String
        let url: URL
    }

    private var metadataCache: [String: AppMetadata] = [:]
    private var dockAppsCache: [String]?
    private var dockAppsCacheTime: Date?
    private let dockAppsCacheDuration: TimeInterval = 5.0

    private static let logger = Logger(subsystem: "com.mustache.app", category: "ApplicationMonitor")

    init() {}

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        refreshApplicationList()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        stopWindowPositionPolling()
    }

    func refreshApplicationList() {
        switch applicationSourceMode {
        case .runningApplications:
            refreshRunningApplications()
        case .dock:
            refreshDockApplications()
        }
    }

    private func refreshRunningApplications() {
        let runningApps = NSWorkspace.shared.runningApplications

        let filteredApps = runningApps.filter { app in
            guard app.activationPolicy == .regular else { return false }
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
            guard !app.isTerminated else { return false }
            return true
        }

        var tracked: [TrackedApplication] = []

        for app in filteredApps {
            let trackedApp = TrackedApplication(
                id: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier ?? "unknown",
                name: app.localizedName ?? "Unknown",
                icon: getCachedIcon(for: app),
                assignedNumber: nil,
                assignedKey: nil,
                isActive: app.isActive,
                windowFrame: nil,
                isRunning: true
            )

            tracked.append(trackedApp)
        }

        for pinnedApp in pinnedApps where pinnedApp.alwaysShow {
            if !tracked.contains(where: { $0.bundleIdentifier == pinnedApp.bundleIdentifier }) {
                if let metadata = getCachedMetadata(for: pinnedApp.bundleIdentifier) {
                    let appIcon = getCachedIcon(for: pinnedApp.bundleIdentifier, appURL: metadata.url)
                    let trackedApp = TrackedApplication(
                        id: 0,
                        bundleIdentifier: pinnedApp.bundleIdentifier,
                        name: pinnedApp.name,
                        icon: appIcon,
                        assignedNumber: nil,
                        assignedKey: nil,
                        isActive: false,
                        windowFrame: nil,
                        isRunning: false
                    )
                    tracked.append(trackedApp)
                }
            }
        }

        tracked = sortApplications(tracked)
        tracked = assignShortcuts(to: tracked)

        trackedApplications = tracked
        delegate?.applicationsDidUpdate(tracked)
    }

    private func refreshDockApplications() {
        let persistentDockApps = getDockApplications()
        var tracked: [TrackedApplication] = []
        var processedBundleIDs = Set<String>()

        let finderBundleID = "com.apple.finder"
        if let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).first,
           !finderApp.isTerminated
        {
            processedBundleIDs.insert(finderBundleID)
            let trackedApp = TrackedApplication(
                id: finderApp.processIdentifier,
                bundleIdentifier: finderBundleID,
                name: finderApp.localizedName ?? "Finder",
                icon: getCachedIcon(for: finderApp),
                assignedNumber: nil,
                assignedKey: nil,
                isActive: finderApp.isActive,
                windowFrame: nil,
                isRunning: true
            )
            tracked.append(trackedApp)
        }

        for bundleID in persistentDockApps {
            guard !processedBundleIDs.contains(bundleID) else { continue }
            processedBundleIDs.insert(bundleID)

            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)

            if let runningApp = runningApps.first,
               runningApp.processIdentifier != ProcessInfo.processInfo.processIdentifier,
               !runningApp.isTerminated
            {
                let trackedApp = TrackedApplication(
                    id: runningApp.processIdentifier,
                    bundleIdentifier: bundleID,
                    name: runningApp.localizedName ?? "Unknown",
                    icon: getCachedIcon(for: runningApp),
                    assignedNumber: nil,
                    assignedKey: nil,
                    isActive: runningApp.isActive,
                    windowFrame: nil,
                    isRunning: true
                )
                tracked.append(trackedApp)
            } else {
                if let metadata = getCachedMetadata(for: bundleID) {
                    let appIcon = getCachedIcon(for: bundleID, appURL: metadata.url)
                    let trackedApp = TrackedApplication(
                        id: 0,
                        bundleIdentifier: bundleID,
                        name: metadata.name,
                        icon: appIcon,
                        assignedNumber: nil,
                        assignedKey: nil,
                        isActive: false,
                        windowFrame: nil,
                        isRunning: false
                    )
                    tracked.append(trackedApp)
                }
            }
        }

        let runningApps = NSWorkspace.shared.runningApplications
        let filteredRunningApps = runningApps.filter { app in
            guard app.activationPolicy == .regular else { return false }
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
            guard !app.isTerminated else { return false }
            guard let bundleID = app.bundleIdentifier else { return false }
            return !processedBundleIDs.contains(bundleID)
        }

        for app in filteredRunningApps {
            let bundleID = app.bundleIdentifier ?? "unknown"
            let trackedApp = TrackedApplication(
                id: app.processIdentifier,
                bundleIdentifier: bundleID,
                name: app.localizedName ?? "Unknown",
                icon: getCachedIcon(for: app),
                assignedNumber: nil,
                assignedKey: nil,
                isActive: app.isActive,
                windowFrame: nil,
                isRunning: true
            )
            tracked.append(trackedApp)
        }

        for pinnedApp in pinnedApps where pinnedApp.alwaysShow {
            if !tracked.contains(where: { $0.bundleIdentifier == pinnedApp.bundleIdentifier }) {
                if let metadata = getCachedMetadata(for: pinnedApp.bundleIdentifier) {
                    let appIcon = getCachedIcon(for: pinnedApp.bundleIdentifier, appURL: metadata.url)
                    let trackedApp = TrackedApplication(
                        id: 0,
                        bundleIdentifier: pinnedApp.bundleIdentifier,
                        name: pinnedApp.name,
                        icon: appIcon,
                        assignedNumber: nil,
                        assignedKey: nil,
                        isActive: false,
                        windowFrame: nil,
                        isRunning: false
                    )
                    tracked.append(trackedApp)
                }
            }
        }

        tracked = sortApplications(tracked)
        tracked = assignShortcuts(to: tracked)

        trackedApplications = tracked
        delegate?.applicationsDidUpdate(tracked)
    }

    private func getCachedIcon(for bundleID: String, appURL: URL) -> NSImage {
        if let cachedIcon = iconCache[bundleID] {
            return cachedIcon
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        iconCache[bundleID] = icon
        return icon
    }

    private func getCachedIcon(for app: NSRunningApplication) -> NSImage {
        let bundleID = app.bundleIdentifier ?? "unknown"

        if let cachedIcon = iconCache[bundleID] {
            return cachedIcon
        }

        let icon = app.icon ?? NSImage()
        iconCache[bundleID] = icon
        return icon
    }

    private func getCachedMetadata(for bundleID: String) -> AppMetadata? {
        if let cached = metadataCache[bundleID] {
            return cached
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            Self.logger.warning("Could not find app URL for bundle ID: \(bundleID)")
            return nil
        }

        let appName = FileManager.default.displayName(atPath: appURL.path)
        let metadata = AppMetadata(name: appName, url: appURL)
        metadataCache[bundleID] = metadata
        return metadata
    }

    func clearCaches() {
        iconCache.removeAll()
        metadataCache.removeAll()
        dockAppsCache = nil
        dockAppsCacheTime = nil
    }

    private func getDockApplications() -> [String] {
        if let cached = dockAppsCache,
           let cacheTime = dockAppsCacheTime,
           Date().timeIntervalSince(cacheTime) < dockAppsCacheDuration
        {
            return cached
        }

        guard let dockPlist = UserDefaults.standard.persistentDomain(forName: "com.apple.dock"),
              let persistentApps = dockPlist["persistent-apps"] as? [[String: Any]]
        else {
            Self.logger.error("Failed to read dock preferences")
            return []
        }

        var bundleIDs: [String] = []
        var seenBundleIDs = Set<String>()

        for app in persistentApps {
            if let tileData = app["tile-data"] as? [String: Any],
               let bundleID = tileData["bundle-identifier"] as? String,
               !seenBundleIDs.contains(bundleID)
            {
                bundleIDs.append(bundleID)
                seenBundleIDs.insert(bundleID)
            }
        }

        dockAppsCache = bundleIDs
        dockAppsCacheTime = Date()

        return bundleIDs
    }

    func getApplication(forNumber number: Int) -> TrackedApplication? {
        trackedApplications.first { $0.assignedNumber == number }
    }

    private func sortApplications(_ apps: [TrackedApplication]) -> [TrackedApplication] {
        guard showPinnedAppsFirst else {
            return apps
        }

        var pinnedAppsInOrder: [TrackedApplication] = []
        var unpinnedApps: [TrackedApplication] = []

        let pinnedAppIndices = Dictionary(uniqueKeysWithValues: pinnedApps.enumerated().map { ($0.element.bundleIdentifier, $0.offset) })

        for app in apps {
            if pinnedAppIndices[app.bundleIdentifier] != nil {
                pinnedAppsInOrder.append(app)
            } else {
                unpinnedApps.append(app)
            }
        }

        pinnedAppsInOrder.sort { app1, app2 in
            let index1 = pinnedAppIndices[app1.bundleIdentifier] ?? Int.max
            let index2 = pinnedAppIndices[app2.bundleIdentifier] ?? Int.max
            return index1 < index2
        }

        return pinnedAppsInOrder + unpinnedApps
    }

    private func assignShortcuts(to apps: [TrackedApplication]) -> [TrackedApplication] {
        var result: [TrackedApplication] = []
        var occupiedIndices = Set<Int>()

        for pinnedApp in pinnedApps {
            if let customIndex = pinnedApp.shortcutIndex {
                occupiedIndices.insert(customIndex)
            }
        }

        var nextAvailableIndex = 0
        for app in apps {
            var trackedApp = app
            let pinnedApp = pinnedApps.first(where: { $0.bundleIdentifier == app.bundleIdentifier })

            if let pinnedApp, let customIndex = pinnedApp.shortcutIndex {
                trackedApp.assignedNumber = customIndex
                trackedApp.assignedKey = pinnedApp.customShortcut
            } else {
                while nextAvailableIndex < maxTrackedApplications, occupiedIndices.contains(nextAvailableIndex) {
                    nextAvailableIndex += 1
                }

                let isPinnedAlwaysShow = pinnedApp?.alwaysShow == true
                let shouldAssignShortcut = nextAvailableIndex < maxTrackedApplications || isPinnedAlwaysShow

                if shouldAssignShortcut, nextAvailableIndex < 47 {
                    trackedApp.assignedNumber = nextAvailableIndex
                    trackedApp.assignedKey = TrackedApplication.shortcutKey(for: nextAvailableIndex)
                    occupiedIndices.insert(nextAvailableIndex)
                    nextAvailableIndex += 1
                } else {
                    trackedApp.assignedNumber = nil
                    trackedApp.assignedKey = nil
                }
            }

            result.append(trackedApp)
        }

        return result
    }

    func updateApplicationOrdering(_ newOrder: [pid_t]) {
        var reordered: [TrackedApplication] = []

        for pid in newOrder {
            if let app = trackedApplications.first(where: { $0.id == pid }) {
                reordered.append(app)
            }
        }

        for app in trackedApplications {
            if !reordered.contains(where: { $0.id == app.id }) {
                reordered.append(app)
            }
        }

        for (index, var app) in reordered.enumerated() {
            if index < maxTrackedApplications {
                app.assignedNumber = index
                app.assignedKey = TrackedApplication.shortcutKey(for: index)
            } else {
                app.assignedNumber = nil
                app.assignedKey = nil
            }
            reordered[index] = app
        }

        trackedApplications = reordered
        delegate?.applicationsDidUpdate(reordered)
    }

    private func startWindowPositionPolling() {
        let weakSelf = self
        windowPositionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor [weak weakSelf] in
                weakSelf?.updateWindowPositions()
            }
        }
    }

    private func stopWindowPositionPolling() {
        windowPositionTimer?.invalidate()
        windowPositionTimer = nil
    }

    func pauseWindowPositionPolling() {
        windowPositionTimer?.invalidate()
        windowPositionTimer = nil
    }

    func resumeWindowPositionPolling() {
        guard windowPositionTimer == nil else { return }
        startWindowPositionPolling()
    }

    private func updateWindowPositions() {
        guard AccessibilityHelper.checkPermissionStatus() == .granted else { return }

        var updated = false
        var appsToRemove: [pid_t] = []

        for (index, var app) in trackedApplications.enumerated() {
            if applicationSourceMode == .dock, !app.isRunning {
                continue
            }

            guard let runningApp = NSRunningApplication.runningApplications(
                withBundleIdentifier: app.bundleIdentifier
            ).first else {
                appsToRemove.append(app.id)
                continue
            }

            if runningApp.isTerminated {
                appsToRemove.append(app.id)
                continue
            }

            let newFrame = AccessibilityHelper.getMainWindowFrame(for: runningApp)

            if newFrame != app.windowFrame {
                app.windowFrame = newFrame
                trackedApplications[index] = app
                updated = true
            }
        }

        if !appsToRemove.isEmpty {
            trackedApplications.removeAll { appsToRemove.contains($0.id) }
            updated = true
        }

        if updated {
            delegate?.applicationsDidUpdate(trackedApplications)
        }
    }

    deinit {
        if isMonitoring {
            windowPositionTimer?.invalidate()
            windowPositionTimer = nil
        }
    }
}
