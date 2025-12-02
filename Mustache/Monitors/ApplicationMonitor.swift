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

protocol ApplicationMonitorDelegate: AnyObject {
    func applicationsDidUpdate(_ applications: [TrackedApplication])
    func applicationDidActivate(_ application: TrackedApplication)
}

@MainActor
class ApplicationMonitor: ObservableObject {
    @Published var trackedApplications: [TrackedApplication] = []
    @Published var isLoadingApplications: Bool = false

    weak var delegate: ApplicationMonitorDelegate?
    private var isMonitoring = false
    private var windowPositionTimer: Timer?
    var applicationSourceMode: ApplicationSourceMode = .runningApplications
    var maxTrackedApplications: Int = 10
    var pinnedApps: [PinnedApp] = []
    var showPinnedAppsFirst: Bool = true

    private var iconCache: [String: NSImage] = [:]
    private var metadataCache: [String: (name: String, url: URL)] = [:]
    private var dockAppsCache: [String]?
    private var dockAppsCacheTime: Date?
    private let dockAppsCacheDuration: TimeInterval = 5.0

    private static let logger = Logger.make(category: .monitor)

    init() {}

    func startMonitoring() {
        guard !isMonitoring else {
            Self.logger.debug("Already monitoring, skipping start")
            return
        }
        isMonitoring = true
        Self.logger.info("Started monitoring applications")
        refreshApplicationList()
    }

    func stopMonitoring() {
        guard isMonitoring else {
            Self.logger.debug("Not monitoring, skipping stop")
            return
        }
        isMonitoring = false
        stopWindowPositionPolling()
        Self.logger.info("Stopped monitoring applications")
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
        isLoadingApplications = true
        Self.logger.debug("Refreshing running applications")

        let filteredApps = ApplicationUtilities.getRunningApplications()
        Self.logger.info("Found \(filteredApps.count) running applications")

        var tracked = filteredApps.map { app in
            var trackedApp = ApplicationUtilities.createTrackedApplication(from: app)
            trackedApp.icon = getCachedIcon(for: app)
            return trackedApp
        }

        tracked = sortAndTruncateApplications(tracked)
        tracked = assignShortcuts(to: tracked)

        trackedApplications = tracked
        delegate?.applicationsDidUpdate(tracked)
        isLoadingApplications = false
    }

    private func refreshDockApplications() {
        isLoadingApplications = true
        Self.logger.debug("Refreshing dock applications")

        let persistentDockApps = getDockApplications()
        var dockOrderedApps: [TrackedApplication] = []
        var processedBundleIDs = Set<String>()

        Task { @MainActor in
            let finderBundleID = "com.apple.finder"
            if let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).first,
               !finderApp.isTerminated
            {
                processedBundleIDs.insert(finderBundleID)
                var trackedApp = ApplicationUtilities.createTrackedApplication(from: finderApp)
                trackedApp.icon = getCachedIcon(for: finderApp)
                dockOrderedApps.append(trackedApp)

                let withShortcuts = assignShortcuts(to: dockOrderedApps)
                trackedApplications = withShortcuts
                delegate?.applicationsDidUpdate(withShortcuts)
            }

            for bundleID in persistentDockApps {
                guard !processedBundleIDs.contains(bundleID) else { continue }
                processedBundleIDs.insert(bundleID)

                let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)

                if let runningApp = runningApps.first,
                   runningApp.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                   !runningApp.isTerminated
                {
                    var trackedApp = ApplicationUtilities.createTrackedApplication(from: runningApp)
                    trackedApp.icon = getCachedIcon(for: runningApp)
                    dockOrderedApps.append(trackedApp)
                } else if let metadata = getCachedMetadata(for: bundleID) {
                    var trackedApp = ApplicationUtilities.createTrackedApplication(bundleIdentifier: bundleID, metadata: metadata)
                    trackedApp.icon = getCachedIcon(for: bundleID, appURL: metadata.url)
                    dockOrderedApps.append(trackedApp)
                }

                let withShortcuts = assignShortcuts(to: dockOrderedApps)
                trackedApplications = withShortcuts
                delegate?.applicationsDidUpdate(withShortcuts)
            }

            let filteredRunningApps = ApplicationUtilities.getRunningApplications().filter { app in
                guard let bundleID = app.bundleIdentifier else { return false }
                return !processedBundleIDs.contains(bundleID)
            }

            for app in filteredRunningApps {
                var trackedApp = ApplicationUtilities.createTrackedApplication(from: app)
                trackedApp.icon = getCachedIcon(for: app)
                dockOrderedApps.append(trackedApp)
            }

            var finalTracked = sortAndTruncateApplications(dockOrderedApps)
            finalTracked = assignShortcuts(to: finalTracked)

            trackedApplications = finalTracked
            delegate?.applicationsDidUpdate(finalTracked)
            isLoadingApplications = false
            Self.logger.info("Loaded \(finalTracked.count) dock applications")
        }
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

    private func getCachedMetadata(for bundleID: String) -> (name: String, url: URL)? {
        if let cached = metadataCache[bundleID] {
            return cached
        }

        guard let metadata = ApplicationUtilities.getApplicationMetadata(bundleIdentifier: bundleID) else {
            return nil
        }

        metadataCache[bundleID] = metadata
        return metadata
    }

    func clearCaches() {
        iconCache.removeAll()
        metadataCache.removeAll()
        dockAppsCache = nil
        dockAppsCacheTime = nil
        Self.logger.info("Cleared all application caches")
    }

    private func getDockApplications() -> [String] {
        if let cached = dockAppsCache,
           let cacheTime = dockAppsCacheTime,
           Date().timeIntervalSince(cacheTime) < dockAppsCacheDuration
        {
            Self.logger.debug("Using cached dock applications")
            return cached
        }

        let bundleIDs = ApplicationUtilities.getDockApplicationBundleIDs()
        dockAppsCache = bundleIDs
        dockAppsCacheTime = Date()

        return bundleIDs
    }

    func getApplication(forNumber number: Int) -> TrackedApplication? {
        trackedApplications.first { $0.assignedNumber == number }
    }

    private func sortAndTruncateApplications(_ apps: [TrackedApplication]) -> [TrackedApplication] {
        // Separate pinned and unpinned apps
        let pinnedBundleIDs = Set(pinnedApps.map(\.bundleIdentifier))
        let pinnedAppIndices = Dictionary(uniqueKeysWithValues: pinnedApps.enumerated().map { ($0.element.bundleIdentifier, $0.offset) })

        var pinnedAppsFound: [TrackedApplication] = []
        var unpinnedApps: [TrackedApplication] = []

        for app in apps {
            if pinnedBundleIDs.contains(app.bundleIdentifier) {
                pinnedAppsFound.append(app)
            } else {
                unpinnedApps.append(app)
            }
        }

        // Sort pinned apps by their order in pinnedApps array
        pinnedAppsFound.sort { app1, app2 in
            let index1 = pinnedAppIndices[app1.bundleIdentifier] ?? Int.max
            let index2 = pinnedAppIndices[app2.bundleIdentifier] ?? Int.max
            return index1 < index2
        }

        // Unpinned apps maintain natural order (no sorting needed)

        // Truncate: pinned apps take priority
        let pinnedCount = pinnedAppsFound.count

        if pinnedCount >= maxTrackedApplications {
            // Only show first maxTrackedApplications pinned apps
            let truncatedPinned = Array(pinnedAppsFound.prefix(maxTrackedApplications))
            return showPinnedAppsFirst ? truncatedPinned : truncatedPinned
        } else {
            // Show all pinned apps + fill remaining slots with unpinned apps
            let remainingSlots = maxTrackedApplications - pinnedCount
            let truncatedUnpinned = Array(unpinnedApps.prefix(remainingSlots))

            return showPinnedAppsFirst ? pinnedAppsFound + truncatedUnpinned : truncatedUnpinned + pinnedAppsFound
        }
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

                if nextAvailableIndex < maxTrackedApplications, nextAvailableIndex < 47 {
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
