//
//  MustacheApp.swift
//  Mustache
//
//  Created by Chunyang Wen on 2025/11/27.
//

import SwiftUI

@main
struct MustacheApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Main window that can be opened via Spotlight
        Window("Mustache", id: "main") {
            if let coordinator = appDelegate.coordinator {
                SettingsView(
                    preferencesManager: coordinator.preferencesManager,
                    applicationMonitor: coordinator.applicationMonitor
                )
            } else {
                EmptyView()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            // Remove "New Window" menu item
            CommandGroup(replacing: .newItem) {}
        }
    }
}
