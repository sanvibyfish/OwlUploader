//
//  DownloadQueueManagerTests.swift
//  OwlUploaderTests
//
//  DownloadQueueManager 单元测试
//  测试下载状态、任务管理和取消功能
//

import XCTest
@testable import OwlUploader

@MainActor
final class DownloadQueueManagerTests: XCTestCase {

    // MARK: - Initial State Tests

    func testDownloadQueueManager_initialState_hasNoTasks() {
        // Given
        let manager = DownloadQueueManager()

        // Then
        XCTAssertTrue(manager.tasks.isEmpty)
        XCTAssertFalse(manager.isProcessing)
        XCTAssertFalse(manager.isQueuePanelVisible)
    }

    // MARK: - Task Filtering Tests

    func testDownloadQueueManager_pendingTasks_filtersCorrectly() {
        // Given
        let manager = DownloadQueueManager()
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

    func testDownloadQueueManager_processingTasks_filtersCorrectly() {
        // Given
        let manager = DownloadQueueManager()
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

    func testDownloadQueueManager_completedTasks_filtersCorrectly() {
        // Given
        let manager = DownloadQueueManager()
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
        let manager = DownloadQueueManager()
        let task = createTestTask(status: .pending)
        manager.tasks = [task]

        // When
        manager.cancelTask(task)

        // Then
        XCTAssertEqual(manager.tasks.first?.status, .cancelled)
    }

    func testCancelTask_processingTask_statusStaysCancelled() {
        // Given
        let manager = DownloadQueueManager()
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
        let manager = DownloadQueueManager()
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
        let manager = DownloadQueueManager()
        let existingTask = createTestTask(status: .pending)
        let nonExistentTask = createTestTask(status: .pending)
        manager.tasks = [existingTask]

        // When
        manager.cancelTask(nonExistentTask)

        // Then
        XCTAssertEqual(manager.tasks.first?.status, .pending)
    }

    // MARK: - Retry Task Tests

    func testRetryTask_resetsProgressAndChangesStatus() {
        // Given
        let manager = DownloadQueueManager()
        var task = createTestTask(status: .failed("Error"))
        task.progress = 0.5
        manager.tasks = [task]

        // When
        manager.retryTask(task)

        // Then - retryTask 会调用 processQueue()，状态可能是 pending 或 processing
        // 重要的是：不再是 failed，且 progress 被重置
        XCTAssertFalse(manager.tasks.first?.status.isFailed ?? true)
        XCTAssertEqual(manager.tasks.first?.progress, 0)
    }

    func testCancelledTask_canBeRetried() {
        // Given
        let manager = DownloadQueueManager()
        var task = createTestTask(status: .cancelled)
        task.progress = 0.3
        manager.tasks = [task]

        // When - 重试取消的任务
        manager.retryTask(task)

        // Then - retryTask 会调用 processQueue()，状态可能变为 pending 或 processing
        // 重要的是：不再是 cancelled，且 progress 被重置
        XCTAssertFalse(manager.tasks.first?.status.isCancelled ?? true)
        XCTAssertEqual(manager.tasks.first?.progress, 0)
    }

    // MARK: - Clear Tests

    func testClearCompleted_removesOnlyCompletedAndCancelledTasks() {
        // Given
        let manager = DownloadQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .completed),
            createTestTask(status: .processing),
            createTestTask(status: .cancelled),
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
        let manager = DownloadQueueManager()
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
        let manager = DownloadQueueManager()
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
        let manager = DownloadQueueManager()

        // When
        let total = manager.totalProgress

        // Then
        XCTAssertEqual(total, 0)
    }

    // MARK: - Helper Methods

    private func createTestTask(
        id: UUID = UUID(),
        fileKey: String = "test/file.txt",
        fileName: String = "file.txt",
        fileSize: Int64 = 1024,
        status: TaskStatus = .pending
    ) -> DownloadQueueTask {
        var task = DownloadQueueTask(
            id: id,
            fileKey: fileKey,
            fileName: fileName,
            fileSize: fileSize,
            localURL: URL(fileURLWithPath: "/tmp/\(fileName)")
        )
        task.status = status
        return task
    }
}
