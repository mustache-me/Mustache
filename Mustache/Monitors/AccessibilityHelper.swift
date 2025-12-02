//
//  AccessibilityHelper.swift
//  Mustache
//

import AppKit
import ApplicationServices
import Foundation
import os.log

class AccessibilityHelper {
    private static let logger = Logger.make(category: .accessibility)
    static func checkPermissionStatus() -> PermissionStatus {
        let trusted = AXIsProcessTrusted()
        let status: PermissionStatus = trusted ? .granted : .denied
        logger.debug("Accessibility permission status: \(status.rawValue)")
        return status
    }

    static func requestPermissions() {
        logger.info("Requesting accessibility permissions")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func enumerateWindows(for app: NSRunningApplication) -> [AXUIElement] {
        guard let pid = app.processIdentifier as pid_t? else {
            return []
        }

        let appElement = AXUIElementCreateApplication(pid)

        var windowList: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowList
        )

        guard result == .success,
              let windows = windowList as? [AXUIElement]
        else {
            return []
        }

        return windows
    }

    static func getWindowFrame(for window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let positionResult = AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &positionValue
        )

        let sizeResult = AXUIElementCopyAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            &sizeValue
        )

        guard positionResult == .success,
              sizeResult == .success,
              let positionValue,
              let sizeValue
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        if AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
           AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        {
            return CGRect(origin: position, size: size)
        }

        return nil
    }

    static func getMainWindowFrame(for app: NSRunningApplication) -> CGRect? {
        let windows = enumerateWindows(for: app)

        for window in windows {
            if isWindowMinimized(window) {
                continue
            }

            if !isStandardWindow(window) {
                continue
            }

            if !isWindowVisible(window) {
                continue
            }

            if let frame = getWindowFrame(for: window) {
                if frame.width > 50, frame.height > 50 {
                    return frame
                }
            }
        }

        return nil
    }

    static func isStandardWindow(_ window: AXUIElement) -> Bool {
        var subroleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXSubroleAttribute as CFString,
            &subroleValue
        )

        guard result == .success, let subrole = subroleValue as? String else {
            return true
        }

        let nonStandardSubroles = [
            "AXDialog",
            "AXSheet",
            "AXSystemDialog",
            "AXFloatingWindow",
            "AXSystemFloatingWindow",
            "AXPopover",
            "AXUnknown",
        ]

        return !nonStandardSubroles.contains(subrole)
    }

    static func isWindowVisible(_ window: AXUIElement) -> Bool {
        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        if titleResult == .success, let title = titleValue as? String, !title.isEmpty {
            return true
        }

        var mainValue: CFTypeRef?
        let mainResult = AXUIElementCopyAttributeValue(
            window,
            kAXMainAttribute as CFString,
            &mainValue
        )

        if mainResult == .success, let isMain = mainValue as? Bool, isMain {
            return true
        }

        return false
    }

    static func hasAnyWindows(for app: NSRunningApplication) -> Bool {
        let windows = enumerateWindows(for: app)
        return !windows.isEmpty
    }

    static func getVisibleWindowCount(for app: NSRunningApplication) -> Int {
        let windows = enumerateWindows(for: app)
        return windows.filter { !isWindowMinimized($0) }.count
    }

    static func errorDescription(for error: AXError) -> String {
        switch error {
        case .success:
            return "Success"
        case .failure:
            return "Generic failure"
        case .illegalArgument:
            return "Illegal argument"
        case .invalidUIElement:
            return "Invalid UI element"
        case .invalidUIElementObserver:
            return "Invalid UI element observer"
        case .cannotComplete:
            return "Cannot complete"
        case .attributeUnsupported:
            return "Attribute unsupported"
        case .actionUnsupported:
            return "Action unsupported"
        case .notificationUnsupported:
            return "Notification unsupported"
        case .notImplemented:
            return "Not implemented"
        case .notificationAlreadyRegistered:
            return "Notification already registered"
        case .notificationNotRegistered:
            return "Notification not registered"
        case .apiDisabled:
            return "Accessibility API disabled - permissions not granted"
        case .noValue:
            return "No value"
        case .parameterizedAttributeUnsupported:
            return "Parameterized attribute unsupported"
        case .notEnoughPrecision:
            return "Not enough precision"
        @unknown default:
            return "Unknown error: \(error.rawValue)"
        }
    }

    static func hasVisibleWindows(for app: NSRunningApplication) -> Bool {
        let windows = enumerateWindows(for: app)
        return !windows.isEmpty
    }

    static func isWindowMinimized(_ window: AXUIElement) -> Bool {
        var minimizedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXMinimizedAttribute as CFString,
            &minimizedValue
        )

        guard result == .success,
              let value = minimizedValue as? Bool
        else {
            return false
        }

        return value
    }
}
