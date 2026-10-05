//
//  Logger.swift
//  WhosThereios
//

import Foundation
import os

/// App-wide logger that only emits output in DEBUG builds.
/// Replaces raw print() calls to prevent information leakage in production.
enum AppLogger {
    private static let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "WhosThereios", category: "app")

    static func debug(_ message: String) {
        #if DEBUG
        logger.debug("\(message)")
        #endif
    }

    static func error(_ message: String) {
        #if DEBUG
        logger.error("\(message)")
        #endif
    }
}
