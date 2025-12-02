//
//  ApplicationsPreferencesView.swift
//  Mustache
//
//  Applications Preferences Tab
//

import Combine
import SwiftUI
import UniformTypeIdentifiers

struct ApplicationsPreferencesView: View {
    @ObservedObject var preferencesManager: PreferencesManager
    @ObservedObject var applicationMonitor: ApplicationMonitor
    @State private var showingAddPinnedApp = false
    @StateObject private var dragState = DragState()
    @State private var availableApplications: [TrackedApplication] = []
    @State private var isLoadingAvailableApps = false

    private func loadAvailableApplications() {
        isLoadingAvailableApps = true
        Task {
            let apps = await loadApplicationsAsync()
            await MainActor.run {
                availableApplications = apps
                isLoadingAvailableApps = false
            }
        }
    }

    private func loadApplicationsAsync() async -> [TrackedApplication] {
        // Get apps in their natural order based on the current mode
        if preferencesManager.preferences.applicationSourceMode == .dock {
            await getDockApplicationsInOrderAsync()
        } else {
            await getRunningApplicationsInOrderAsync()
        }
    }

    private func getDockApplicationsInOrderAsync() async -> [TrackedApplication] {
        await Task.detached {
            await MainActor.run {
                getDockApplicationsInOrder()
            }
        }.value
    }

    private func getRunningApplicationsInOrderAsync() async -> [TrackedApplication] {
        await Task.detached {
            await MainActor.run {
                getRunningApplicationsInOrder()
            }
        }.value
    }

    private func getDockApplicationsInOrder() -> [TrackedApplication] {
        var apps: [TrackedApplication] = []
        var processedBundleIDs = Set<String>()

        // Add Finder first
        let finderBundleID = "com.apple.finder"
        if let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).first,
           !finderApp.isTerminated
        {
            processedBundleIDs.insert(finderBundleID)
            let trackedApp = TrackedApplication(
                id: finderApp.processIdentifier,
                bundleIdentifier: finderBundleID,
                name: finderApp.localizedName ?? "Finder",
                icon: finderApp.icon ?? NSImage(),
                assignedNumber: nil,
                assignedKey: nil,
                isActive: false,
                windowFrame: nil,
                isRunning: true
            )
            apps.append(trackedApp)
        }

        // Get dock apps from system preferences
        guard let dockPlist = UserDefaults.standard.persistentDomain(forName: "com.apple.dock"),
              let persistentApps = dockPlist["persistent-apps"] as? [[String: Any]]
        else {
            return apps
        }

        for app in persistentApps {
            if let tileData = app["tile-data"] as? [String: Any],
               let bundleID = tileData["bundle-identifier"] as? String,
               !processedBundleIDs.contains(bundleID)
            {
                processedBundleIDs.insert(bundleID)

                // Check if app is running
                if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
                   !runningApp.isTerminated
                {
                    let trackedApp = TrackedApplication(
                        id: runningApp.processIdentifier,
                        bundleIdentifier: bundleID,
                        name: runningApp.localizedName ?? "Unknown",
                        icon: runningApp.icon ?? NSImage(),
                        assignedNumber: nil,
                        assignedKey: nil,
                        isActive: false,
                        windowFrame: nil,
                        isRunning: true
                    )
                    apps.append(trackedApp)
                } else {
                    // App is not running, get metadata
                    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                        let appName = FileManager.default.displayName(atPath: appURL.path)
                        let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                        let trackedApp = TrackedApplication(
                            id: 0,
                            bundleIdentifier: bundleID,
                            name: appName,
                            icon: appIcon,
                            assignedNumber: nil,
                            assignedKey: nil,
                            isActive: false,
                            windowFrame: nil,
                            isRunning: false
                        )
                        apps.append(trackedApp)
                    }
                }
            }
        }

        // Add running apps not in dock
        let runningApps = NSWorkspace.shared.runningApplications
        let filteredRunningApps = runningApps.filter { app in
            guard app.activationPolicy == .regular else { return false }
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
            guard !app.isTerminated else { return false }
            guard let bundleID = app.bundleIdentifier else { return false }
            return !processedBundleIDs.contains(bundleID)
        }

        for app in filteredRunningApps {
            let trackedApp = TrackedApplication(
                id: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier ?? "",
                name: app.localizedName ?? "Unknown",
                icon: app.icon ?? NSImage(),
                assignedNumber: nil,
                assignedKey: nil,
                isActive: false,
                windowFrame: nil,
                isRunning: true
            )
            apps.append(trackedApp)
        }

        return apps
    }

    private func getRunningApplicationsInOrder() -> [TrackedApplication] {
        let runningApps = NSWorkspace.shared.runningApplications

        return runningApps
            .filter { app in
                guard app.activationPolicy == .regular else { return false }
                guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
                guard !app.isTerminated else { return false }
                return true
            }
            .map { app in
                TrackedApplication(
                    id: app.processIdentifier,
                    bundleIdentifier: app.bundleIdentifier ?? "unknown",
                    name: app.localizedName ?? "Unknown",
                    icon: app.icon ?? NSImage(),
                    assignedNumber: nil,
                    assignedKey: nil,
                    isActive: app.isActive,
                    windowFrame: nil,
                    isRunning: true
                )
            }
    }

    var body: some View {
        Form {
            // Application Source Section
            Section(header: Text("Application Source")) {
                Picker("Mode:", selection: Binding(
                    get: { preferencesManager.preferences.applicationSourceMode },
                    set: { newValue in
                        preferencesManager.preferences.applicationSourceMode = newValue
                        preferencesManager.savePreferences()
                        NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
                    }
                )) {
                    ForEach(ApplicationSourceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                if preferencesManager.preferences.applicationSourceMode == .runningApplications {
                    Text("Track all running applications with visible windows.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Track applications from your Dock.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Pinned Applications Section
            Section(header: HStack {
                Text("Pinned Applications (\(preferencesManager.preferences.pinnedApps.count))")
                Spacer()

                // Front/Back radio buttons
                Picker("", selection: Binding(
                    get: {
                        MainActor.assumeIsolated {
                            preferencesManager.preferences.showPinnedAppsFirst
                        }
                    },
                    set: { newValue in
                        Task { @MainActor in
                            preferencesManager.preferences.showPinnedAppsFirst = newValue
                            preferencesManager.savePreferences()
                            NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
                        }
                    }
                )) {
                    Text("Front").tag(true)
                    Text("Back").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .help("Position pinned apps at the front or back of the list")

                Button(action: { showingAddPinnedApp = true }) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Add pinned application")
            }) {
                if preferencesManager.preferences.pinnedApps.isEmpty {
                    Text("No pinned applications. Click + to add one.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Column headers
                    HStack(spacing: 12) {
                        Text("App")
                            .frame(width: 32, alignment: .leading)
                        Text("")
                            .frame(width: 120, alignment: .leading)
                        Text("Shortcut")
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Text("Unpin")
                            .frame(width: 40, alignment: .center)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(preferencesManager.preferences.pinnedApps.enumerated()), id: \.element.id) { index, pinnedApp in
                                PinnedAppRow(
                                    pinnedApp: pinnedApp,
                                    preferencesManager: preferencesManager
                                )
                                .onDrag {
                                    dragState.draggedItem = pinnedApp
                                    return NSItemProvider(object: pinnedApp.bundleIdentifier as NSString)
                                }
                                .onDrop(of: [.text], delegate: PinnedAppDropDelegate(
                                    item: pinnedApp,
                                    items: $preferencesManager.preferences.pinnedApps,
                                    preferencesManager: preferencesManager,
                                    dragState: dragState
                                ))

                                if index < preferencesManager.preferences.pinnedApps.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                    .frame(height: 120)
                }
            }

            // Available Applications Section
            Section(header: HStack {
                Text("Available Applications (\(availableApplications.count))")
                Spacer()

                if isLoadingAvailableApps || applicationMonitor.isLoadingApplications {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                }

                Button(action: {
                    applicationMonitor.clearCaches()
                    applicationMonitor.refreshApplicationList()
                    loadAvailableApplications()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh application list (clears cache)")
                .disabled(isLoadingAvailableApps || applicationMonitor.isLoadingApplications)
            }) {
                Text("Applications from \(preferencesManager.preferences.applicationSourceMode.rawValue) mode")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Column headers
                HStack {
                    Text("App")
                        .frame(width: 32, alignment: .leading)
                    Text("")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Shortcut")
                        .frame(width: 60, alignment: .center)
                    Text("Pin")
                        .frame(width: 40, alignment: .center)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 4)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(availableApplications.enumerated()), id: \.element.bundleIdentifier) { index, app in
                            AvailableAppRow(
                                app: app,
                                preferencesManager: preferencesManager,
                                applicationMonitor: applicationMonitor
                            )
                            .padding(.vertical, 4)

                            if index < availableApplications.count - 1 {
                                Divider()
                                    .padding(.horizontal, 8)
                            }
                        }

                        if isLoadingAvailableApps || applicationMonitor.isLoadingApplications, availableApplications.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Loading applications...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.trailing, 8)
                }
                .frame(height: 180)
            }
        }
        .frame(minWidth: 600)
        .padding()
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddPinnedApp) {
            AddPinnedAppSheet(
                preferencesManager: preferencesManager,
                applicationMonitor: applicationMonitor,
                isPresented: $showingAddPinnedApp
            )
        }
        .onAppear {
            // Refresh app list when user opens this view
            applicationMonitor.refreshApplicationList()
            loadAvailableApplications()
        }
        .onChange(of: preferencesManager.preferences.applicationSourceMode) { _, _ in
            loadAvailableApplications()
        }
    }
}

// MARK: - Pinned App Row

struct PinnedAppRow: View {
    let pinnedApp: PinnedApp
    @ObservedObject var preferencesManager: PreferencesManager

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let iconPath = pinnedApp.iconPath {
                let icon = NSWorkspace.shared.icon(forFile: iconPath)
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            }

            // App name
            Text(pinnedApp.name)
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            // Shortcut picker
            Menu {
                Button("Auto") {
                    updatePinnedApp(shortcut: nil)
                }

                Divider()

                ForEach(0 ..< 47) { index in
                    if let key = TrackedApplication.shortcutKey(for: index) {
                        let isOccupied = isShortcutOccupied(key, excluding: pinnedApp.bundleIdentifier)
                        Button(key) {
                            if !isOccupied {
                                updatePinnedApp(shortcut: key)
                            }
                        }
                        .disabled(isOccupied)
                    }
                }
            } label: {
                Text(pinnedApp.customShortcut ?? "Auto")
                    .frame(width: 60, alignment: .leading)
            }
            .frame(width: 80)

            Spacer()

            // Unpin button
            Button(action: unpinApp) {
                Image(systemName: "pin.slash")
            }
            .buttonStyle(.borderless)
            .help("Unpin application")
            .frame(width: 40, alignment: .center)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    private func isShortcutOccupied(_ shortcut: String, excluding bundleID: String) -> Bool {
        preferencesManager.preferences.pinnedApps.contains { app in
            app.bundleIdentifier != bundleID && app.customShortcut == shortcut
        }
    }

    private func updatePinnedApp(shortcut: String? = nil) {
        if let index = preferencesManager.preferences.pinnedApps.firstIndex(where: { $0.id == pinnedApp.id }) {
            var updated = preferencesManager.preferences.pinnedApps[index]

            // Validate shortcut is not already taken
            if let shortcut, isShortcutOccupied(shortcut, excluding: pinnedApp.bundleIdentifier) {
                print("Shortcut \(shortcut) is already taken by another pinned app")
                return
            }

            if let shortcut {
                updated.customShortcut = shortcut
            }
            preferencesManager.preferences.pinnedApps[index] = updated
            preferencesManager.savePreferences()
            NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
        }
    }

    private func unpinApp() {
        preferencesManager.preferences.pinnedApps.removeAll { $0.id == pinnedApp.id }
        preferencesManager.savePreferences()
        NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
    }
}

// MARK: - Available App Row

struct AvailableAppRow: View {
    let app: TrackedApplication
    @ObservedObject var preferencesManager: PreferencesManager
    @ObservedObject var applicationMonitor: ApplicationMonitor

    var isPinned: Bool {
        preferencesManager.preferences.pinnedApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
    }

    var body: some View {
        HStack {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)

            Text(app.name)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(app.assignedKey ?? "")
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(isPinned ? .blue : .secondary)
                .frame(width: 60, alignment: .center)

            Button(action: togglePin) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .foregroundColor(isPinned ? .blue : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isPinned ? "Unpin application" : "Pin application")
            .frame(width: 40, alignment: .center)
        }
        .padding(.horizontal, 8)
    }

    private func togglePin() {
        if isPinned {
            preferencesManager.preferences.pinnedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        } else {
            let iconPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier)?.path
            let pinnedApp = PinnedApp(
                bundleIdentifier: app.bundleIdentifier,
                name: app.name,
                iconPath: iconPath,
                customShortcut: nil
            )
            preferencesManager.preferences.pinnedApps.append(pinnedApp)
        }
        preferencesManager.savePreferences()
        NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
    }
}

// MARK: - Add Pinned App Sheet

struct AddPinnedAppSheet: View {
    @ObservedObject var preferencesManager: PreferencesManager
    @ObservedObject var applicationMonitor: ApplicationMonitor
    @Binding var isPresented: Bool
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var cachedRunningApps: [TrackedApplication] = []
    @State private var cachedDockApps: [TrackedApplication] = []
    @State private var isLoadingApps = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Pinned Application")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
            }
            .padding()

            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Running").tag(0)
                Text("Dock").tag(1)
                Text("Browse").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Search field - only show for Running and Dock tabs
            if selectedTab != 2 {
                TextField("Search applications...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
            }

            // Content
            if selectedTab == 2 {
                BrowseAppsView(
                    preferencesManager: preferencesManager,
                    isPresented: $isPresented
                )
                .padding(50)
                Spacer()
            } else {
                if isLoadingApps, filteredApps.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading applications...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AppListView(
                        apps: filteredApps,
                        preferencesManager: preferencesManager,
                        isPresented: $isPresented
                    )
                }
            }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadAppsForCurrentTab()
        }
        .onChange(of: selectedTab) { _, _ in
            loadAppsForCurrentTab()
        }
    }

    private var filteredApps: [TrackedApplication] {
        let apps = selectedTab == 0 ? cachedRunningApps : cachedDockApps
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadAppsForCurrentTab() {
        isLoadingApps = true
        Task {
            if selectedTab == 0 {
                let apps = await loadRunningAppsAsync()
                await MainActor.run {
                    cachedRunningApps = apps
                    isLoadingApps = false
                }
            } else {
                let apps = await loadDockAppsAsync()
                await MainActor.run {
                    cachedDockApps = apps
                    isLoadingApps = false
                }
            }
        }
    }

    private func loadRunningAppsAsync() async -> [TrackedApplication] {
        await Task.detached {
            await MainActor.run {
                NSWorkspace.shared.runningApplications
                    .filter { $0.activationPolicy == .regular }
                    .map { app in
                        TrackedApplication(
                            id: app.processIdentifier,
                            bundleIdentifier: app.bundleIdentifier ?? "",
                            name: app.localizedName ?? "Unknown",
                            icon: app.icon ?? NSImage(),
                            assignedNumber: nil,
                            assignedKey: nil,
                            isActive: false,
                            windowFrame: nil,
                            isRunning: true
                        )
                    }
            }
        }.value
    }

    private func loadDockAppsAsync() async -> [TrackedApplication] {
        await Task.detached {
            await MainActor.run {
                loadDockApps()
            }
        }.value
    }

    private func loadDockApps() -> [TrackedApplication] {
        // Get dock apps directly, regardless of current application source mode
        var apps: [TrackedApplication] = []
        var processedBundleIDs = Set<String>()

        // Add Finder first
        let finderBundleID = "com.apple.finder"
        if let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).first,
           !finderApp.isTerminated
        {
            processedBundleIDs.insert(finderBundleID)
            let trackedApp = TrackedApplication(
                id: finderApp.processIdentifier,
                bundleIdentifier: finderBundleID,
                name: finderApp.localizedName ?? "Finder",
                icon: finderApp.icon ?? NSImage(),
                assignedNumber: nil,
                assignedKey: nil,
                isActive: false,
                windowFrame: nil,
                isRunning: true
            )
            apps.append(trackedApp)
        }

        // Get dock apps from system preferences
        guard let dockPlist = UserDefaults.standard.persistentDomain(forName: "com.apple.dock"),
              let persistentApps = dockPlist["persistent-apps"] as? [[String: Any]]
        else {
            return apps
        }

        for app in persistentApps {
            if let tileData = app["tile-data"] as? [String: Any],
               let bundleID = tileData["bundle-identifier"] as? String,
               !processedBundleIDs.contains(bundleID)
            {
                processedBundleIDs.insert(bundleID)

                // Check if app is running
                if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
                   !runningApp.isTerminated
                {
                    let trackedApp = TrackedApplication(
                        id: runningApp.processIdentifier,
                        bundleIdentifier: bundleID,
                        name: runningApp.localizedName ?? "Unknown",
                        icon: runningApp.icon ?? NSImage(),
                        assignedNumber: nil,
                        assignedKey: nil,
                        isActive: false,
                        windowFrame: nil,
                        isRunning: true
                    )
                    apps.append(trackedApp)
                } else {
                    // App is not running, get metadata
                    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                        let appName = FileManager.default.displayName(atPath: appURL.path)
                        let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                        let trackedApp = TrackedApplication(
                            id: 0,
                            bundleIdentifier: bundleID,
                            name: appName,
                            icon: appIcon,
                            assignedNumber: nil,
                            assignedKey: nil,
                            isActive: false,
                            windowFrame: nil,
                            isRunning: false
                        )
                        apps.append(trackedApp)
                    }
                }
            }
        }

        return apps
    }
}

struct AppListView: View {
    let apps: [TrackedApplication]
    @ObservedObject var preferencesManager: PreferencesManager
    @Binding var isPresented: Bool

    var body: some View {
        List(apps) { app in
            HStack {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 32, height: 32)

                Text(app.name)

                Spacer()

                Button("Add") {
                    addPinnedApp(app)
                }
                .disabled(isAlreadyPinned(app))
            }
        }
    }

    private func isAlreadyPinned(_ app: TrackedApplication) -> Bool {
        preferencesManager.preferences.pinnedApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
    }

    private func addPinnedApp(_ app: TrackedApplication) {
        let iconPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier)?.path
        let pinnedApp = PinnedApp(
            bundleIdentifier: app.bundleIdentifier,
            name: app.name,
            iconPath: iconPath,
            customShortcut: nil
        )
        preferencesManager.preferences.pinnedApps.append(pinnedApp)
        preferencesManager.savePreferences()
        NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
        isPresented = false
    }
}

struct BrowseAppsView: View {
    @ObservedObject var preferencesManager: PreferencesManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
//            Spacer()

            Button(action: { browseForApp() }) {
                HStack {
                    Image(systemName: "folder")
                    Text("Browse...")
                }
                .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    QuickAccessButton(icon: "folder", title: "Applications") {
                        browseForApp(startingAt: "/Applications")
                    }
                    QuickAccessButton(icon: "wrench.and.screwdriver", title: "Utilities") {
                        browseForApp(startingAt: "/Applications/Utilities")
                    }
                    QuickAccessButton(icon: "house", title: "Home") {
                        browseForApp(startingAt: NSHomeDirectory())
                    }
                }
                HStack(spacing: 8) {
                    QuickAccessButton(icon: "desktopcomputer", title: "Desktop") {
                        browseForApp(startingAt: NSHomeDirectory() + "/Desktop")
                    }
                    QuickAccessButton(icon: "doc", title: "Documents") {
                        browseForApp(startingAt: NSHomeDirectory() + "/Documents")
                    }
                    QuickAccessButton(icon: "arrow.down.circle", title: "Downloads") {
                        browseForApp(startingAt: NSHomeDirectory() + "/Downloads")
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func browseForApp(startingAt path: String = "/Applications") {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: path)
        panel.message = "Select an application to pin"

        if panel.runModal() == .OK, let url = panel.url {
            if let bundle = Bundle(url: url),
               let bundleID = bundle.bundleIdentifier,
               let appName = bundle.infoDictionary?["CFBundleName"] as? String
            {
                let pinnedApp = PinnedApp(
                    bundleIdentifier: bundleID,
                    name: appName,
                    iconPath: url.path,
                    customShortcut: nil
                )
                preferencesManager.preferences.pinnedApps.append(pinnedApp)
                preferencesManager.savePreferences()
                NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
                isPresented = false
            }
        }
    }
}

// MARK: - Quick Access Button

struct QuickAccessButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.caption)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

// MARK: - Drag & Drop Support

class DragState: ObservableObject {
    @Published var draggedItem: PinnedApp?
}

struct PinnedAppDropDelegate: DropDelegate {
    let item: PinnedApp
    @Binding var items: [PinnedApp]
    let preferencesManager: PreferencesManager
    @ObservedObject var dragState: DragState

    func performDrop(info _: DropInfo) -> Bool {
        dragState.draggedItem = nil
        return true
    }

    func dropEntered(info _: DropInfo) {
        guard let draggedItem = dragState.draggedItem else { return }
        guard let fromIndex = items.firstIndex(where: { $0.id == draggedItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }),
              fromIndex != toIndex
        else { return }

        withAnimation {
            let movedItem = items[fromIndex]
            items.remove(at: fromIndex)
            items.insert(movedItem, at: toIndex)
            preferencesManager.savePreferences()
            NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
        }
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
