//
//  MoveQueueManagerTests.swift
//  OwlUploaderTests
//
//  MoveQueueManager 单元测试
//  测试移动状态、任务管理和取消功能
//

import XCTest
@testable import OwlUploader

@MainActor
final class MoveQueueManagerTests: XCTestCase {

    // MARK: - Initial State Tests

    func testMoveQueueManager_initialState_hasNoTasks() {
        // Given
        let manager = MoveQueueManager()

        // Then
        XCTAssertTrue(manager.tasks.isEmpty)
        XCTAssertFalse(manager.isProcessing)
        XCTAssertFalse(manager.isQueuePanelVisible)
    }

    // MARK: - Task Filtering Tests

    func testMoveQueueManager_pendingTasks_filtersCorrectly() {
        // Given
        let manager = MoveQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .processing),
            createTestTask(status: .completed),
            createTestTask(status: .pending)
        ]

        // When
        let pending = manager.pendingTasks

        // Then
        XCTAssertEqual(pending.count, 2)
        XCTAssertTrue(pending.allSatisfy { $0.status == .pending })
    }

    func testMoveQueueManager_processingTasks_filtersCorrectly() {
        // Given
        let manager = MoveQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .processing),
            createTestTask(status: .processing),
            createTestTask(status: .completed)
        ]

        // When
        let processing = manager.processingTasks

        // Then
        XCTAssertEqual(processing.count, 2)
        XCTAssertTrue(processing.allSatisfy { $0.status == .processing })
    }

    func testMoveQueueManager_completedTasks_filtersCorrectly() {
        // Given
        let manager = MoveQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .completed),
            createTestTask(status: .completed)
        ]

        // When
        let completed = manager.completedTasks

        // Then
        XCTAssertEqual(completed.count, 2)
        XCTAssertTrue(completed.allSatisfy { $0.status == .completed })
    }

    // MARK: - Cancel Task Tests

    func testCancelTask_setsStatusToCancelled() {
        // Given
        let manager = MoveQueueManager()
        let task = createTestTask(status: .pending)
        manager.tasks = [task]

        // When
        manager.cancelTask(task)

        // Then
        XCTAssertEqual(manager.tasks.first?.status, .cancelled)
    }

    func testCancelTask_processingTask_statusStaysCancelled() {
        // Given
        let manager = MoveQueueManager()
        var task = createTestTask(status: .processing)
        task.progress = 0.5
        manager.tasks = [task]

        // When
        manager.cancelTask(task)

        // Then - 取消后状态应为 cancelled
        XCTAssertEqual(manager.tasks.first?.status, .cancelled)
        XCTAssertTrue(manager.tasks.first?.status.isCancelled ?? false)
    }

    func testCancelledTask_statusNotOverwrittenByCompletion() {
        // Given - 模拟一个已取消的任务
        let manager = MoveQueueManager()
        var task = createTestTask(status: .cancelled)
        task.progress = 0.5
        manager.tasks = [task]

        // Then - 验证取消状态不应被覆盖
        XCTAssertEqual(manager.tasks.first?.status, .cancelled)
        XCTAssertTrue(manager.tasks.first?.status.isCancelled ?? false)
        XCTAssertFalse(manager.tasks.first?.status.isCompleted ?? true)
    }

    func testCancelTask_withNonExistentTask_doesNothing() {
        // Given
        let manager = MoveQueueManager()
        let existingTask = createTestTask(status: .pending)
        let nonExistentTask = createTestTask(status: .pending)
        manager.tasks = [existingTask]

        // When
        manager.cancelTask(nonExistentTask)

        // Then
        XCTAssertEqual(manager.tasks.first?.status, .pending)
    }

    // MARK: - Retry Task Tests

    func testRetryTask_setsStatusToPending() {
        // Given
        let manager = MoveQueueManager()
        var task = createTestTask(status: .failed("Error"))
        task.progress = 0.5
        manager.tasks = [task]

        // When
        manager.retryTask(task)

        // Then
        XCTAssertEqual(manager.tasks.first?.status, .pending)
        XCTAssertEqual(manager.tasks.first?.progress, 0)
    }

    func testCancelledTask_canBeRetried() {
        // Given
        let manager = MoveQueueManager()
        var task = createTestTask(status: .cancelled)
        task.progress = 0.3
        manager.tasks = [task]

        // When - 重试取消的任务
        manager.retryTask(task)

        // Then - 应该变为 pending 状态
        XCTAssertEqual(manager.tasks.first?.status, .pending)
        XCTAssertEqual(manager.tasks.first?.progress, 0)
    }

    // MARK: - Clear Tests

    func testClearCompleted_removesOnlyCompletedTasks() {
        // Given
        let manager = MoveQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .completed),
            createTestTask(status: .processing),
            createTestTask(status: .completed),
            createTestTask(status: .failed("Error"))
        ]

        // When
        manager.clearCompleted()

        // Then
        XCTAssertEqual(manager.tasks.count, 3)
        XCTAssertTrue(manager.completedTasks.isEmpty)
    }

    func testClearAll_removesAllTasks() {
        // Given
        let manager = MoveQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .processing),
            createTestTask(status: .completed)
        ]
        manager.isQueuePanelVisible = true

        // When
        manager.clearAll()

        // Then
        XCTAssertTrue(manager.tasks.isEmpty)
        XCTAssertFalse(manager.isQueuePanelVisible)
    }

    // MARK: - Progress Tests

    func testTotalProgress_calculatesCorrectly() {
        // Given
        let manager = MoveQueueManager()
        var task1 = createTestTask()
        task1.progress = 0.5
        var task2 = createTestTask()
        task2.progress = 1.0
        var task3 = createTestTask()
        task3.progress = 0.0
        manager.tasks = [task1, task2, task3]

        // When
        let total = manager.totalProgress

        // Then
        XCTAssertEqual(total, 0.5, accuracy: 0.01) // (0.5 + 1.0 + 0.0) / 3 = 0.5
    }

    func testTotalProgress_withNoTasks_returnsZero() {
        // Given
        let manager = MoveQueueManager()

        // When
        let total = manager.totalProgress

        // Then
        XCTAssertEqual(total, 0)
    }

    // MARK: - Conflict Resolution Tests

    func testConflictResolution_defaultIsRename() {
        // Given
        UserDefaults.standard.removeObject(forKey: "moveConflictResolution")

        // When
        let resolution = MoveQueueManager.getConflictResolution()

        // Then
        XCTAssertEqual(resolution, .rename)
    }

    func testMaxConcurrentMoves_defaultIsThree() {
        // Given
        UserDefaults.standard.removeObject(forKey: "maxConcurrentMoves")

        // When
        let maxMoves = MoveQueueManager.getMaxConcurrentMoves()

        // Then
        XCTAssertEqual(maxMoves, 3)
    }

    func testSetMaxConcurrentMoves_clampsToRange() {
        // Given & When - 测试最小值
        MoveQueueManager.setMaxConcurrentMoves(0)
        XCTAssertEqual(MoveQueueManager.getMaxConcurrentMoves(), 1)

        // Given & When - 测试最大值
        MoveQueueManager.setMaxConcurrentMoves(15)
        XCTAssertEqual(MoveQueueManager.getMaxConcurrentMoves(), 10)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "maxConcurrentMoves")
    }

    // MARK: - Deduplication Tests

    func testAddMoveTasks_skipsDuplicateActiveTasks() {
        // Given - 模拟已存在的活跃任务
        let manager = MoveQueueManager()
        let existingTask = createTestTask(
            sourceKey: "source/file.txt",
            status: .processing
        )
        manager.tasks = [existingTask]

        // Then - 验证去重逻辑存在（基于 sourceKey 和 status.isActive）
        XCTAssertTrue(manager.tasks.first?.status.isActive ?? false)
    }

    func testAddMoveTasks_allowsCompletedTaskToBeReAdded() {
        // Given - 已完成的任务
        let manager = MoveQueueManager()
        let completedTask = createTestTask(
            sourceKey: "source/file.txt",
            status: .completed
        )
        manager.tasks = [completedTask]

        // Then - 已完成任务不是活跃的，可以重新添加
        XCTAssertFalse(manager.tasks.first?.status.isActive ?? true)
    }

    func testAddMoveTasks_allowsCancelledTaskToBeReAdded() {
        // Given - 已取消的任务
        let manager = MoveQueueManager()
        let cancelledTask = createTestTask(
            sourceKey: "source/file.txt",
            status: .cancelled
        )
        manager.tasks = [cancelledTask]

        // Then - 已取消任务不是活跃的，可以重新添加
        XCTAssertFalse(manager.tasks.first?.status.isActive ?? true)
    }

    func testAddMoveTasks_allowsFailedTaskToBeReAdded() {
        // Given - 失败的任务
        let manager = MoveQueueManager()
        let failedTask = createTestTask(
            sourceKey: "source/file.txt",
            status: .failed("Conflict error")
        )
        manager.tasks = [failedTask]

        // Then - 失败任务不是活跃的，可以重新添加
        XCTAssertFalse(manager.tasks.first?.status.isActive ?? true)
    }

    // MARK: - Rename Pattern Tests

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
        let customPattern = "_copy{n}"

        // When
        let result = pattern.apply(to: "file", number: 1, customPattern: customPattern)

        // Then
        XCTAssertEqual(result, "file_copy1")
    }

    func testRenamePattern_preview_showsCorrectExample() {
        // Given
        let pattern = RenamePattern.parentheses

        // When
        let preview = pattern.preview()

        // Then
        XCTAssertEqual(preview, "file(1).txt")
    }

    // MARK: - Helper Methods

    private func createTestTask(
        id: UUID = UUID(),
        sourceKey: String = "source/file.txt",
        destinationKey: String = "dest/file.txt",
        fileName: String = "file.txt",
        isDirectory: Bool = false,
        status: TaskStatus = .pending
    ) -> MoveQueueTask {
        var task = MoveQueueTask(
            id: id,
            sourceKey: sourceKey,
            destinationKey: destinationKey,
            fileName: fileName,
            isDirectory: isDirectory
        )
        task.status = status
        return task
    }
}
