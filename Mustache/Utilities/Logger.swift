//
//  Logger.swift
//  Mustache
//

import Foundation
import os.log

enum LogCategory: String {
    case application = "Application"
    case coordinator = "Coordinator"
    case monitor = "Monitor"
    case preferences = "Preferences"
    case rendering = "Rendering"
    case accessibility = "Accessibility"
    case statistics = "Statistics"
}

extension Logger {
    private static let subsystem = "com.mustache.app"

    static func make(category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
