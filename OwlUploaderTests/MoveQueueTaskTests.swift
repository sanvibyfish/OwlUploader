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
        XCTAssertEqual(task.displayDetail, "→ 根目录")
    }
}
