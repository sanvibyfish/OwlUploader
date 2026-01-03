//
//  UploadQueueManager.swift
//  OwlUploader
//
//  多文件上传队列管理器
//  支持并发上传、进度追踪、暂停/取消操作
//

import Foundation
import SwiftUI
import Combine

/// 避免与 UploadQueueTask 冲突的类型别名
private typealias AsyncTask = Task

/// 上传任务
struct UploadQueueTask: QueueTaskProtocol {
    let id: UUID
    let fileName: String
    let fileSize: Int64
    let localURL: URL
    let remotePath: String
    let contentType: String
    var progress: Double = 0
    var status: TaskStatus = .pending
    var data: Data?  // 缓存的文件数据
    var bytesUploaded: Int64 = 0  // 已上传字节数
    var startTime: Date?  // 开始上传时间

    // MARK: - QueueTaskProtocol

    var displayName: String { fileName }

    var displayDetail: String { formattedSize }

    /// 格式化的文件大小
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    static func == (lhs: UploadQueueTask, rhs: UploadQueueTask) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.progress == rhs.progress
    }
}

/// 上传队列管理器
@MainActor
class UploadQueueManager: ObservableObject, TaskQueueManagerProtocol {

    // MARK: - Published Properties

    /// 所有上传任务（不使用 @Published，手动控制更新时机）
    var tasks: [UploadQueueTask] = []

    /// 是否正在处理队列
    @Published var isProcessing: Bool = false

    /// 队列面板是否显示
    @Published var isQueuePanelVisible: Bool = false

    /// 当前上传速度（字节/秒）- 内部值，通过节流更新
    private var _currentSpeed: Double = 0
    var currentSpeed: Double { _currentSpeed }

    /// 预计剩余时间（秒）- 内部值，通过节流更新
    private var _estimatedTimeRemaining: TimeInterval = 0
    var estimatedTimeRemaining: TimeInterval { _estimatedTimeRemaining }

    // MARK: - TaskQueueManagerProtocol

    var queueTitle: String { L.Upload.Queue.title }
    var processingVerb: String { L.Upload.Status.uploading }

    // MARK: - Configuration

    /// 并发上传数 UserDefaults 键
    private static let concurrentUploadsKey = "maxConcurrentUploads"

    /// 最大并发上传数（从设置读取，默认 5，范围 1-10）
    var maxConcurrentUploads: Int {
        let stored = UserDefaults.standard.integer(forKey: Self.concurrentUploadsKey)
        if stored == 0 {
            return 5 // 默认值
        }
        return min(max(stored, 1), 10) // 限制在 1-10 范围
    }

    /// 设置最大并发上传数
    static func setMaxConcurrentUploads(_ value: Int) {
        let clamped = min(max(value, 1), 10)
        UserDefaults.standard.set(clamped, forKey: concurrentUploadsKey)
    }

    /// 获取当前设置的最大并发上传数（用于 UI 显示）
    static func getMaxConcurrentUploads() -> Int {
        let stored = UserDefaults.standard.integer(forKey: concurrentUploadsKey)
        if stored == 0 {
            return 5 // 默认值
        }
        return min(max(stored, 1), 10)
    }

    // MARK: - Callbacks

    /// 队列完成回调（所有任务完成或失败后触发）
    var onQueueComplete: (() -> Void)?

    // MARK: - Private Properties

    /// 当前正在上传的任务数量
    private var activeUploadCount: Int = 0

    /// R2 服务引用
    private weak var r2Service: R2Service?

    /// 当前存储桶名称
    private var bucketName: String = ""

    /// 速度计算的滑动窗口
    private var speedSamples: [(bytes: Int64, time: Date)] = []

    /// 队列开始时间
    private var queueStartTime: Date?

    /// 已上传的总字节数
    private var totalBytesUploaded: Int64 = 0

    /// 上次 UI 更新时间（用于节流）
    private var lastUIUpdateTime: Date = .distantPast

    /// UI 更新间隔（秒）
    private let uiUpdateInterval: TimeInterval = 1.0

    // MARK: - Computed Properties

    /// 正在上传的任务（兼容旧代码）
    var uploadingTasks: [UploadQueueTask] {
        processingTasks
    }

    /// 总待上传字节数
    var totalBytes: Int64 {
        tasks.reduce(0) { $0 + $1.fileSize }
    }

    /// 已上传字节数
    var uploadedBytes: Int64 {
        tasks.reduce(0) { result, task in
            switch task.status {
            case .completed:
                return result + task.fileSize
            case .processing:
                return result + Int64(Double(task.fileSize) * task.progress)
            default:
                return result
            }
        }
    }

    /// 格式化的上传速度
    var formattedSpeed: String {
        if currentSpeed <= 0 { return "--" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(currentSpeed)))/s"
    }

    /// 格式化的剩余时间
    var formattedETA: String {
        if estimatedTimeRemaining <= 0 || estimatedTimeRemaining.isInfinite {
            return "--"
        }

        let hours = Int(estimatedTimeRemaining) / 3600
        let minutes = (Int(estimatedTimeRemaining) % 3600) / 60
        let seconds = Int(estimatedTimeRemaining) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }

    // MARK: - Public Methods

    /// 配置管理器
    func configure(r2Service: R2Service, bucketName: String) {
        self.r2Service = r2Service
        self.bucketName = bucketName
    }

    /// 添加文件到上传队列
    /// - Parameters:
    ///   - urls: 本地文件 URL 列表
    ///   - prefix: 目标路径前缀
    ///   - baseFolder: 基础文件夹URL（用于计算相对路径保留目录结构）
    func addFiles(_ urls: [URL], to prefix: String, baseFolder: URL? = nil) {
        print("📥 [UploadQueue] addFiles 开始，收到 \(urls.count) 个文件")
        print("📥 [UploadQueue] 当前线程: \(Thread.isMainThread ? "主线程" : "后台线程")")

        // 立即显示队列面板（不等待所有文件添加完成）
        if !urls.isEmpty {
            isQueuePanelVisible = true
        }

        for (index, url) in urls.enumerated() {
            print("📥 [UploadQueue] 处理文件 \(index + 1)/\(urls.count): \(url.lastPathComponent)")

            // 验证文件
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("⚠️ 文件不存在: \(url.path)")
                continue
            }

            do {
                // 获取文件属性（只获取大小，不读取内容）
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0

                // 推断 MIME 类型
                let contentType = inferContentType(from: url)

                // 构建远程路径（保留目录结构）
                let remotePath: String
                if let base = baseFolder {
                    // 计算相对路径：从baseFolder开始保留目录结构
                    let basePath = base.deletingLastPathComponent().path
                    let relativePath = url.path.replacingOccurrences(of: basePath + "/", with: "")

                    var safePrefix = prefix
                    if !safePrefix.isEmpty && !safePrefix.hasSuffix("/") {
                        safePrefix += "/"
                    }

                    remotePath = safePrefix.isEmpty ? relativePath : "\(safePrefix)\(relativePath)"
                } else {
                    var safePrefix = prefix
                    if !safePrefix.isEmpty && !safePrefix.hasSuffix("/") {
                        safePrefix += "/"
                    }

                    remotePath = safePrefix.isEmpty ? url.lastPathComponent : "\(safePrefix)\(url.lastPathComponent)"
                }

                // 创建上传任务（不立即读取文件数据）
                let task = UploadQueueTask(
                    id: UUID(),
                    fileName: url.lastPathComponent,
                    fileSize: fileSize,
                    localURL: url,
                    remotePath: remotePath,
                    contentType: contentType
                )

                tasks.append(task)
                print("✅ [UploadQueue] 添加任务成功: \(task.fileName) (\(task.formattedSize))")

            } catch {
                print("❌ 无法获取文件信息: \(url.path) - \(error.localizedDescription)")
            }
        }

        print("📥 [UploadQueue] addFiles 完成，队列中共 \(tasks.count) 个任务")

        // 开始处理队列
        if !tasks.isEmpty {
            print("📥 [UploadQueue] 准备调用 processQueue")
            processQueue()
            print("📥 [UploadQueue] processQueue 调用完成")
        }
    }

    /// 取消任务
    func cancelTask(_ task: UploadQueueTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].status = .cancelled
        }
    }

    /// 重试失败的任务
    func retryTask(_ task: UploadQueueTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].status = .pending
            tasks[index].progress = 0
            processQueue()
        }
    }

    /// 重试所有失败的任务
    func retryAllFailed() {
        for index in tasks.indices {
            if case .failed = tasks[index].status {
                tasks[index].status = .pending
                tasks[index].progress = 0
            }
        }
        processQueue()
    }

    /// 清除已完成的任务
    func clearCompleted() {
        tasks.removeAll { $0.status.isCompleted }
    }

    /// 清除所有任务
    func clearAll() {
        // 取消所有进行中的任务
        for index in tasks.indices {
            if tasks[index].status == .pending || tasks[index].status == .processing {
                tasks[index].status = .cancelled
            }
        }
        tasks.removeAll()
        isQueuePanelVisible = false
    }

    // MARK: - Private Methods

    /// 处理上传队列
    private func processQueue() {
        print("🔄 [UploadQueue] processQueue 进入")
        guard !isProcessing else {
            print("🔄 [UploadQueue] 已在处理中，跳过")
            return
        }
        isProcessing = true
        queueStartTime = Date()
        speedSamples.removeAll()
        totalBytesUploaded = 0
        print("🔄 [UploadQueue] 开始处理队列，待处理任务: \(pendingTasks.count)，并发数: \(maxConcurrentUploads)")

        AsyncTask { @MainActor in
            print("🔄 [UploadQueue] Task 开始执行")
            var loopCount = 0
            while hasActiveTasks {
                loopCount += 1
                if loopCount % 20 == 1 {
                    print("🔄 [UploadQueue] 循环 #\(loopCount), pending: \(pendingTasks.count), uploading: \(uploadingTasks.count), active: \(activeUploadCount)")
                }

                // 检查是否可以启动新任务（真正的并发：不等待上传完成）
                while activeUploadCount < maxConcurrentUploads,
                      let nextTask = pendingTasks.first {
                    // 立即标记为 processing，防止重复选择
                    if let index = tasks.firstIndex(where: { $0.id == nextTask.id }) {
                        tasks[index].status = .processing
                        tasks[index].startTime = Date()
                    }
                    activeUploadCount += 1
                    print("🔄 [UploadQueue] 启动任务: \(nextTask.fileName)，当前并发: \(activeUploadCount)")

                    // 启动上传任务但不等待完成（真正的并发）
                    let taskId = nextTask.id
                    AsyncTask {
                        await self.performUpload(taskId: taskId, task: nextTask)
                    }
                }

                // 更新速度和ETA
                updateSpeedAndETA()

                // 等待一小段时间再检查
                try? await AsyncTask.sleep(nanoseconds: 500_000_000) // 0.5秒
            }

            print("🔄 [UploadQueue] 队列处理完成")
            // 完成后重置
            _currentSpeed = 0
            _estimatedTimeRemaining = 0
            isProcessing = false

            // 最终 UI 更新
            objectWillChange.send()

            // 触发完成回调（刷新文件列表等）
            if completedTasks.count > 0 {
                print("🔄 [UploadQueue] 触发完成回调，\(completedTasks.count) 个任务已完成")
                onQueueComplete?()
            }
        }
        print("🔄 [UploadQueue] processQueue 退出（Task已启动）")
    }

    /// 更新速度和剩余时间计算
    private func updateSpeedAndETA() {
        let now = Date()
        let currentUploaded = uploadedBytes

        // 添加新样本
        speedSamples.append((bytes: currentUploaded, time: now))

        // 只保留最近5秒的样本
        speedSamples = speedSamples.filter { now.timeIntervalSince($0.time) <= 5 }

        // 节流：只有超过更新间隔才更新 UI
        guard now.timeIntervalSince(lastUIUpdateTime) >= uiUpdateInterval else {
            return
        }
        lastUIUpdateTime = now

        // 计算速度（使用滑动窗口平均）
        if speedSamples.count >= 2 {
            let oldest = speedSamples.first!
            let newest = speedSamples.last!
            let bytesTransferred = newest.bytes - oldest.bytes
            let timeElapsed = newest.time.timeIntervalSince(oldest.time)

            if timeElapsed > 0 {
                _currentSpeed = Double(bytesTransferred) / timeElapsed
            }
        }

        // 计算剩余时间
        if _currentSpeed > 0 {
            let remainingBytes = totalBytes - currentUploaded
            _estimatedTimeRemaining = Double(remainingBytes) / _currentSpeed
        } else {
            _estimatedTimeRemaining = 0
        }

        // 手动触发 UI 更新（批量更新：任务状态 + 速度 + 剩余时间）
        objectWillChange.send()
    }

    /// 执行单个上传任务（由 processQueue 并发调用）
    /// - Parameters:
    ///   - taskId: 任务 ID
    ///   - task: 上传任务
    private func performUpload(taskId: UUID, task: UploadQueueTask) async {
        print("⬆️ [Upload] performUpload 开始: \(task.fileName)")

        guard let r2Service = r2Service else {
            print("⬆️ [Upload] r2Service 为空，跳过")
            await MainActor.run {
                activeUploadCount -= 1
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[idx].status = .failed("R2 服务未初始化")
                }
            }
            return
        }

        do {
            // 在后台线程读取文件数据
            // 注意：需要在读取时处理安全作用域权限
            let data = try await AsyncTask.detached(priority: .userInitiated) {
                // 获取安全作用域权限
                let needsSecurityScope = task.localURL.startAccessingSecurityScopedResource()

                defer {
                    if needsSecurityScope {
                        task.localURL.stopAccessingSecurityScopedResource()
                    }
                }

                let fileData = try Data(contentsOf: task.localURL)
                return fileData
            }.value
            print("⬆️ [Upload] 文件数据读取完成: \(task.fileName), \(data.count) bytes")

            // 检查是否已取消
            let isCancelled = await MainActor.run {
                guard let currentIndex = tasks.firstIndex(where: { $0.id == taskId }) else {
                    return true
                }
                if tasks[currentIndex].status != .processing {
                    return true
                }
                // 更新进度为10%（文件读取完成）
                tasks[currentIndex].progress = 0.1
                return false
            }

            if isCancelled {
                print("⬆️ [Upload] 任务已取消，跳过上传: \(task.fileName)")
                await MainActor.run { activeUploadCount -= 1 }
                return
            }

            // 执行上传
            print("⬆️ [Upload] 开始上传到 R2: \(task.remotePath)")
            try await r2Service.uploadData(
                bucket: bucketName,
                key: task.remotePath,
                data: data,
                contentType: task.contentType
            )
            print("✅ [Upload] 上传完成: \(task.fileName)")

            // 更新状态为完成
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[idx].progress = 1.0
                    tasks[idx].status = .completed
                }
                activeUploadCount -= 1
            }

        } catch {
            print("❌ [Upload] 上传失败: \(task.fileName) - \(error.localizedDescription)")
            // 更新失败状态
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[idx].status = .failed(error.localizedDescription)
                }
                activeUploadCount -= 1
            }
        }

        print("⬆️ [Upload] performUpload 结束: \(task.fileName)")
    }

    /// 推断文件的 MIME 类型
    private func inferContentType(from url: URL) -> String {
        let ext = url.pathExtension.lowercased()

        let mimeTypes: [String: String] = [
            // 图片
            "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
            "gif": "image/gif", "webp": "image/webp", "svg": "image/svg+xml",
            "ico": "image/x-icon", "bmp": "image/bmp",
            // 视频
            "mp4": "video/mp4", "mov": "video/quicktime", "avi": "video/x-msvideo",
            "mkv": "video/x-matroska", "webm": "video/webm",
            // 音频
            "mp3": "audio/mpeg", "wav": "audio/wav", "flac": "audio/flac",
            "aac": "audio/aac", "ogg": "audio/ogg",
            // 文档
            "pdf": "application/pdf", "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "ppt": "application/vnd.ms-powerpoint",
            "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "txt": "text/plain", "csv": "text/csv", "html": "text/html",
            "css": "text/css", "js": "application/javascript", "json": "application/json",
            "xml": "application/xml",
            // 压缩
            "zip": "application/zip", "rar": "application/vnd.rar",
            "7z": "application/x-7z-compressed", "tar": "application/x-tar",
            "gz": "application/gzip"
        ]

        return mimeTypes[ext] ?? "application/octet-stream"
    }
}
