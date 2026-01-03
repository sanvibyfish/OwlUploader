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

/// 上传任务状态
enum UploadStatus: Equatable {
    case pending      // 等待中
    case uploading    // 上传中
    case completed    // 已完成
    case failed(String)  // 失败（附带错误信息）
    case cancelled    // 已取消

    var displayText: String {
        switch self {
        case .pending: return L.Upload.Status.pending
        case .uploading: return L.Upload.Status.uploading
        case .completed: return L.Upload.Status.completed
        case .failed(let error): return L.Upload.Status.failed(error)
        case .cancelled: return L.Upload.Status.cancelled
        }
    }
    
    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .uploading: return "arrow.up.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .pending: return .secondary
        case .uploading: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

/// 上传任务
struct UploadTask: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let fileSize: Int64
    let localURL: URL
    let remotePath: String
    let contentType: String
    var progress: Double = 0
    var status: UploadStatus = .pending
    var data: Data?  // 缓存的文件数据
    var bytesUploaded: Int64 = 0  // 已上传字节数
    var startTime: Date?  // 开始上传时间

    /// 格式化的文件大小
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    static func == (lhs: UploadTask, rhs: UploadTask) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.progress == rhs.progress
    }
}

/// 上传队列管理器
@MainActor
class UploadQueueManager: ObservableObject {
    
    // MARK: - Published Properties

    /// 所有上传任务
    @Published var tasks: [UploadTask] = []

    /// 是否正在处理队列
    @Published var isProcessing: Bool = false

    /// 队列面板是否显示
    @Published var isQueuePanelVisible: Bool = false

    /// 当前上传速度（字节/秒）
    @Published var currentSpeed: Double = 0

    /// 预计剩余时间（秒）
    @Published var estimatedTimeRemaining: TimeInterval = 0

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
    
    // MARK: - Computed Properties
    
    /// 等待中的任务
    var pendingTasks: [UploadTask] {
        tasks.filter { $0.status == .pending }
    }
    
    /// 正在上传的任务
    var uploadingTasks: [UploadTask] {
        tasks.filter { $0.status == .uploading }
    }
    
    /// 已完成的任务
    var completedTasks: [UploadTask] {
        tasks.filter { $0.status == .completed }
    }
    
    /// 失败的任务
    var failedTasks: [UploadTask] {
        tasks.filter { 
            if case .failed = $0.status { return true }
            return false
        }
    }
    
    /// 总进度
    var totalProgress: Double {
        guard !tasks.isEmpty else { return 0 }
        let total = tasks.reduce(0.0) { $0 + $1.progress }
        return total / Double(tasks.count)
    }
    
    /// 是否有活动任务
    var hasActiveTasks: Bool {
        !pendingTasks.isEmpty || !uploadingTasks.isEmpty
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
            case .uploading:
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

    /// 总体进度百分比
    var overallProgressPercent: Int {
        guard totalBytes > 0 else { return 0 }
        return Int((Double(uploadedBytes) / Double(totalBytes)) * 100)
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
                    remotePath = prefix.isEmpty ? relativePath : "\(prefix)\(relativePath)"
                } else {
                    remotePath = prefix.isEmpty ? url.lastPathComponent : "\(prefix)\(url.lastPathComponent)"
                }

                // 创建上传任务（不立即读取文件数据）
                let task = UploadTask(
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

        // 显示队列面板
        if !tasks.isEmpty {
            print("📥 [UploadQueue] 显示队列面板，准备调用 processQueue")
            isQueuePanelVisible = true
            processQueue()
            print("📥 [UploadQueue] processQueue 调用完成")
        }
    }
    
    /// 取消任务
    func cancelTask(_ task: UploadTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].status = .cancelled
        }
    }
    
    /// 重试失败的任务
    func retryTask(_ task: UploadTask) {
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
        tasks.removeAll { $0.status == .completed }
    }
    
    /// 清除所有任务
    func clearAll() {
        // 取消所有进行中的任务
        for index in tasks.indices {
            if tasks[index].status == .pending || tasks[index].status == .uploading {
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

        Task { @MainActor in
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
                    // 立即标记为 uploading，防止重复选择
                    if let index = tasks.firstIndex(where: { $0.id == nextTask.id }) {
                        tasks[index].status = .uploading
                        tasks[index].startTime = Date()
                    }
                    activeUploadCount += 1
                    print("🔄 [UploadQueue] 启动任务: \(nextTask.fileName)，当前并发: \(activeUploadCount)")

                    // 启动上传任务但不等待完成（真正的并发）
                    let taskId = nextTask.id
                    Task {
                        await self.performUpload(taskId: taskId, task: nextTask)
                    }
                }

                // 更新速度和ETA
                updateSpeedAndETA()

                // 等待一小段时间再检查（减少到 0.05s 提高响应速度）
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
            }

            print("🔄 [UploadQueue] 队列处理完成")
            // 完成后重置
            currentSpeed = 0
            estimatedTimeRemaining = 0
            isProcessing = false

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

        // 计算速度（使用滑动窗口平均）
        if speedSamples.count >= 2 {
            let oldest = speedSamples.first!
            let newest = speedSamples.last!
            let bytesTransferred = newest.bytes - oldest.bytes
            let timeElapsed = newest.time.timeIntervalSince(oldest.time)

            if timeElapsed > 0 {
                currentSpeed = Double(bytesTransferred) / timeElapsed
            }
        }

        // 计算剩余时间
        if currentSpeed > 0 {
            let remainingBytes = totalBytes - currentUploaded
            estimatedTimeRemaining = Double(remainingBytes) / currentSpeed
        } else {
            estimatedTimeRemaining = 0
        }
    }
    
    /// 执行单个上传任务（由 processQueue 并发调用）
    /// - Parameters:
    ///   - taskId: 任务 ID
    ///   - task: 上传任务
    private func performUpload(taskId: UUID, task: UploadTask) async {
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
            let data = try await Task.detached(priority: .userInitiated) {
                let fileData = try Data(contentsOf: task.localURL)
                return fileData
            }.value
            print("⬆️ [Upload] 文件数据读取完成: \(task.fileName), \(data.count) bytes")

            // 检查是否已取消
            let isCancelled = await MainActor.run {
                guard let currentIndex = tasks.firstIndex(where: { $0.id == taskId }) else {
                    return true
                }
                if tasks[currentIndex].status != .uploading {
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
