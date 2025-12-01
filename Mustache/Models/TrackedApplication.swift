//
//  TrackedApplication.swift
//  Mustache
//
//  Numbered App Switcher
//

import AppKit
import Foundation

/// Represents a running application with its metadata and assigned number
struct TrackedApplication: Identifiable, Equatable {
    let id: pid_t // Process ID (0 for non-running apps)
    let bundleIdentifier: String // e.g., "com.apple.Safari"
    let name: String // Display name
    let icon: NSImage // App icon
    var assignedNumber: Int? // 0-9, nil if not assigned
    var assignedKey: String? // Display key: "1"-"9", "0", "a"-"z"
    var isActive: Bool // Currently frontmost
    var windowFrame: CGRect? // Main window position
    var isRunning: Bool // Whether the app is currently running

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id &&
            lhs.bundleIdentifier == rhs.bundleIdentifier &&
            lhs.assignedNumber == rhs.assignedNumber &&
            lhs.assignedKey == rhs.assignedKey &&
            lhs.isActive == rhs.isActive &&
            lhs.isRunning == rhs.isRunning
    }

    /// Convert index to shortcut key string using keyboard sequence
    /// Full keyboard layout: all visible characters in physical keyboard order
    static func shortcutKey(for index: Int) -> String? {
        let keySequence = [
            // Number row (12 keys): 1-9, 0, -, =
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", // 0-11
            // Top letter row (12 keys): q-p, [, ]
            "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]", // 12-23
            // Home row (11 keys): a-l, ;, '
            "a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'", // 24-34
            // Bottom letter row (10 keys): z-m, ,, ., /
            "z", "x", "c", "v", "b", "n", "m", ",", ".", "/", // 35-44
            // Additional keys: `, \
            "`", "\\", // 45-46
        ]

        guard index >= 0, index < keySequence.count else {
            return nil
        }

        return keySequence[index]
    }
}
