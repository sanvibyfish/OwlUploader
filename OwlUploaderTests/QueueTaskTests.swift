//
//  QueueTaskTests.swift
//  OwlUploaderTests
//
//  QueueTask 协议与默认实现单元测试
//

import XCTest
@testable import OwlUploader

final class QueueTaskTests: XCTestCase {

    private struct TestTask: QueueTaskProtocol {
        let id: UUID
        let displayName: String
        let displayDetail: String
        var progress: Double
        var status: TaskStatus
    }

    private final class TestQueueManager: ObservableObject, TaskQueueManagerProtocol {
        typealias Task = TestTask

        var tasks: [TestTask] = []
        var isProcessing: Bool = false
        var isQueuePanelVisible: Bool = false
        var queueTitle: String = "Queue"
        var processingVerb: String = "Processing"

        func cancelTask(_ task: TestTask) {}
        func retryTask(_ task: TestTask) {}
        func clearCompleted() {}
        func clearAll() {}
    }

    func testOverallProgressPercentCalculatesFromTasks() {
        // Given
        let manager = TestQueueManager()
        manager.tasks = [
            TestTask(id: UUID(), displayName: "a", displayDetail: "", progress: 0.25, status: .pending),
            TestTask(id: UUID(), displayName: "b", displayDetail: "", progress: 0.75, status: .processing)
        ]

        // Then
        XCTAssertEqual(manager.totalProgress, 0.5, accuracy: 0.01)
        XCTAssertEqual(manager.overallProgressPercent, 50)
    }

    func testTaskFiltersFromProtocolExtension() {
        // Given
        let manager = TestQueueManager()
        manager.tasks = [
            TestTask(id: UUID(), displayName: "a", displayDetail: "", progress: 0, status: .pending),
            TestTask(id: UUID(), displayName: "b", displayDetail: "", progress: 0.3, status: .processing),
            TestTask(id: UUID(), displayName: "c", displayDetail: "", progress: 1.0, status: .completed),
            TestTask(id: UUID(), displayName: "d", displayDetail: "", progress: 0, status: .failed("err"))
        ]

        // Then
        XCTAssertEqual(manager.pendingTasks.count, 1)
        XCTAssertEqual(manager.processingTasks.count, 1)
        XCTAssertEqual(manager.completedTasks.count, 1)
        XCTAssertEqual(manager.failedTasks.count, 1)
        XCTAssertTrue(manager.hasActiveTasks)
    }
}
