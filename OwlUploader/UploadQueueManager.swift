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

    /// 冲突检测回调
    /// 参数：冲突列表、用户选择后的回调
    var onConflictsDetected: (([UploadConflict], @escaping ([UUID: ConflictAction]) -> Void) -> Void)?

    // MARK: - Private Properties

    /// 当前正在上传的任务数量
    private var activeUploadCount: Int = 0

    /// 存储活跃的上传 Task 句柄（用于取消）
    private var activeTasks: [UUID: AsyncTask<Void, Never>] = [:]

    /// R2 服务引用
    private weak var r2Service: R2Service?

    /// 当前存储桶名称
    private var bucketName: String = ""

    /// 待批量 purge 的 CDN URL 列表
    private var pendingCDNPurgeURLs: [String] = []

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

    /// 上次进度 UI 更新时间（用于进度回调节流）
    private var lastProgressUpdateTime: Date = .distantPast

    /// 进度 UI 更新间隔（秒）- 比整体更新更频繁
    private let progressUpdateInterval: TimeInterval = 0.1

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

    /// 添加文件到上传队列（带冲突检测）
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

        // 如果配置了冲突检测回调，则进行冲突检测
        if onConflictsDetected != nil {
            AsyncTask {
                await self.addFilesWithConflictCheck(urls, to: prefix, baseFolder: baseFolder)
            }
        } else {
            // 没有配置冲突检测，直接添加
            addFilesDirectly(urls, to: prefix, baseFolder: baseFolder)
        }
    }

    /// 带冲突检测的文件添加
    private func addFilesWithConflictCheck(_ urls: [URL], to prefix: String, baseFolder: URL? = nil) async {
        guard let r2Service = r2Service else {
            print("❌ [UploadQueue] R2 服务未初始化，跳过冲突检测")
            addFilesDirectly(urls, to: prefix, baseFolder: baseFolder)
            return
        }

        // 1. 准备文件信息
        var fileInfos: [(url: URL, remotePath: String, fileSize: Int64, modDate: Date?)] = []

        for url in urls {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                let modDate = attributes[.modificationDate] as? Date

                // 构建远程路径
                let remotePath = buildRemotePath(for: url, prefix: prefix, baseFolder: baseFolder)
                fileInfos.append((url: url, remotePath: remotePath, fileSize: fileSize, modDate: modDate))
            } catch {
                print("❌ 无法获取文件信息: \(url.path)")
            }
        }

        // 2. 获取目标目录中已存在的文件列表
        var existingFiles: [String: (size: Int64, modDate: Date?)] = [:]
        do {
            if baseFolder != nil, !prefix.isEmpty {
                // 文件夹上传到指定目录：递归获取该目录下所有文件
                let allFiles = try await r2Service.listAllFilesInFolder(bucket: bucketName, folderPrefix: prefix)
                for file in allFiles {
                    existingFiles[file.key] = (size: file.size, modDate: nil)
                }
            } else {
                // 普通文件上传：只查当前目录层级
                let prefixParam = prefix.isEmpty ? nil : prefix
                let objects = try await r2Service.listObjects(bucket: bucketName, prefix: prefixParam)
                for obj in objects {
                    if !obj.isDirectory {
                        existingFiles[obj.key] = (size: obj.size ?? 0, modDate: obj.lastModifiedDate)
                    }
                }
            }
        } catch {
            print("⚠️ [UploadQueue] 无法获取远程文件列表，跳过冲突检测: \(error)")
            addFilesDirectly(urls, to: prefix, baseFolder: baseFolder)
            return
        }

        // 3. 检测冲突
        var conflicts: [UploadConflict] = []
        var nonConflictFiles: [(url: URL, remotePath: String)] = []

        for fileInfo in fileInfos {
            if let existingFile = existingFiles[fileInfo.remotePath] {
                // 存在冲突
                let conflict = UploadConflict(
                    localURL: fileInfo.url,
                    remotePath: fileInfo.remotePath,
                    localFileName: fileInfo.url.lastPathComponent,
                    localFileSize: fileInfo.fileSize,
                    localModDate: fileInfo.modDate,
                    remoteFileSize: existingFile.size,
                    remoteModDate: existingFile.modDate
                )
                conflicts.append(conflict)
            } else {
                nonConflictFiles.append((url: fileInfo.url, remotePath: fileInfo.remotePath))
            }
        }

        // 4. 如果没有冲突，直接添加所有文件
        if conflicts.isEmpty {
            print("📥 [UploadQueue] 无冲突，直接添加所有文件")
            addFilesDirectly(urls, to: prefix, baseFolder: baseFolder)
            return
        }

        // 5. 有冲突，先添加无冲突的文件
        for file in nonConflictFiles {
            addSingleFile(url: file.url, remotePath: file.remotePath)
        }

        // 立即开始处理非冲突文件（防止用户离开视图导致队列停滞）
        if !tasks.isEmpty && !isProcessing {
            processQueue()
        }

        // 6. 调用冲突回调让用户选择
        print("📥 [UploadQueue] 检测到 \(conflicts.count) 个冲突文件")

        await MainActor.run {
            self.onConflictsDetected?(conflicts) { [weak self] resolutions in
                guard let self = self else { return }

                AsyncTask { @MainActor in
                    await self.handleConflictResolutions(conflicts: conflicts, resolutions: resolutions, prefix: prefix)
                }
            }
        }
    }

    /// 处理用户的冲突解决选择
    private func handleConflictResolutions(conflicts: [UploadConflict], resolutions: [UUID: ConflictAction], prefix: String) async {
        for conflict in conflicts {
            guard let action = resolutions[conflict.id] else { continue }

            switch action {
            case .replace:
                // 覆盖：直接使用原路径上传
                print("📥 [UploadQueue] 覆盖: \(conflict.localFileName)")
                addSingleFile(url: conflict.localURL, remotePath: conflict.remotePath)

            case .keepBoth:
                // 保留两者：生成唯一路径
                do {
                    let uniquePath = try await generateUniquePath(conflict.remotePath)
                    print("📥 [UploadQueue] 保留两者: \(conflict.localFileName) → \(uniquePath)")
                    addSingleFile(url: conflict.localURL, remotePath: uniquePath)
                } catch {
                    print("❌ [UploadQueue] 生成唯一路径失败: \(error)")
                    // 将失败的文件作为任务添加到队列，让用户看到错误
                    var failedTask = UploadQueueTask(
                        id: UUID(),
                        fileName: conflict.localFileName,
                        fileSize: conflict.localFileSize,
                        localURL: conflict.localURL,
                        remotePath: conflict.remotePath,
                        contentType: inferContentType(from: conflict.localURL)
                    )
                    failedTask.status = .failed(error.localizedDescription)
                    tasks.append(failedTask)
                }

            case .skip:
                // 跳过：不上传
                print("📥 [UploadQueue] 跳过: \(conflict.localFileName)")
            }
        }

        // 开始处理队列
        if !tasks.isEmpty && !isProcessing {
            processQueue()
        }
    }

    /// 生成唯一文件路径（Finder 风格：file.txt → file (1).txt → file (2).txt）
    func generateUniquePath(_ path: String) async throws -> String {
        guard let r2Service = r2Service else {
            throw R2ServiceError.accountNotConfigured
        }

        // 分解路径
        let nsPath = path as NSString
        let directory = nsPath.deletingLastPathComponent
        let fileName = nsPath.lastPathComponent as NSString
        let ext = fileName.pathExtension
        let baseName = fileName.deletingPathExtension

        // 获取目录中的文件列表
        let prefix = directory.isEmpty ? nil : (directory.hasSuffix("/") ? directory : directory + "/")
        let objects = try await r2Service.listObjects(bucket: bucketName, prefix: prefix)
        let existingKeys = Set(objects.map { $0.key })

        // 尝试生成唯一名称
        var counter = 1
        var newPath = path

        while existingKeys.contains(newPath) {
            let newFileName: String
            if ext.isEmpty {
                newFileName = "\(baseName) (\(counter))"
            } else {
                newFileName = "\(baseName) (\(counter)).\(ext)"
            }

            if directory.isEmpty {
                newPath = newFileName
            } else {
                newPath = (directory as NSString).appendingPathComponent(newFileName)
            }
            counter += 1

            // 防止无限循环
            if counter > 1000 {
                throw R2ServiceError.invalidOperation("无法生成唯一文件名")
            }
        }

        return newPath
    }

    /// 构建远程路径
    private func buildRemotePath(for url: URL, prefix: String, baseFolder: URL?) -> String {
        if let base = baseFolder {
            let basePath = base.deletingLastPathComponent().path
            let relativePath = url.path.replacingOccurrences(of: basePath + "/", with: "")

            var safePrefix = prefix
            if !safePrefix.isEmpty && !safePrefix.hasSuffix("/") {
                safePrefix += "/"
            }

            return safePrefix.isEmpty ? relativePath : "\(safePrefix)\(relativePath)"
        } else {
            var safePrefix = prefix
            if !safePrefix.isEmpty && !safePrefix.hasSuffix("/") {
                safePrefix += "/"
            }

            return safePrefix.isEmpty ? url.lastPathComponent : "\(safePrefix)\(url.lastPathComponent)"
        }
    }

    /// 添加单个文件到队列
    private func addSingleFile(url: URL, remotePath: String) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ 文件不存在: \(url.path)")
            return
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let contentType = inferContentType(from: url)

            // 跳过已存在的活跃任务
            let existingActiveTask = tasks.first { task in
                task.localURL == url && task.status.isActive
            }
            if existingActiveTask != nil {
                print("⚠️ [UploadQueue] 跳过重复任务: \(url.lastPathComponent)")
                return
            }

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

    /// 直接添加文件（不检测冲突）
    private func addFilesDirectly(_ urls: [URL], to prefix: String, baseFolder: URL? = nil) {
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
                let remotePath = buildRemotePath(for: url, prefix: prefix, baseFolder: baseFolder)

                // 跳过已存在的活跃任务（防止重复添加）
                let existingActiveTask = tasks.first { task in
                    task.localURL == url && task.status.isActive
                }
                if existingActiveTask != nil {
                    print("⚠️ [UploadQueue] 跳过重复任务: \(url.lastPathComponent)")
                    continue
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
        // 取消正在执行的 Task
        activeTasks[task.id]?.cancel()
        activeTasks[task.id] = nil

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
        objectWillChange.send()
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
                    let uploadTask = AsyncTask {
                        await self.performUpload(taskId: taskId, task: nextTask)
                    }
                    // 存储 Task 句柄以便取消
                    activeTasks[taskId] = uploadTask
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

            // 批量 purge CDN 缓存（Cloudflare 单次最多 30 个 URL）
            if !pendingCDNPurgeURLs.isEmpty, let r2Service = self.r2Service {
                let urlsToPurge = pendingCDNPurgeURLs
                pendingCDNPurgeURLs.removeAll()
                print("🔄 [UploadQueue] 批量 purge CDN 缓存: \(urlsToPurge.count) 个 URL")
                AsyncTask {
                    var failedCount = 0
                    for batch in stride(from: 0, to: urlsToPurge.count, by: 30) {
                        let end = min(batch + 30, urlsToPurge.count)
                        let batchURLs = Array(urlsToPurge[batch..<end])
                        let success = await r2Service.purgeCDNCache(for: batchURLs)
                        if !success { failedCount += batchURLs.count }
                    }
                    if failedCount > 0 {
                        print("⚠️ [UploadQueue] CDN purge 部分失败: \(failedCount)/\(urlsToPurge.count) 个 URL")
                    }
                }
            }

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

    /// 节流的进度 UI 更新（用于进度回调）
    private func throttledProgressUpdate() {
        let now = Date()
        if now.timeIntervalSince(lastProgressUpdateTime) >= progressUpdateInterval {
            lastProgressUpdateTime = now
            objectWillChange.send()
        }
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
                    tasks[idx].status = .failed(L.Error.Service.r2NotInitialized)
                }
            }
            return
        }

        do {
            // 获取安全作用域权限
            let needsSecurityScope = task.localURL.startAccessingSecurityScopedResource()

            defer {
                if needsSecurityScope {
                    task.localURL.stopAccessingSecurityScopedResource()
                }
            }

            // 检查是否已取消
            let isCancelled = await MainActor.run {
                guard let currentIndex = tasks.firstIndex(where: { $0.id == taskId }) else {
                    return true
                }
                if tasks[currentIndex].status != .processing {
                    return true
                }
                // 更新进度为5%（开始上传）
                tasks[currentIndex].progress = 0.05
                return false
            }

            if isCancelled {
                print("⬆️ [Upload] 任务已取消，跳过上传: \(task.fileName)")
                await MainActor.run { activeUploadCount -= 1 }
                return
            }

            // 使用流式上传，避免将整个文件加载到内存
            print("⬆️ [Upload] 开始流式上传到 R2: \(task.remotePath)")
            try await r2Service.uploadFileStream(
                bucket: bucketName,
                key: task.remotePath,
                fileURL: task.localURL,
                contentType: task.contentType
            ) { progress in
                AsyncTask { @MainActor in
                    if let idx = self.tasks.firstIndex(where: { $0.id == taskId }) {
                        // 将进度映射到 0.05 - 0.95 范围（保留首尾用于状态更新）
                        self.tasks[idx].progress = 0.05 + progress * 0.9
                        self.throttledProgressUpdate()
                    }
                }
            }
            print("✅ [Upload] 上传完成: \(task.fileName)")

            // 更新状态为完成（仅当任务仍在处理中时，避免覆盖已取消状态）
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    if tasks[idx].status == .processing {
                        tasks[idx].progress = 1.0
                        tasks[idx].status = .completed
                    }
                }
                activeUploadCount -= 1
                activeTasks[taskId] = nil

                // 清除旧缩略图缓存（确保覆盖上传后显示新图片）
                r2Service.invalidateThumbnailCache(for: task.remotePath, in: bucketName)

                // 收集待 purge 的 CDN URL（仅 Cloudflare R2，队列完成时统一批量 purge）
                if r2Service.supportsCDNPurge,
                   let fileURL = r2Service.generateBaseURL(for: task.remotePath, in: bucketName) {
                    self.pendingCDNPurgeURLs.append(fileURL)
                }
            }

        } catch {
            print("❌ [Upload] 上传失败: \(task.fileName) - \(error.localizedDescription)")
            // 更新失败状态
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    // 区分取消和失败
                    if error is CancellationError {
                        tasks[idx].status = .cancelled
                    } else {
                        tasks[idx].status = .failed(error.localizedDescription)
                    }
                }
                activeUploadCount -= 1
                activeTasks[taskId] = nil
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
