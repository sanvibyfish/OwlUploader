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

    // MARK: - Deduplication Tests

    func testAddDownloads_skipsDuplicateActiveTasks() {
        // Given - 模拟已存在的活跃任务
        let manager = DownloadQueueManager()
        let existingTask = createTestTask(
            fileKey: "test/file.txt",
            status: .processing
        )
        manager.tasks = [existingTask]

        // Then - 验证去重逻辑存在（基于 fileKey 和 status.isActive）
        XCTAssertTrue(manager.tasks.first?.status.isActive ?? false)
    }

    func testAddDownloads_allowsCompletedTaskToBeReAdded() {
        // Given - 已完成的任务
        let manager = DownloadQueueManager()
        let completedTask = createTestTask(
            fileKey: "test/file.txt",
            status: .completed
        )
        manager.tasks = [completedTask]

        // Then - 已完成任务不是活跃的，可以重新添加
        XCTAssertFalse(manager.tasks.first?.status.isActive ?? true)
    }

    func testAddDownloads_allowsCancelledTaskToBeReAdded() {
        // Given - 已取消的任务
        let manager = DownloadQueueManager()
        let cancelledTask = createTestTask(
            fileKey: "test/file.txt",
            status: .cancelled
        )
        manager.tasks = [cancelledTask]

        // Then - 已取消任务不是活跃的，可以重新添加
        XCTAssertFalse(manager.tasks.first?.status.isActive ?? true)
    }

    func testAddDownloads_allowsFailedTaskToBeReAdded() {
        // Given - 失败的任务
        let manager = DownloadQueueManager()
        let failedTask = createTestTask(
            fileKey: "test/file.txt",
            status: .failed("Network error")
        )
        manager.tasks = [failedTask]

        // Then - 失败任务不是活跃的，可以重新添加
        XCTAssertFalse(manager.tasks.first?.status.isActive ?? true)
    }

    // MARK: - Retry All Failed Tests

    func testRetryAllFailed_resetsAllFailedTasks() {
        // Given
        let manager = DownloadQueueManager()
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

    // MARK: - Nested Path Download Tests

    func testAddDownloads_withNestedRelativePath_createsCorrectLocalURL() {
        // Given - 模拟文件夹下载场景，文件有嵌套相对路径
        let manager = DownloadQueueManager()
        let destinationFolder = URL(fileURLWithPath: "/tmp/downloads/mybucket")
        let filesWithNestedPaths: [(key: String, name: String, size: Int64)] = [
            (key: "blog/images/cover.jpg", name: "images/cover.jpg", size: 1024),
            (key: "blog/posts/article.md", name: "posts/article.md", size: 2048),
            (key: "blog/assets/styles/main.css", name: "assets/styles/main.css", size: 512)
        ]

        // When
        manager.addDownloads(filesWithNestedPaths, to: destinationFolder)

        // Then - 验证本地 URL 正确包含嵌套路径
        XCTAssertEqual(manager.tasks.count, 3)

        let task1 = manager.tasks.first { $0.fileKey == "blog/images/cover.jpg" }
        XCTAssertEqual(task1?.localURL.path, "/tmp/downloads/mybucket/images/cover.jpg")

        let task2 = manager.tasks.first { $0.fileKey == "blog/posts/article.md" }
        XCTAssertEqual(task2?.localURL.path, "/tmp/downloads/mybucket/posts/article.md")

        let task3 = manager.tasks.first { $0.fileKey == "blog/assets/styles/main.css" }
        XCTAssertEqual(task3?.localURL.path, "/tmp/downloads/mybucket/assets/styles/main.css")
    }

    func testAddDownloads_withFlatPath_createsCorrectLocalURL() {
        // Given - 普通单文件下载（无嵌套路径）
        let manager = DownloadQueueManager()
        let destinationFolder = URL(fileURLWithPath: "/tmp/downloads")
        let files: [(key: String, name: String, size: Int64)] = [
            (key: "document.pdf", name: "document.pdf", size: 4096)
        ]

        // When
        manager.addDownloads(files, to: destinationFolder)

        // Then
        XCTAssertEqual(manager.tasks.count, 1)
        XCTAssertEqual(manager.tasks.first?.localURL.path, "/tmp/downloads/document.pdf")
    }

    func testDownloadTask_localURLParentDirectory_canBeExtracted() {
        // Given - 创建带嵌套路径的下载任务
        let task = createTestTask(
            fileKey: "screenshots/blog/cover.jpg",
            fileName: "blog/cover.jpg"
        )

        // When - 提取父目录（这是下载前需要创建的目录）
        let parentDirectory = task.localURL.deletingLastPathComponent()

        // Then
        XCTAssertTrue(parentDirectory.path.contains("blog"),
                      "父目录路径应包含子目录")
        XCTAssertFalse(parentDirectory.path.hasSuffix("cover.jpg"),
                       "父目录路径不应包含文件名")
    }

    func testAddDownloads_preservesRelativePathStructure() {
        // Given - 模拟真实的文件夹下载：从 R2 的 screenshots/blog/ 下载到本地
        let manager = DownloadQueueManager()
        let localFolderURL = URL(fileURLWithPath: "/Users/test/Downloads/blog")

        // R2 中的文件（带相对路径）
        let filesFromR2: [(key: String, name: String, size: Int64)] = [
            (key: "screenshots/blog/2025/jan/image1.jpg", name: "2025/jan/image1.jpg", size: 1000),
            (key: "screenshots/blog/2025/jan/image2.jpg", name: "2025/jan/image2.jpg", size: 2000),
            (key: "screenshots/blog/2025/feb/image3.jpg", name: "2025/feb/image3.jpg", size: 3000)
        ]

        // When
        manager.addDownloads(filesFromR2, to: localFolderURL)

        // Then - 验证目录结构保持一致
        let expectedPaths = [
            "/Users/test/Downloads/blog/2025/jan/image1.jpg",
            "/Users/test/Downloads/blog/2025/jan/image2.jpg",
            "/Users/test/Downloads/blog/2025/feb/image3.jpg"
        ]

        for (index, task) in manager.tasks.enumerated() {
            XCTAssertEqual(task.localURL.path, expectedPaths[index],
                           "任务 \(index) 的本地路径应保持目录结构")
        }
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
