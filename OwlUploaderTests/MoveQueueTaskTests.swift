//
//  MoveQueueTaskTests.swift
//  OwlUploaderTests
//
//  MoveQueueTask 单元测试
//

import XCTest
@testable import OwlUploader

final class MoveQueueTaskTests: XCTestCase {

    func testDisplayDetail_withNestedDestinationShowsFolderName() {
        // Given
        let task = MoveQueueTask(
            id: UUID(),
            sourceKey: "source/file.txt",
            destinationKey: "dest/folder/",
            fileName: "file.txt",
            isDirectory: false
        )

        // Then
        XCTAssertEqual(task.displayDetail, "→ folder/")
    }

    func testDisplayDetail_withRootDestinationShowsRoot() {
        // Given
        let task = MoveQueueTask(
            id: UUID(),
            sourceKey: "source/file.txt",
            destinationKey: "file.txt",
            fileName: "file.txt",
            isDirectory: false
        )

        // Then
        XCTAssertEqual(task.displayDetail, "→ \(L.Move.rootDirectory)")
    }
}

// MARK: - MoveError Tests

final class MoveErrorTests: XCTestCase {

    func testMoveError_destinationExists_hasDescription() {
        // Given
        let error = MoveError.destinationExists("folder/file.txt")

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testMoveError_skipped_hasDescription() {
        // Given
        let error = MoveError.skipped("test.txt")

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }
}

// MARK: - ConflictResolution Tests

final class ConflictResolutionTests: XCTestCase {

    func testConflictResolution_allCases() {
        // 确保所有 case 都有 displayName
        for resolution in ConflictResolution.allCases {
            XCTAssertFalse(resolution.displayName.isEmpty, "\(resolution) 应有 displayName")
        }
    }

    func testConflictResolution_skip_displayName() {
        XCTAssertEqual(ConflictResolution.skip.displayName, L.Move.ConflictResolution.skip)
    }

    func testConflictResolution_rename_displayName() {
        XCTAssertEqual(ConflictResolution.rename.displayName, L.Move.ConflictResolution.rename)
    }

    func testConflictResolution_replace_displayName() {
        XCTAssertEqual(ConflictResolution.replace.displayName, L.Move.ConflictResolution.replace)
    }
}

// MARK: - RenamePattern Tests

final class RenamePatternTests: XCTestCase {

    func testRenamePattern_parentheses_appliesCorrectly() {
        // Given
        let pattern = RenamePattern.parentheses

        // When
        let result = pattern.apply(to: "file", number: 1)

        // Then
        XCTAssertEqual(result, "file(1)")
    }

    func testRenamePattern_underscore_appliesCorrectly() {
        // Given
        let pattern = RenamePattern.underscore

        // When
        let result = pattern.apply(to: "file", number: 2)

        // Then
        XCTAssertEqual(result, "file_2")
    }

    func testRenamePattern_dash_appliesCorrectly() {
        // Given
        let pattern = RenamePattern.dash

        // When
        let result = pattern.apply(to: "file", number: 3)

        // Then
        XCTAssertEqual(result, "file-3")
    }

    func testRenamePattern_bracket_appliesCorrectly() {
        // Given
        let pattern = RenamePattern.bracket

        // When
        let result = pattern.apply(to: "file", number: 4)

        // Then
        XCTAssertEqual(result, "file[4]")
    }

    func testRenamePattern_custom_appliesCorrectly() {
        // Given
        let pattern = RenamePattern.custom

        // When
        let result = pattern.apply(to: "file", number: 5, customPattern: "_copy{n}")

        // Then
        XCTAssertEqual(result, "file_copy5")
    }

    func testRenamePattern_custom_withEmptyPattern_usesFallback() {
        // Given
        let pattern = RenamePattern.custom

        // When
        let result = pattern.apply(to: "file", number: 1, customPattern: "")

        // Then
        XCTAssertEqual(result, "file(1)", "空自定义模式应使用默认括号格式")
    }

    func testRenamePattern_preview_showsExample() {
        // Given
        let pattern = RenamePattern.parentheses

        // When
        let preview = pattern.preview()

        // Then
        XCTAssertEqual(preview, "file(1).txt")
    }

    func testRenamePattern_allCases_haveDisplayNames() {
        for pattern in RenamePattern.allCases {
            XCTAssertFalse(pattern.displayName.isEmpty, "\(pattern) 应有 displayName")
        }
    }
}
