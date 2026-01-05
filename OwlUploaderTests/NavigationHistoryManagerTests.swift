//
//  NavigationHistoryManagerTests.swift
//  OwlUploaderTests
//
//  NavigationHistoryManager 单元测试
//

import XCTest
@testable import OwlUploader

@MainActor
final class NavigationHistoryManagerTests: XCTestCase {

    func testNavigateToRecordsHistoryAndClearsForward() {
        // Given
        let manager = NavigationHistoryManager()

        // When
        manager.navigateTo("docs/")

        // Then
        XCTAssertEqual(manager.currentPath, "docs/")
        XCTAssertEqual(manager.backStack, [""])
        XCTAssertTrue(manager.forwardStack.isEmpty)
    }

    func testNavigateToSamePathDoesNothing() {
        // Given
        let manager = NavigationHistoryManager(initialPath: "docs/")

        // When
        manager.navigateTo("docs/")

        // Then
        XCTAssertEqual(manager.currentPath, "docs/")
        XCTAssertTrue(manager.backStack.isEmpty)
        XCTAssertTrue(manager.forwardStack.isEmpty)
    }

    func testNavigateToWithoutRecordHistoryKeepsStacks() {
        // Given
        let manager = NavigationHistoryManager(initialPath: "root/")

        // When
        manager.navigateTo("docs/", recordHistory: false)

        // Then
        XCTAssertEqual(manager.currentPath, "docs/")
        XCTAssertTrue(manager.backStack.isEmpty)
        XCTAssertTrue(manager.forwardStack.isEmpty)
    }

    func testGoBackMovesCurrentToForward() {
        // Given
        let manager = NavigationHistoryManager()
        manager.navigateTo("a/")
        manager.navigateTo("b/")

        // When
        let path = manager.goBack()

        // Then
        XCTAssertEqual(path, "a/")
        XCTAssertEqual(manager.currentPath, "a/")
        XCTAssertEqual(manager.backStack, [""])
        XCTAssertEqual(manager.forwardStack, ["b/"])
    }

    func testGoForwardMovesCurrentToBack() {
        // Given
        let manager = NavigationHistoryManager()
        manager.navigateTo("a/")
        manager.navigateTo("b/")
        _ = manager.goBack()

        // When
        let path = manager.goForward()

        // Then
        XCTAssertEqual(path, "b/")
        XCTAssertEqual(manager.currentPath, "b/")
        XCTAssertEqual(manager.backStack, ["", "a/"])
        XCTAssertTrue(manager.forwardStack.isEmpty)
    }

    func testClearHistoryLeavesCurrentPath() {
        // Given
        let manager = NavigationHistoryManager()
        manager.navigateTo("docs/")

        // When
        manager.clearHistory()

        // Then
        XCTAssertEqual(manager.currentPath, "docs/")
        XCTAssertTrue(manager.backStack.isEmpty)
        XCTAssertTrue(manager.forwardStack.isEmpty)
    }

    func testResetClearsHistoryAndSetsPath() {
        // Given
        let manager = NavigationHistoryManager()
        manager.navigateTo("docs/")

        // When
        manager.reset(to: "images/")

        // Then
        XCTAssertEqual(manager.currentPath, "images/")
        XCTAssertTrue(manager.backStack.isEmpty)
        XCTAssertTrue(manager.forwardStack.isEmpty)
    }
}
