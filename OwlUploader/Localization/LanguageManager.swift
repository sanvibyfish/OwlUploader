//
//  LanguageManager.swift
//  OwlUploader
//
//  Language management for app localization
//

import Foundation
import SwiftUI

/// Language manager for handling app localization preferences
@MainActor
class LanguageManager: ObservableObject {

    // MARK: - Singleton

    static let shared = LanguageManager()

    // MARK: - Published Properties

    /// Selected language code
    /// "system" = follow system, "en" = English, "zh-Hans" = Simplified Chinese
    @AppStorage("app_language") var selectedLanguage: String = "system" {
        didSet {
            applyLanguage()
        }
    }

    // MARK: - Properties

    /// Available languages for selection
    let availableLanguages: [(code: String, name: String, nativeName: String)] = [
        ("system", "Follow System", "Follow System"),
        ("en", "English", "English"),
        ("zh-Hans", "Chinese (Simplified)", "简体中文")
    ]

    /// Current locale based on selected language
    var currentLocale: Locale {
        if selectedLanguage == "system" {
            return .current
        }
        return Locale(identifier: selectedLanguage)
    }

    /// Current language code (resolves "system" to actual language)
    var currentLanguageCode: String {
        if selectedLanguage == "system" {
            return Locale.current.language.languageCode?.identifier ?? "en"
        }
        return selectedLanguage
    }

    // MARK: - Initialization

    private init() {
        applyLanguage()
    }

    // MARK: - Methods

    /// Apply the selected language to the app
    private func applyLanguage() {
        guard selectedLanguage != "system" else {
            // Reset to system default
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            return
        }

        // Set the preferred language
        UserDefaults.standard.set([selectedLanguage], forKey: "AppleLanguages")
    }

    /// Get display name for a language code
    func displayName(for code: String) -> String {
        if let language = availableLanguages.first(where: { $0.code == code }) {
            return language.nativeName
        }
        return code
    }

    /// Check if a specific language is selected
    func isSelected(_ code: String) -> Bool {
        return selectedLanguage == code
    }

    /// Check if following system language
    var isFollowingSystem: Bool {
        return selectedLanguage == "system"
    }
}

// MARK: - Language Selection View

struct LanguagePickerView: View {
    @ObservedObject var languageManager = LanguageManager.shared

    var body: some View {
        Picker(L.Settings.selectLanguage, selection: $languageManager.selectedLanguage) {
            ForEach(languageManager.availableLanguages, id: \.code) { language in
                HStack {
                    Text(language.nativeName)
                    if language.code != "system" && language.name != language.nativeName {
                        Text("(\(language.name))")
                            .foregroundColor(.secondary)
                    }
                }
                .tag(language.code)
            }
        }
        .pickerStyle(.menu)
    }
}
