import os
//
//  Logger.swift
//  calendar
//
//  Created by Fede Ramirez on 05/04/2026.
//

extension Logger {
    nonisolated static let shared = Logger(subsystem: Constants.subsystem, category: "App")
}
