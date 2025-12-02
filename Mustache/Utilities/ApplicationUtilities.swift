//
//  ApplicationUtilities.swift
//  Mustache
//

import AppKit
import Foundation
import os.log

enum ApplicationUtilities {
    private static let logger = Logger.make(category: .application)

    static func getDockApplicationBundleIDs() -> [String] {
        guard let dockPlist = UserDefaults.standard.persistentDomain(forName: "com.apple.dock"),
              let persistentApps = dockPlist["persistent-apps"] as? [[String: Any]]
        else {
            logger.error("Failed to read dock preferences")
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

        logger.info("Found \(bundleIDs.count) applications in dock")
        return bundleIDs
    }

    static func getRunningApplications(excludingCurrent: Bool = true) -> [NSRunningApplication] {
        let currentPID = ProcessInfo.processInfo.processIdentifier

        return NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular else { return false }
            guard !app.isTerminated else { return false }
            if excludingCurrent {
                guard app.processIdentifier != currentPID else { return false }
            }
            return true
        }
    }

    static func getApplicationMetadata(bundleIdentifier: String) -> (name: String, url: URL)? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            logger.warning("Could not find app URL for bundle ID: \(bundleIdentifier)")
            return nil
        }

        let appName = FileManager.default.displayName(atPath: appURL.path)
        return (name: appName, url: appURL)
    }

    static func getApplicationIcon(bundleIdentifier: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    static func createTrackedApplication(from runningApp: NSRunningApplication) -> TrackedApplication {
        TrackedApplication(
            id: runningApp.processIdentifier,
            bundleIdentifier: runningApp.bundleIdentifier ?? "unknown",
            name: runningApp.localizedName ?? "Unknown",
            icon: runningApp.icon ?? NSImage(),
            assignedNumber: nil,
            assignedKey: nil,
            isActive: runningApp.isActive,
            windowFrame: nil,
            isRunning: true
        )
    }

    static func createTrackedApplication(bundleIdentifier: String, metadata: (name: String, url: URL)) -> TrackedApplication {
        let icon = NSWorkspace.shared.icon(forFile: metadata.url.path)
        return TrackedApplication(
            id: 0,
            bundleIdentifier: bundleIdentifier,
            name: metadata.name,
            icon: icon,
            assignedNumber: nil,
            assignedKey: nil,
            isActive: false,
            windowFrame: nil,
            isRunning: false
        )
    }
}
