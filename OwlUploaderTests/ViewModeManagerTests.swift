//
//  ViewModeManagerTests.swift
//  OwlUploaderTests
//
//  ViewModeManager 单元测试
//

import XCTest
@testable import OwlUploader

@MainActor
final class ViewModeManagerTests: XCTestCase {

    private let defaults = UserDefaults.standard
    private let preferenceKeys = [
        "fileViewMode",
        "iconSize",
        "showPreviewPanel",
        "showFileExtensions",
        "showDateColumn",
        "showSizeColumn",
        "showTypeColumn"
    ]

    override func setUpWithError() throws {
        try super.setUpWithError()
        clearPreferences()
    }

    override func tearDownWithError() throws {
        clearPreferences()
        try super.tearDownWithError()
    }

    private func clearPreferences() {
        for key in preferenceKeys {
            defaults.removeObject(forKey: key)
        }
    }

    func testDefaultsWhenUserDefaultsEmpty() {
        // Given
        let manager = ViewModeManager()

        // Then
        XCTAssertEqual(manager.currentMode, .table)
        XCTAssertEqual(manager.iconSize, .medium)
        XCTAssertFalse(manager.showPreviewPanel)
        XCTAssertTrue(manager.showFileExtensions)
        XCTAssertTrue(manager.showDateColumn)
        XCTAssertTrue(manager.showSizeColumn)
        XCTAssertFalse(manager.showTypeColumn)
    }

    func testToggleModeSwitchesBetweenTableAndIcons() {
        // Given
        let manager = ViewModeManager()
        XCTAssertEqual(manager.currentMode, .table)

        // When
        manager.toggleMode()

        // Then
        XCTAssertEqual(manager.currentMode, .icons)

        // When
        manager.toggleMode()

        // Then
        XCTAssertEqual(manager.currentMode, .table)
    }

    func testIncreaseDecreaseIconSize() {
        // Given
        let manager = ViewModeManager()
        XCTAssertEqual(manager.iconSize, .medium)

        // When
        manager.increaseIconSize()

        // Then
        XCTAssertEqual(manager.iconSize, .large)

        // When
        manager.decreaseIconSize()

        // Then
        XCTAssertEqual(manager.iconSize, .medium)
    }

    func testPreferencesPersistAcrossInstances() {
        // Given
        let manager = ViewModeManager()

        // When
        manager.setMode(.icons)
        manager.iconSize = .large
        manager.togglePreviewPanel()

        // Then
        let reloaded = ViewModeManager()
        XCTAssertEqual(reloaded.currentMode, .icons)
        XCTAssertEqual(reloaded.iconSize, .large)
        XCTAssertTrue(reloaded.showPreviewPanel)
    }
}
