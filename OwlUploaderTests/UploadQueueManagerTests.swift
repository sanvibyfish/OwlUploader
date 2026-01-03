//
//  UploadQueueManagerTests.swift
//  OwlUploaderTests
//
//  UploadQueueManager 单元测试
//  测试上传状态、任务管理和队列操作
//

import XCTest
@testable import OwlUploader

final class UploadQueueManagerTests: XCTestCase {

    // MARK: - UploadStatus Tests

    func testUploadStatus_pending_hasCorrectDisplayText() {
        // Given
        let status = UploadStatus.pending

        // Then
        XCTAssertEqual(status.displayText, "等待中")
        XCTAssertEqual(status.iconName, "clock")
    }

    func testUploadStatus_uploading_hasCorrectDisplayText() {
        // Given
        let status = UploadStatus.uploading

        // Then
        XCTAssertEqual(status.displayText, "上传中")
        XCTAssertEqual(status.iconName, "arrow.up.circle")
    }

    func testUploadStatus_completed_hasCorrectDisplayText() {
        // Given
        let status = UploadStatus.completed

        // Then
        XCTAssertEqual(status.displayText, "已完成")
        XCTAssertEqual(status.iconName, "checkmark.circle.fill")
    }

    func testUploadStatus_failed_includesErrorMessage() {
        // Given
        let errorMessage = "网络连接超时"
        let status = UploadStatus.failed(errorMessage)

        // Then
        XCTAssertTrue(status.displayText.contains(errorMessage))
        XCTAssertEqual(status.iconName, "exclamationmark.circle.fill")
    }

    func testUploadStatus_cancelled_hasCorrectDisplayText() {
        // Given
        let status = UploadStatus.cancelled

        // Then
        XCTAssertEqual(status.displayText, "已取消")
        XCTAssertEqual(status.iconName, "xmark.circle")
    }

    // MARK: - UploadStatus Equality Tests

    func testUploadStatus_equality_sameStatusAreEqual() {
        // Given
        let status1 = UploadStatus.pending
        let status2 = UploadStatus.pending

        // Then
        XCTAssertEqual(status1, status2)
    }

    func testUploadStatus_equality_differentStatusAreNotEqual() {
        // Given
        let status1 = UploadStatus.pending
        let status2 = UploadStatus.uploading

        // Then
        XCTAssertNotEqual(status1, status2)
    }

    func testUploadStatus_equality_failedWithSameMessageAreEqual() {
        // Given
        let status1 = UploadStatus.failed("Error")
        let status2 = UploadStatus.failed("Error")

        // Then
        XCTAssertEqual(status1, status2)
    }

    func testUploadStatus_equality_failedWithDifferentMessageAreNotEqual() {
        // Given
        let status1 = UploadStatus.failed("Error 1")
        let status2 = UploadStatus.failed("Error 2")

        // Then
        XCTAssertNotEqual(status1, status2)
    }

    // MARK: - UploadTask Tests

    func testUploadTask_formattedSize_formatsCorrectly() {
        // Given
        let task = createTestTask(fileSize: 1024 * 1024) // 1 MB

        // Then
        XCTAssertFalse(task.formattedSize.isEmpty)
        XCTAssertTrue(task.formattedSize.contains("MB") ||
                     task.formattedSize.contains("1"))
    }

    func testUploadTask_formattedSize_forSmallFile() {
        // Given
        let task = createTestTask(fileSize: 512) // 512 bytes

        // Then
        XCTAssertFalse(task.formattedSize.isEmpty)
    }

    func testUploadTask_formattedSize_forLargeFile() {
        // Given
        let task = createTestTask(fileSize: 1024 * 1024 * 1024 * 2) // 2 GB

        // Then
        XCTAssertFalse(task.formattedSize.isEmpty)
        XCTAssertTrue(task.formattedSize.contains("GB"))
    }

    func testUploadTask_equality_sameIdAndStatusAreEqual() {
        // Given
        let id = UUID()
        var task1 = createTestTask(id: id)
        var task2 = createTestTask(id: id)
        task1.progress = 0.5
        task2.progress = 0.5

        // Then
        XCTAssertEqual(task1, task2)
    }

    func testUploadTask_equality_differentIdAreNotEqual() {
        // Given
        let task1 = createTestTask()
        let task2 = createTestTask()

        // Then
        XCTAssertNotEqual(task1, task2)
    }

    func testUploadTask_equality_sameIdButDifferentProgressAreNotEqual() {
        // Given
        let id = UUID()
        var task1 = createTestTask(id: id)
        var task2 = createTestTask(id: id)
        task1.progress = 0.3
        task2.progress = 0.7

        // Then
        XCTAssertNotEqual(task1, task2)
    }

    func testUploadTask_equality_sameIdButDifferentStatusAreNotEqual() {
        // Given
        let id = UUID()
        var task1 = createTestTask(id: id)
        var task2 = createTestTask(id: id)
        task1.status = .pending
        task2.status = .uploading

        // Then
        XCTAssertNotEqual(task1, task2)
    }

    // MARK: - UploadQueueManager Tests

    @MainActor
    func testUploadQueueManager_initialState_hasNoTasks() {
        // Given
        let manager = UploadQueueManager()

        // Then
        XCTAssertTrue(manager.tasks.isEmpty)
        XCTAssertFalse(manager.isProcessing)
        XCTAssertFalse(manager.isQueuePanelVisible)
    }

    @MainActor
    func testUploadQueueManager_pendingTasks_filtersCorrectly() {
        // Given
        let manager = UploadQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .uploading),
            createTestTask(status: .completed),
            createTestTask(status: .pending)
        ]

        // When
        let pending = manager.pendingTasks

        // Then
        XCTAssertEqual(pending.count, 2)
        XCTAssertTrue(pending.allSatisfy { $0.status == .pending })
    }

    @MainActor
    func testUploadQueueManager_uploadingTasks_filtersCorrectly() {
        // Given
        let manager = UploadQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .uploading),
            createTestTask(status: .uploading),
            createTestTask(status: .completed)
        ]

        // When
        let uploading = manager.uploadingTasks

        // Then
        XCTAssertEqual(uploading.count, 2)
        XCTAssertTrue(uploading.allSatisfy { $0.status == .uploading })
    }

    @MainActor
    func testUploadQueueManager_completedTasks_filtersCorrectly() {
        // Given
        let manager = UploadQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .completed),
            createTestTask(status: .completed),
            createTestTask(status: .completed)
        ]

        // When
        let completed = manager.completedTasks

        // Then
        XCTAssertEqual(completed.count, 3)
        XCTAssertTrue(completed.allSatisfy { $0.status == .completed })
    }

    @MainActor
    func testUploadQueueManager_failedTasks_filtersCorrectly() {
        // Given
        let manager = UploadQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .failed("Error 1")),
            createTestTask(status: .completed),
            createTestTask(status: .failed("Error 2"))
        ]

        // When
        let failed = manager.failedTasks

        // Then
        XCTAssertEqual(failed.count, 2)
    }

    @MainActor
    func testUploadQueueManager_totalProgress_calculatesCorrectly() {
        // Given
        let manager = UploadQueueManager()
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

    @MainActor
    func testUploadQueueManager_totalProgress_withNoTasks_returnsZero() {
        // Given
        let manager = UploadQueueManager()

        // When
        let total = manager.totalProgress

        // Then
        XCTAssertEqual(total, 0)
    }

    @MainActor
    func testUploadQueueManager_hasActiveTasks_withPendingTasks() {
        // Given
        let manager = UploadQueueManager()
        manager.tasks = [createTestTask(status: .pending)]

        // Then
        XCTAssertTrue(manager.hasActiveTasks)
    }

    @MainActor
    func testUploadQueueManager_hasActiveTasks_withUploadingTasks() {
        // Given
        let manager = UploadQueueManager()
        manager.tasks = [createTestTask(status: .uploading)]

        // Then
        XCTAssertTrue(manager.hasActiveTasks)
    }

    @MainActor
    func testUploadQueueManager_hasActiveTasks_withOnlyCompletedTasks() {
        // Given
        let manager = UploadQueueManager()
        manager.tasks = [createTestTask(status: .completed)]

        // Then
        XCTAssertFalse(manager.hasActiveTasks)
    }

    @MainActor
    func testUploadQueueManager_hasActiveTasks_withNoTasks() {
        // Given
        let manager = UploadQueueManager()

        // Then
        XCTAssertFalse(manager.hasActiveTasks)
    }

    // MARK: - cancelTask Tests

    @MainActor
    func testCancelTask_setsStatusToCancelled() {
        // Given
        let manager = UploadQueueManager()
        let task = createTestTask(status: .pending)
        manager.tasks = [task]

        // When
        manager.cancelTask(task)

        // Then
        XCTAssertEqual(manager.tasks.first?.status, .cancelled)
    }

    @MainActor
    func testCancelTask_withNonExistentTask_doesNothing() {
        // Given
        let manager = UploadQueueManager()
        let existingTask = createTestTask(status: .pending)
        let nonExistentTask = createTestTask(status: .pending)
        manager.tasks = [existingTask]

        // When
        manager.cancelTask(nonExistentTask)

        // Then
        XCTAssertEqual(manager.tasks.first?.status, .pending)
    }

    // MARK: - retryTask Tests

    @MainActor
    func testRetryTask_setsStatusToPending() {
        // Given
        let manager = UploadQueueManager()
        var task = createTestTask(status: .failed("Error"))
        task.progress = 0.5
        manager.tasks = [task]

        // When
        manager.retryTask(task)

        // Then
        XCTAssertEqual(manager.tasks.first?.status, .pending)
        XCTAssertEqual(manager.tasks.first?.progress, 0)
    }

    // MARK: - retryAllFailed Tests

    @MainActor
    func testRetryAllFailed_resetsAllFailedTasks() {
        // Given
        let manager = UploadQueueManager()
        var task1 = createTestTask(status: .failed("Error 1"))
        task1.progress = 0.3
        var task2 = createTestTask(status: .completed)
        task2.progress = 1.0
        var task3 = createTestTask(status: .failed("Error 2"))
        task3.progress = 0.7
        manager.tasks = [task1, task2, task3]

        // When
        manager.retryAllFailed()

        // Then
        let pendingCount = manager.tasks.filter { $0.status == .pending }.count
        XCTAssertEqual(pendingCount, 2)
        XCTAssertEqual(manager.tasks[1].status, .completed) // 未改变
    }

    // MARK: - clearCompleted Tests

    @MainActor
    func testClearCompleted_removesOnlyCompletedTasks() {
        // Given
        let manager = UploadQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .completed),
            createTestTask(status: .uploading),
            createTestTask(status: .completed),
            createTestTask(status: .failed("Error"))
        ]

        // When
        manager.clearCompleted()

        // Then
        XCTAssertEqual(manager.tasks.count, 3)
        XCTAssertTrue(manager.completedTasks.isEmpty)
    }

    // MARK: - clearAll Tests

    @MainActor
    func testClearAll_removesAllTasks() {
        // Given
        let manager = UploadQueueManager()
        manager.tasks = [
            createTestTask(status: .pending),
            createTestTask(status: .uploading),
            createTestTask(status: .completed)
        ]
        manager.isQueuePanelVisible = true

        // When
        manager.clearAll()

        // Then
        XCTAssertTrue(manager.tasks.isEmpty)
        XCTAssertFalse(manager.isQueuePanelVisible)
    }

    // MARK: - configure Tests

    @MainActor
    func testConfigure_setsR2ServiceAndBucket() {
        // Given
        let manager = UploadQueueManager()
        let r2Service = R2Service()

        // When
        manager.configure(r2Service: r2Service, bucketName: "test-bucket")

        // Then - 虽然是私有属性，但配置不应抛出错误
        // 配置成功的验证可以通过后续操作来间接验证
    }

    // MARK: - maxConcurrentUploads Tests

    @MainActor
    func testMaxConcurrentUploads_hasDefaultValue() {
        // Given
        // 清除任何之前保存的设置以确保测试独立性
        UserDefaults.standard.removeObject(forKey: "maxConcurrentUploads")
        let manager = UploadQueueManager()

        // Then - 默认值现在是 5
        XCTAssertEqual(manager.maxConcurrentUploads, 5)
    }

    @MainActor
    func testSetMaxConcurrentUploads_storesValueInUserDefaults() {
        // Given
        let testValue = 7

        // When
        UploadQueueManager.setMaxConcurrentUploads(testValue)

        // Then
        let storedValue = UserDefaults.standard.integer(forKey: "maxConcurrentUploads")
        XCTAssertEqual(storedValue, testValue)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "maxConcurrentUploads")
    }

    @MainActor
    func testGetMaxConcurrentUploads_returnsStoredValue() {
        // Given
        let testValue = 8
        UserDefaults.standard.set(testValue, forKey: "maxConcurrentUploads")

        // When
        let result = UploadQueueManager.getMaxConcurrentUploads()

        // Then
        XCTAssertEqual(result, testValue)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "maxConcurrentUploads")
    }

    @MainActor
    func testGetMaxConcurrentUploads_withNoStoredValue_returnsDefault() {
        // Given
        UserDefaults.standard.removeObject(forKey: "maxConcurrentUploads")

        // When
        let result = UploadQueueManager.getMaxConcurrentUploads()

        // Then - 默认值是 5
        XCTAssertEqual(result, 5)
    }

    @MainActor
    func testSetMaxConcurrentUploads_clampsToMaximum() {
        // Given - 尝试设置超过最大值 10 的值
        let testValue = 15

        // When
        UploadQueueManager.setMaxConcurrentUploads(testValue)

        // Then - 应该被限制在 10
        let storedValue = UploadQueueManager.getMaxConcurrentUploads()
        XCTAssertEqual(storedValue, 10)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "maxConcurrentUploads")
    }

    @MainActor
    func testSetMaxConcurrentUploads_clampsToMinimum() {
        // Given - 尝试设置小于最小值 1 的值
        let testValue = 0

        // When
        UploadQueueManager.setMaxConcurrentUploads(testValue)

        // Then - 应该被限制在 1
        let storedValue = UploadQueueManager.getMaxConcurrentUploads()
        XCTAssertEqual(storedValue, 1)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "maxConcurrentUploads")
    }

    @MainActor
    func testMaxConcurrentUploads_readsFromUserDefaults() {
        // Given
        UserDefaults.standard.set(6, forKey: "maxConcurrentUploads")
        let manager = UploadQueueManager()

        // When/Then
        XCTAssertEqual(manager.maxConcurrentUploads, 6)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "maxConcurrentUploads")
    }

    // MARK: - Helper Methods

    private func createTestTask(
        id: UUID = UUID(),
        fileName: String = "test.txt",
        fileSize: Int64 = 1024,
        status: UploadStatus = .pending
    ) -> UploadTask {
        var task = UploadTask(
            id: id,
            fileName: fileName,
            fileSize: fileSize,
            localURL: URL(fileURLWithPath: "/tmp/\(fileName)"),
            remotePath: "uploads/\(fileName)",
            contentType: "text/plain"
        )
        task.status = status
        return task
    }
}
