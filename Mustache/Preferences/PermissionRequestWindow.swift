//
//  PermissionRequestWindow.swift
//  Mustache
//
//  Window for permission request dialog
//

import AppKit
import SwiftUI

class PermissionRequestWindow: NSWindowController {
    private var onOpenSystemPreferences: (() -> Void)?

    convenience init(onOpenSystemPreferences: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Permission Required"
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false

        self.init(window: window)
        self.onOpenSystemPreferences = onOpenSystemPreferences

        setupContent()
    }

    private func setupContent() {
        let permissionView = PermissionRequestView(
            onOpenSystemPreferences: { [weak self] in
                self?.handleOpenSystemPreferences()
            },
            onDismiss: { [weak self] in
                self?.close()
            }
        )

        let hostingView = NSHostingView(rootView: permissionView)
        window?.contentView = hostingView
    }

    private func handleOpenSystemPreferences() {
        onOpenSystemPreferences?()
        close()
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
