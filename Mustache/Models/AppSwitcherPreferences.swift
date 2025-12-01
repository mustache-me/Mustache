import Foundation

enum ApplicationSourceMode: String, Codable, CaseIterable {
    case runningApplications = "Running Applications"
    case dock = "Dock"
}

enum LayoutMode: String, Codable, CaseIterable {
    case dynamic = "Dynamic (Width-Based)"
    case grid = "Grid"
}

struct PinnedApp: Codable, Equatable, Identifiable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let iconPath: String?
    var customShortcut: String?

    var shortcutIndex: Int? {
        guard let shortcut = customShortcut else { return nil }

        let keySequence = [
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=",
            "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]",
            "a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'",
            "z", "x", "c", "v", "b", "n", "m", ",", ".", "/",
            "`", "\\",
        ]

        return keySequence.firstIndex(of: shortcut.lowercased())
    }
}

struct AppSwitcherPreferences: Codable, Equatable {
    var customApplicationOrder: [String]?
    var excludedApplications: Set<String>
    var launchAtLogin: Bool
    var showMenuBarIcon: Bool
    var badgeStyle: BadgeStyle
    var applicationSourceMode: ApplicationSourceMode
    var maxTrackedApplications: Int
    var pinnedApps: [PinnedApp]
    var showPinnedAppsFirst: Bool
    var layoutMode: LayoutMode
    var gridRows: Int
    var gridColumns: Int
    var maxItemsPerRow: Int?

    static var defaults: AppSwitcherPreferences {
        AppSwitcherPreferences(
            customApplicationOrder: nil,
            excludedApplications: [],
            launchAtLogin: false,
            showMenuBarIcon: true,
            badgeStyle: BadgeStyle(),
            applicationSourceMode: .runningApplications,
            maxTrackedApplications: 10,
            pinnedApps: [],
            showPinnedAppsFirst: true,
            layoutMode: .dynamic,
            gridRows: 2,
            gridColumns: 5,
            maxItemsPerRow: nil
        )
    }

    mutating func migrateLegacySettings() {
        if let itemsPerRow = maxItemsPerRow {
            layoutMode = .grid
            gridColumns = itemsPerRow
            gridRows = max(1, (maxTrackedApplications + itemsPerRow - 1) / itemsPerRow)
            maxItemsPerRow = nil
        }
    }
}
