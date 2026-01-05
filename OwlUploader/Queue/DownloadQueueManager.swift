//
//  DownloadQueueManager.swift
//  OwlUploader
//
//  文件下载队列管理器
//  支持并发下载、分段下载（大文件）、进度追踪
//

import Foundation
import SwiftUI
import Combine

/// 避免与 DownloadQueueTask 冲突的类型别名
private typealias AsyncTask = Task

// MARK: - 下载任务

/// 下载任务
struct DownloadQueueTask: QueueTaskProtocol {
    let id: UUID
    let fileKey: String
    let fileName: String
    let fileSize: Int64
    let localURL: URL
    var progress: Double = 0
    var status: TaskStatus = .pending

    // MARK: - QueueTaskProtocol

    var displayName: String { fileName }

    var displayDetail: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// 格式化大小
    var formattedSize: String { displayDetail }

    static func == (lhs: DownloadQueueTask, rhs: DownloadQueueTask) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.progress == rhs.progress
    }
}

// MARK: - 下载队列管理器

/// 下载队列管理器
@MainActor
class DownloadQueueManager: ObservableObject, TaskQueueManagerProtocol {

    // MARK: - Published Properties

    /// 所有下载任务
    var tasks: [DownloadQueueTask] = []

    /// 是否正在处理队列
    @Published var isProcessing: Bool = false

    /// 队列面板是否显示
    @Published var isQueuePanelVisible: Bool = false

    /// 上次 UI 更新时间（用于节流）
    private var lastUIUpdateTime: Date = .distantPast

    /// UI 更新节流间隔（秒）
    private let uiUpdateThrottleInterval: TimeInterval = 0.1

    // MARK: - TaskQueueManagerProtocol

    var queueTitle: String { L.Files.Toolbar.download }
    var processingVerb: String { "下载中" }

    // MARK: - Private Properties

    /// R2 服务
    private weak var r2Service: R2Service?

    /// 存储桶名称
    private var bucketName: String = ""

    /// 并发下载数量
    private var maxConcurrentDownloads: Int = 3

    /// 当前下载数量
    private var activeDownloadCount: Int = 0

    /// 存储活跃的下载 Task 句柄（用于取消）
    private var activeTasks: [UUID: AsyncTask<Void, Never>] = [:]

    /// 队列完成回调
    var onQueueComplete: (() -> Void)?

    /// 下载中的任务
    var downloadingTasks: [DownloadQueueTask] {
        tasks.filter { $0.status == .processing }
    }

    // MARK: - 速度计算

    /// 开始时间
    private var startTime: Date?

    /// 已下载字节数
    private var totalBytesDownloaded: Int64 = 0

    /// 上次速度计算的字节数
    private var lastSpeedBytes: Int64 = 0

    /// 上次速度计算时间
    private var lastSpeedTime: Date?

    /// 当前下载速度（字节/秒）
    private var currentSpeed: Double = 0

    /// 格式化速度
    var formattedSpeed: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(currentSpeed)))/s"
    }

    /// 预计剩余时间（秒）
    var estimatedTimeRemaining: TimeInterval {
        guard currentSpeed > 0 else { return 0 }
        let remainingBytes = tasks.reduce(Int64(0)) { sum, task in
            if task.status.isActive {
                return sum + Int64(Double(task.fileSize) * (1 - task.progress))
            }
            return sum
        }
        return Double(remainingBytes) / currentSpeed
    }

    /// 格式化剩余时间
    var formattedETA: String {
        let eta = estimatedTimeRemaining
        if eta < 60 {
            return "\(Int(eta))s"
        } else if eta < 3600 {
            return "\(Int(eta / 60))m"
        } else {
            return "\(Int(eta / 3600))h \(Int((eta.truncatingRemainder(dividingBy: 3600)) / 60))m"
        }
    }

    // MARK: - Public Methods

    /// 配置管理器
    func configure(r2Service: R2Service, bucketName: String) {
        self.r2Service = r2Service
        self.bucketName = bucketName
    }

    /// 添加下载任务
    /// - Parameters:
    ///   - files: 要下载的文件列表
    ///   - destinationFolder: 目标文件夹
    func addDownloads(_ files: [(key: String, name: String, size: Int64)], to destinationFolder: URL) {
        print("📥 [Download] 添加 \(files.count) 个下载任务")

        guard !files.isEmpty else {
            print("📥 [Download] 没有文件需要下载，跳过")
            return
        }

        var newTasks: [DownloadQueueTask] = []

        for file in files {
            // 跳过已存在的活跃任务（防止重复添加）
            let existingActiveTask = tasks.first { task in
                task.fileKey == file.key && task.status.isActive
            }
            if existingActiveTask != nil {
                print("⚠️ [Download] 跳过重复任务: \(file.key)")
                continue
            }

            let localURL = destinationFolder.appendingPathComponent(file.name)

            let task = DownloadQueueTask(
                id: UUID(),
                fileKey: file.key,
                fileName: file.name,
                fileSize: file.size,
                localURL: localURL
            )
            newTasks.append(task)
        }

        tasks.append(contentsOf: newTasks)

        // 显示队列面板并触发 UI 更新
        isQueuePanelVisible = true
        objectWillChange.send()

        print("📥 [Download] 任务队列已更新，共 \(tasks.count) 个任务，面板可见: \(isQueuePanelVisible)")

        // 开始处理队列
        processQueue()
    }

    /// 处理队列
    private func processQueue() {
        guard !isProcessing || activeDownloadCount < maxConcurrentDownloads else { return }

        isProcessing = true

        if startTime == nil {
            startTime = Date()
        }

        // 启动下载任务
        while activeDownloadCount < maxConcurrentDownloads {
            guard let taskIndex = tasks.firstIndex(where: { $0.status == .pending }) else {
                break
            }

            let taskId = tasks[taskIndex].id
            tasks[taskIndex].status = .processing
            activeDownloadCount += 1

            let task = tasks[taskIndex]

            // 启动下载任务并存储句柄
            let downloadTask = AsyncTask {
                await self.performDownload(taskId: taskId, task: task)
                self.checkQueueCompletion()
            }
            activeTasks[taskId] = downloadTask
        }
    }

    /// 检查队列是否完成
    private func checkQueueCompletion() {
        let hasActive = tasks.contains { $0.status.isActive }

        if !hasActive {
            isProcessing = false
            startTime = nil
            totalBytesDownloaded = 0
            currentSpeed = 0
            onQueueComplete?()
        } else {
            processQueue()
        }
    }

    /// 执行单个下载任务
    private func performDownload(taskId: UUID, task: DownloadQueueTask) async {
        print("📥 [Download] 开始下载: \(task.fileName)")

        guard let r2Service = r2Service else {
            print("📥 [Download] r2Service 为空，跳过")
            await MainActor.run {
                activeDownloadCount -= 1
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[idx].status = .failed(L.Error.Service.r2NotInitialized)
                }
            }
            return
        }

        do {
            // 使用分段下载
            try await r2Service.downloadObjectChunked(
                bucket: bucketName,
                key: task.fileKey,
                to: task.localURL,
                fileSize: task.fileSize
            ) { bytesDownloaded, totalBytes in
                AsyncTask { @MainActor in
                    if let idx = self.tasks.firstIndex(where: { $0.id == taskId }) {
                        self.tasks[idx].progress = Double(bytesDownloaded) / Double(totalBytes)
                        self.throttledUIUpdate()
                    }
                    // 更新速度
                    self.updateSpeed(bytesDownloaded: bytesDownloaded)
                }
            }

            print("✅ [Download] 下载完成: \(task.fileName)")

            // 更新状态为完成（仅当任务仍在处理中时，避免覆盖已取消状态）
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    if tasks[idx].status == .processing {
                        tasks[idx].progress = 1.0
                        tasks[idx].status = .completed
                    }
                }
                activeDownloadCount -= 1
                activeTasks[taskId] = nil
            }

        } catch {
            print("❌ [Download] 下载失败: \(task.fileName) - \(error.localizedDescription)")
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    // 区分取消和失败
                    if error is CancellationError {
                        tasks[idx].status = .cancelled
                    } else {
                        tasks[idx].status = .failed(error.localizedDescription)
                    }
                }
                activeDownloadCount -= 1
                activeTasks[taskId] = nil
            }
        }
    }

    /// 更新下载速度
    private func updateSpeed(bytesDownloaded: Int64) {
        let now = Date()

        if let lastTime = lastSpeedTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed >= 0.5 {
                let bytesDelta = bytesDownloaded - lastSpeedBytes
                currentSpeed = Double(bytesDelta) / elapsed
                lastSpeedBytes = bytesDownloaded
                lastSpeedTime = now
            }
        } else {
            lastSpeedTime = now
            lastSpeedBytes = bytesDownloaded
        }
    }

    /// 节流 UI 更新
    private func throttledUIUpdate() {
        let now = Date()
        if now.timeIntervalSince(lastUIUpdateTime) >= uiUpdateThrottleInterval {
            lastUIUpdateTime = now
            objectWillChange.send()
        }
    }

    // MARK: - TaskQueueManagerProtocol

    func cancelTask(_ task: DownloadQueueTask) {
        // 取消正在执行的 Task
        activeTasks[task.id]?.cancel()
        activeTasks[task.id] = nil

        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].status = .cancelled
            objectWillChange.send()
        }
    }

    func retryTask(_ task: DownloadQueueTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].status = .pending
            tasks[idx].progress = 0
            objectWillChange.send()
            processQueue()
        }
    }

    func clearCompleted() {
        tasks.removeAll { $0.status.isCompleted || $0.status.isCancelled }
        objectWillChange.send()

        if tasks.isEmpty {
            isQueuePanelVisible = false
        }
    }

    func clearAll() {
        tasks.removeAll()
        activeDownloadCount = 0
        isProcessing = false
        isQueuePanelVisible = false
        objectWillChange.send()
    }

    /// 重试所有失败的任务
    func retryAllFailed() {
        for i in tasks.indices {
            if tasks[i].status.isFailed {
                tasks[i].status = .pending
                tasks[i].progress = 0
            }
        }
        objectWillChange.send()
        processQueue()
    }
}
