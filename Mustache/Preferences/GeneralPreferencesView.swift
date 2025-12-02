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
    @State private var showingExportPanel = false
    @State private var showingImportPanel = false
    @State private var showingImportAlert = false
    @State private var importSuccess = false

    var body: some View {
        Form {
            Section(header: Text("General")) {
                VStack(alignment: .leading, spacing: 16) {
                    // Keyboard Shortcut
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

                    Divider()

                    // Launch at Login
                    LaunchAtLogin.Toggle()

                    // Show menu bar icon
                    VStack(alignment: .leading, spacing: 4) {
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
                                .padding(.leading, 20)
                        }
                    }
                }
            }

            Section(header: Text("Backup & Restore")) {
                HStack(spacing: 12) {
                    Button("Export Settings...") {
                        showingExportPanel = true
                    }

                    Button("Import Settings...") {
                        showingImportPanel = true
                    }
                }

                Text("Export your settings to backup or transfer to another Mac. Import to restore settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Button("Reset to Defaults") {
                    preferencesManager.resetToDefaults()
                }
            }
        }
        .padding()
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $showingExportPanel,
            document: SettingsDocument(data: preferencesManager.exportSettings()),
            contentType: .json,
            defaultFilename: "Mustache-Settings-\(dateString()).json"
        ) { result in
            switch result {
            case .success:
                break
            case let .failure(error):
                print("Export failed: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $showingImportPanel,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                let gotAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if gotAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                importSuccess = preferencesManager.importSettingsFromFile(url: url)
                showingImportAlert = true

            case let .failure(error):
                print("Import failed: \(error.localizedDescription)")
                importSuccess = false
                showingImportAlert = true
            }
        }
        .alert(importSuccess ? "Settings Imported" : "Import Failed", isPresented: $showingImportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importSuccess ? "Your settings have been successfully imported." : "Failed to import settings. Please check the file format.")
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Settings Document

import UniformTypeIdentifiers

struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data?

    init(data: Data?) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        guard let data else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
