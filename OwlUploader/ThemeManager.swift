//
//  ThemeManager.swift
//  OwlUploader
//
//  Theme management for app appearance
//

import Foundation
import SwiftUI

/// App theme options
enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    /// Display name for UI
    var displayName: String {
        switch self {
        case .system: return L.Settings.Theme.followSystem
        case .light: return L.Settings.Theme.light
        case .dark: return L.Settings.Theme.dark
        }
    }

    /// Icon for the theme
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// Convert to SwiftUI ColorScheme
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Theme manager for handling app appearance
@MainActor
class ThemeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ThemeManager()

    // MARK: - Published Properties

    /// Selected theme
    @AppStorage("app_theme") var selectedTheme: String = AppTheme.system.rawValue {
        didSet {
            applyTheme()
        }
    }

    // MARK: - Computed Properties

    /// Current theme enum
    var currentTheme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .system
    }

    /// Color scheme for SwiftUI preferredColorScheme
    var preferredColorScheme: ColorScheme? {
        currentTheme.colorScheme
    }

    // MARK: - Initialization

    private init() {
        applyTheme()
    }

    // MARK: - Methods

    /// Apply the selected theme to the app
    private func applyTheme() {
        let appearance: NSAppearance?
        switch currentTheme {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }
        NSApp.appearance = appearance
    }

    /// Set theme
    func setTheme(_ theme: AppTheme) {
        selectedTheme = theme.rawValue
    }
}
