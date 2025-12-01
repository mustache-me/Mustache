//
//  KeyboardShortcutsExtension.swift
//  Mustache
//
//  KeyboardShortcuts integration for app switcher
//

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleAppSwitcher = Self("toggleAppSwitcher", default: .init(.tab, modifiers: [.option]))
}
