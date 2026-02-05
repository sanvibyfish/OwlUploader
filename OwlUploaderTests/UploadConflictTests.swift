//
//  UploadConflictTests.swift
//  OwlUploaderTests
//
//  上传冲突检测相关测试
//  覆盖 UploadConflict 模型、ConflictAction、冲突解决逻辑
//

import XCTest
@testable import OwlUploader

final class UploadConflictTests: XCTestCase {

    // MARK: - ConflictAction Tests

    func testConflictAction_replace_isEquatable() {
        XCTAssertEqual(ConflictAction.replace, ConflictAction.replace)
        XCTAssertNotEqual(ConflictAction.replace, ConflictAction.skip)
    }

    func testConflictAction_keepBoth_isEquatable() {
        XCTAssertEqual(ConflictAction.keepBoth, ConflictAction.keepBoth)
        XCTAssertNotEqual(ConflictAction.keepBoth, ConflictAction.replace)
    }

    func testConflictAction_skip_isEquatable() {
        XCTAssertEqual(ConflictAction.skip, ConflictAction.skip)
        XCTAssertNotEqual(ConflictAction.skip, ConflictAction.keepBoth)
    }

    func testConflictAction_allCasesAreDifferent() {
        let actions: [ConflictAction] = [.replace, .keepBoth, .skip]
        for i in 0..<actions.count {
            for j in (i+1)..<actions.count {
                XCTAssertNotEqual(actions[i], actions[j],
                    "\(actions[i]) 和 \(actions[j]) 应该不相等")
            }
        }
    }

    // MARK: - UploadConflict Model Tests

    func testUploadConflict_hasUniqueId() {
        // Given
        let conflict1 = createTestConflict(fileName: "file1.txt")
        let conflict2 = createTestConflict(fileName: "file2.txt")

        // Then
        XCTAssertNotEqual(conflict1.id, conflict2.id)
    }

    func testUploadConflict_equality_sameIdAreEqual() {
        // Given
        let conflict = createTestConflict(fileName: "test.txt")
        let same = conflict

        // Then
        XCTAssertEqual(conflict, same)
    }

    func testUploadConflict_equality_differentIdAreNotEqual() {
        // Given
        let conflict1 = createTestConflict(fileName: "test.txt")
        let conflict2 = createTestConflict(fileName: "test.txt")

        // Then — 每次创建都生成新的 UUID
        XCTAssertNotEqual(conflict1, conflict2)
    }

    func testUploadConflict_storesLocalFileInfo() {
        // Given
        let url = URL(fileURLWithPath: "/tmp/photo.jpg")
        let modDate = Date()

        // When
        let conflict = UploadConflict(
            localURL: url,
            remotePath: "images/photo.jpg",
            localFileName: "photo.jpg",
            localFileSize: 2_456_789,
            localModDate: modDate,
            remoteFileSize: 1_234_567,
            remoteModDate: Date().addingTimeInterval(-86400)
        )

        // Then
        XCTAssertEqual(conflict.localURL, url)
        XCTAssertEqual(conflict.localFileName, "photo.jpg")
        XCTAssertEqual(conflict.localFileSize, 2_456_789)
        XCTAssertEqual(conflict.localModDate, modDate)
    }

    func testUploadConflict_storesRemoteFileInfo() {
        // Given
        let remoteModDate = Date().addingTimeInterval(-86400)

        // When
        let conflict = UploadConflict(
            localURL: URL(fileURLWithPath: "/tmp/doc.pdf"),
            remotePath: "docs/doc.pdf",
            localFileName: "doc.pdf",
            localFileSize: 5_000_000,
            localModDate: Date(),
            remoteFileSize: 3_000_000,
            remoteModDate: remoteModDate
        )

        // Then
        XCTAssertEqual(conflict.remotePath, "docs/doc.pdf")
        XCTAssertEqual(conflict.remoteFileSize, 3_000_000)
        XCTAssertEqual(conflict.remoteModDate, remoteModDate)
    }

    func testUploadConflict_optionalFieldsCanBeNil() {
        // Given
        let conflict = UploadConflict(
            localURL: URL(fileURLWithPath: "/tmp/file.txt"),
            remotePath: "file.txt",
            localFileName: "file.txt",
            localFileSize: 100,
            localModDate: nil,
            remoteFileSize: nil,
            remoteModDate: nil
        )

        // Then
        XCTAssertNil(conflict.localModDate)
        XCTAssertNil(conflict.remoteFileSize)
        XCTAssertNil(conflict.remoteModDate)
    }

    // MARK: - UploadConflictData Tests

    func testUploadConflictData_wrapsConflicts() {
        // Given
        let conflicts = [
            createTestConflict(fileName: "a.txt"),
            createTestConflict(fileName: "b.txt"),
            createTestConflict(fileName: "c.txt")
        ]

        // When
        let data = UploadConflictData(conflicts: conflicts)

        // Then
        XCTAssertEqual(data.conflicts.count, 3)
        XCTAssertEqual(data.conflicts[0].localFileName, "a.txt")
        XCTAssertEqual(data.conflicts[1].localFileName, "b.txt")
        XCTAssertEqual(data.conflicts[2].localFileName, "c.txt")
    }

    func testUploadConflictData_hasUniqueId() {
        // Given
        let conflicts = [createTestConflict(fileName: "test.txt")]

        // When
        let data1 = UploadConflictData(conflicts: conflicts)
        let data2 = UploadConflictData(conflicts: conflicts)

        // Then
        XCTAssertNotEqual(data1.id, data2.id)
    }

    func testUploadConflictData_isIdentifiable() {
        // Given
        let data = UploadConflictData(conflicts: [])

        // Then — 验证 Identifiable 协议
        let _: UUID = data.id
        XCTAssertNotNil(data.id)
    }

    // MARK: - UploadQueueManager Conflict Callback Tests

    @MainActor
    func testUploadQueueManager_conflictCallback_isNilByDefault() {
        // Given
        let manager = UploadQueueManager()

        // Then
        XCTAssertNil(manager.onConflictsDetected)
    }

    @MainActor
    func testUploadQueueManager_conflictCallback_canBeSet() {
        // Given
        let manager = UploadQueueManager()

        // When
        manager.onConflictsDetected = { conflicts, handler in
            // 模拟用户选择全部跳过
            var resolutions: [UUID: ConflictAction] = [:]
            for conflict in conflicts {
                resolutions[conflict.id] = .skip
            }
            handler(resolutions)
        }

        // Then
        XCTAssertNotNil(manager.onConflictsDetected)
    }

    // MARK: - buildRemotePath Tests（通过 generateUniquePath 间接测试）

    @MainActor
    func testUploadQueueManager_addFilesDirectly_withNoR2Service_doesNotCrash() {
        // Given — 未配置 R2Service 的管理器
        let manager = UploadQueueManager()

        // When — 添加一个不存在的文件（应该被静默跳过）
        manager.addFiles([URL(fileURLWithPath: "/nonexistent/file.txt")], to: "test/")

        // Then — 不应崩溃，任务列表为空（文件不存在）
        XCTAssertTrue(manager.tasks.isEmpty)
    }

    // MARK: - Resolution Map Tests

    func testResolutionMap_canStoreAllActionTypes() {
        // Given
        let conflicts = [
            createTestConflict(fileName: "replace.txt"),
            createTestConflict(fileName: "keep.txt"),
            createTestConflict(fileName: "skip.txt")
        ]

        // When
        var resolutions: [UUID: ConflictAction] = [:]
        resolutions[conflicts[0].id] = .replace
        resolutions[conflicts[1].id] = .keepBoth
        resolutions[conflicts[2].id] = .skip

        // Then
        XCTAssertEqual(resolutions[conflicts[0].id], .replace)
        XCTAssertEqual(resolutions[conflicts[1].id], .keepBoth)
        XCTAssertEqual(resolutions[conflicts[2].id], .skip)
        XCTAssertEqual(resolutions.count, 3)
    }

    func testResolutionMap_applyToAll_setsAllToSameAction() {
        // Given
        let conflicts = (0..<5).map { createTestConflict(fileName: "file\($0).txt") }

        // When — 模拟「应用到全部」
        var resolutions: [UUID: ConflictAction] = [:]
        let selectedAction: ConflictAction = .replace
        for conflict in conflicts {
            resolutions[conflict.id] = selectedAction
        }

        // Then
        XCTAssertEqual(resolutions.count, 5)
        XCTAssertTrue(resolutions.values.allSatisfy { $0 == .replace })
    }

    func testResolutionMap_skipAll_setsAllToSkip() {
        // Given — 模拟用户点击取消
        let conflicts = (0..<3).map { createTestConflict(fileName: "file\($0).txt") }

        // When
        var skipAll: [UUID: ConflictAction] = [:]
        for conflict in conflicts {
            skipAll[conflict.id] = .skip
        }

        // Then
        XCTAssertEqual(skipAll.count, 3)
        XCTAssertTrue(skipAll.values.allSatisfy { $0 == .skip })
    }

    // MARK: - Helper Methods

    private func createTestConflict(
        fileName: String,
        localSize: Int64 = 1024,
        remoteSize: Int64 = 512
    ) -> UploadConflict {
        UploadConflict(
            localURL: URL(fileURLWithPath: "/tmp/\(fileName)"),
            remotePath: "uploads/\(fileName)",
            localFileName: fileName,
            localFileSize: localSize,
            localModDate: Date(),
            remoteFileSize: remoteSize,
            remoteModDate: Date().addingTimeInterval(-3600)
        )
    }
}
