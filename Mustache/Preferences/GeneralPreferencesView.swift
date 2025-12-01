//
//  GeneralPreferencesView.swift
//  Mustache
//
//  General Preferences Tab
//

import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct GeneralPreferencesView: View {
    @ObservedObject var preferencesManager: PreferencesManager

    var body: some View {
        Form {
            Section(header: Text("Keyboard Shortcut")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Shortcut:")
                            .font(.headline)

                        KeyboardShortcuts.Recorder("", name: .toggleAppSwitcher)
                            .frame(maxWidth: 200)
                    }

                    Text("Press the shortcut, then use any visible keyboard character to switch to applications.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

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

            Section(header: Text("Overlay Layout")) {
                Picker("Layout Mode:", selection: Binding(
                    get: { preferencesManager.preferences.layoutMode },
                    set: { newValue in
                        preferencesManager.preferences.layoutMode = newValue
                        // Update maxTrackedApplications based on mode
                        if newValue == .grid {
                            preferencesManager.preferences.maxTrackedApplications = preferencesManager.preferences.gridRows * preferencesManager.preferences.gridColumns
                        }
                        preferencesManager.savePreferences()
                        NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
                    }
                )) {
                    ForEach(LayoutMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                if preferencesManager.preferences.layoutMode == .dynamic {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Apps arrange automatically row by row based on available screen width.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("Maximum tracked apps: \(preferencesManager.preferences.maxTrackedApplications)")
                            Slider(
                                value: Binding(
                                    get: { Double(preferencesManager.preferences.maxTrackedApplications) },
                                    set: { newValue in
                                        preferencesManager.preferences.maxTrackedApplications = Int(newValue)
                                        preferencesManager.savePreferences()
                                        NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
                                    }
                                ),
                                in: 1 ... 47,
                                step: 1
                            )
                            Spacer()
                        }

                        Text("Full keyboard: 1234567890-= qwertyuiop[] asdfghjkl;' zxcvbnm,./ `\\ (47 keys)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Apps fill a grid with specified dimensions.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("Rows: \(preferencesManager.preferences.gridRows)")
                                .frame(width: 80, alignment: .leading)
                            Slider(
                                value: Binding(
                                    get: { Double(preferencesManager.preferences.gridRows) },
                                    set: { newValue in
                                        preferencesManager.preferences.gridRows = Int(newValue)
                                        preferencesManager.preferences.maxTrackedApplications = preferencesManager.preferences.gridRows * preferencesManager.preferences.gridColumns
                                        preferencesManager.savePreferences()
                                        NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
                                    }
                                ),
                                in: 1 ... 10,
                                step: 1
                            )
                        }

                        HStack {
                            Text("Columns: \(preferencesManager.preferences.gridColumns)")
                                .frame(width: 80, alignment: .leading)
                            Slider(
                                value: Binding(
                                    get: { Double(preferencesManager.preferences.gridColumns) },
                                    set: { newValue in
                                        preferencesManager.preferences.gridColumns = Int(newValue)
                                        preferencesManager.preferences.maxTrackedApplications = preferencesManager.preferences.gridRows * preferencesManager.preferences.gridColumns
                                        preferencesManager.savePreferences()
                                        NotificationCenter.default.post(name: .applicationSourceModeChanged, object: nil)
                                    }
                                ),
                                in: 1 ... 18,
                                step: 1
                            )
                        }

                        Text("Maximum tracked apps: \(preferencesManager.preferences.gridRows * preferencesManager.preferences.gridColumns) (grid capacity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Appearance")) {
                Toggle("Show menu bar icon", isOn: Binding(
                    get: { preferencesManager.preferences.showMenuBarIcon },
                    set: { newValue in
                        preferencesManager.preferences.showMenuBarIcon = newValue
                        preferencesManager.savePreferences()
                        NotificationCenter.default.post(name: .menuBarIconVisibilityChanged, object: nil)
                    }
                ))

                if !preferencesManager.preferences.showMenuBarIcon {
                    Text("Tip: Use Spotlight (⌘Space) to search for 'Mustache' to open settings when the menu bar icon is hidden.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }

            Section(header: Text("Startup")) {
                LaunchAtLogin.Toggle()
            }

            Section {
                Button("Reset to Defaults") {
                    preferencesManager.resetToDefaults()
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}
