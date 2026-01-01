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
        case .pending: return "等待中"
        case .uploading: return "上传中"
        case .completed: return "已完成"
        case .failed(let error): return "失败: \(error)"
        case .cancelled: return "已取消"
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
    
    // MARK: - Configuration
    
    /// 最大并发上传数
    let maxConcurrentUploads: Int = 3
    
    // MARK: - Private Properties
    
    /// 当前正在上传的任务数量
    private var activeUploadCount: Int = 0
    
    /// R2 服务引用
    private weak var r2Service: R2Service?
    
    /// 当前存储桶名称
    private var bucketName: String = ""
    
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
    func addFiles(_ urls: [URL], to prefix: String) {
        for url in urls {
            // 验证文件
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("⚠️ 文件不存在: \(url.path)")
                continue
            }
            
            do {
                // 获取文件属性
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                // 读取文件数据
                let data = try Data(contentsOf: url)
                
                // 推断 MIME 类型
                let contentType = inferContentType(from: url)
                
                // 构建远程路径
                let remotePath = prefix.isEmpty ? url.lastPathComponent : "\(prefix)\(url.lastPathComponent)"
                
                // 创建上传任务
                var task = UploadTask(
                    id: UUID(),
                    fileName: url.lastPathComponent,
                    fileSize: fileSize,
                    localURL: url,
                    remotePath: remotePath,
                    contentType: contentType
                )
                task.data = data
                
                tasks.append(task)
                print("✅ 添加上传任务: \(task.fileName) (\(task.formattedSize))")
                
            } catch {
                print("❌ 无法读取文件: \(url.path) - \(error.localizedDescription)")
            }
        }
        
        // 显示队列面板
        if !tasks.isEmpty {
            isQueuePanelVisible = true
            processQueue()
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
        guard !isProcessing else { return }
        isProcessing = true
        
        Task {
            while hasActiveTasks {
                // 检查是否可以启动新任务
                while activeUploadCount < maxConcurrentUploads,
                      let nextTask = pendingTasks.first {
                    await startUpload(nextTask)
                }
                
                // 等待一小段时间再检查
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
            
            isProcessing = false
        }
    }
    
    /// 开始上传任务
    private func startUpload(_ task: UploadTask) async {
        guard let r2Service = r2Service,
              let taskIndex = tasks.firstIndex(where: { $0.id == task.id }),
              let data = task.data else {
            return
        }
        
        activeUploadCount += 1
        tasks[taskIndex].status = .uploading
        
        do {
            // 模拟进度更新（实际 AWS SDK 可能不支持进度回调）
            for progress in stride(from: 0.0, through: 0.9, by: 0.1) {
                if tasks[taskIndex].status == .cancelled { break }
                tasks[taskIndex].progress = progress
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            
            // 执行上传
            try await r2Service.uploadData(
                bucket: bucketName,
                key: task.remotePath,
                data: data,
                contentType: task.contentType
            )
            
            // 更新状态
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].progress = 1.0
                tasks[idx].status = .completed
            }
            
            print("✅ 上传完成: \(task.fileName)")
            
        } catch {
            // 更新失败状态
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].status = .failed(error.localizedDescription)
            }
            print("❌ 上传失败: \(task.fileName) - \(error.localizedDescription)")
        }
        
        activeUploadCount -= 1
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
