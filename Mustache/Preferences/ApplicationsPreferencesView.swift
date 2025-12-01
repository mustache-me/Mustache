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

    /// Show all tracked applications
    var availableApplications: [TrackedApplication] {
        applicationMonitor.trackedApplications
    }

    var body: some View {
        Form {
            // Pinned Applications Section
            Section(header: HStack {
                Text("Pinned Applications (\(preferencesManager.preferences.pinnedApps.count))")
                Spacer()
                Button(action: { showingAddPinnedApp = true }) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Add pinned application")
            }) {
                // Show pinned apps first toggle
                Toggle("Show pinned apps first", isOn: Binding(
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
                ))
                .help("When enabled, pinned apps appear first in the order below")
                .padding(.bottom, 8)

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
                        Text("Always show")
                            .frame(width: 90, alignment: .leading)
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
                Button(action: {
                    applicationMonitor.clearCaches()
                    applicationMonitor.refreshApplicationList()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh application list (clears cache)")
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
                    }
                    .padding(.trailing, 8)
                }
                .frame(height: 250)
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

            // Always show toggle
            Toggle("", isOn: Binding(
                get: {
                    MainActor.assumeIsolated {
                        pinnedApp.alwaysShow
                    }
                },
                set: { newValue in
                    Task { @MainActor in
                        updatePinnedApp(alwaysShow: newValue)
                    }
                }
            ))
            .help("Always show in overlay")
            .frame(width: 90)

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

    private func updatePinnedApp(shortcut: String? = nil, alwaysShow: Bool? = nil) {
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
            if let alwaysShow {
                updated.alwaysShow = alwaysShow
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
                customShortcut: nil,
                alwaysShow: false
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

            // Search field
            TextField("Search applications...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()

            // Content
            if selectedTab == 2 {
                BrowseAppsView(
                    preferencesManager: preferencesManager,
                    isPresented: $isPresented
                )
            } else {
                AppListView(
                    apps: filteredApps,
                    preferencesManager: preferencesManager,
                    isPresented: $isPresented
                )
            }
        }
        .frame(width: 500, height: 400)
    }

    private var filteredApps: [TrackedApplication] {
        let apps = selectedTab == 0 ? runningApps : dockApps
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var runningApps: [TrackedApplication] {
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

    private var dockApps: [TrackedApplication] {
        applicationMonitor.trackedApplications
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
            customShortcut: nil,
            alwaysShow: false
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
        VStack {
            Text("Click to browse for an application")
                .foregroundColor(.secondary)

            Button("Browse...") {
                browseForApp()
            }
        }
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            if let bundle = Bundle(url: url),
               let bundleID = bundle.bundleIdentifier,
               let appName = bundle.infoDictionary?["CFBundleName"] as? String
            {
                let pinnedApp = PinnedApp(
                    bundleIdentifier: bundleID,
                    name: appName,
                    iconPath: url.path,
                    customShortcut: nil,
                    alwaysShow: false
                )
                preferencesManager.preferences.pinnedApps.append(pinnedApp)
                preferencesManager.savePreferences()
                NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
                isPresented = false
            }
        }
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
