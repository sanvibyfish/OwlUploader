//
//  MoveQueueManager.swift
//  OwlUploader
//
//  文件移动队列管理器
//  支持并发移动、进度追踪、冲突处理
//

import Foundation
import SwiftUI
import Combine

/// 避免与 MoveQueueTask 冲突的类型别名
private typealias AsyncTask = Task

// MARK: - 移动任务

/// 移动任务
struct MoveQueueTask: QueueTaskProtocol {
    let id: UUID
    let sourceKey: String
    let destinationKey: String
    let fileName: String
    let isDirectory: Bool
    var progress: Double = 0
    var status: TaskStatus = .pending

    // MARK: - QueueTaskProtocol

    var displayName: String { fileName }

    var displayDetail: String {
        // 提取目标文件夹名称
        let destPath = destinationKey.hasSuffix("/") ? String(destinationKey.dropLast()) : destinationKey
        if let lastSlash = destPath.lastIndex(of: "/") {
            let folder = String(destPath[destPath.index(after: lastSlash)...])
            return "→ \(folder.isEmpty ? L.Move.rootDirectory : folder)/"
        }
        return "→ \(L.Move.rootDirectory)"
    }

    static func == (lhs: MoveQueueTask, rhs: MoveQueueTask) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.progress == rhs.progress
    }
}

// MARK: - 移动队列管理器

/// 移动队列管理器
@MainActor
class MoveQueueManager: ObservableObject, TaskQueueManagerProtocol {

    // MARK: - Published Properties

    /// 所有移动任务（不使用 @Published，手动控制更新时机）
    var tasks: [MoveQueueTask] = []

    /// 是否正在处理队列
    @Published var isProcessing: Bool = false

    /// 队列面板是否显示
    @Published var isQueuePanelVisible: Bool = false

    /// 上次 UI 更新时间（用于节流）
    private var lastUIUpdateTime: Date = .distantPast

    /// UI 更新间隔（秒）
    private let uiUpdateInterval: TimeInterval = 1.0

    // MARK: - TaskQueueManagerProtocol

    var queueTitle: String { L.Move.Queue.title }
    var processingVerb: String { L.Move.Status.moving }

    // MARK: - Configuration

    /// 并发移动数 UserDefaults 键
    private static let concurrentMovesKey = "maxConcurrentMoves"

    /// 最大并发移动数（从设置读取，默认 3，范围 1-10）
    var maxConcurrentMoves: Int {
        let stored = UserDefaults.standard.integer(forKey: Self.concurrentMovesKey)
        if stored == 0 {
            return 3 // 默认值
        }
        return min(max(stored, 1), 10)
    }

    /// 设置最大并发移动数
    static func setMaxConcurrentMoves(_ value: Int) {
        let clamped = min(max(value, 1), 10)
        UserDefaults.standard.set(clamped, forKey: concurrentMovesKey)
    }

    /// 获取当前设置的最大并发移动数（用于 UI 显示）
    static func getMaxConcurrentMoves() -> Int {
        let stored = UserDefaults.standard.integer(forKey: concurrentMovesKey)
        if stored == 0 {
            return 3 // 默认值
        }
        return min(max(stored, 1), 10)
    }

    // MARK: - Callbacks

    /// 队列完成回调
    var onQueueComplete: (() -> Void)?

    // MARK: - Private Properties

    /// 当前正在移动的任务数量
    private var activeMoveCount: Int = 0

    /// R2 服务引用
    private weak var r2Service: R2Service?

    /// 当前存储桶名称
    private var bucketName: String = ""

    // MARK: - Public Methods

    /// 配置管理器
    func configure(r2Service: R2Service, bucketName: String) {
        self.r2Service = r2Service
        self.bucketName = bucketName
    }

    /// 添加移动任务
    /// - Parameters:
    ///   - items: 要移动的文件项列表
    ///   - destinationPath: 目标路径前缀
    func addMoveTasks(_ items: [FileObject], to destinationPath: String) {
        for item in items {
            // 计算目标键
            let destKey = destinationPath + item.name + (item.isDirectory ? "/" : "")

            // 跳过移动到当前位置的情况
            let itemParentPath = getParentPath(of: item.key)
            if itemParentPath == destinationPath {
                continue
            }

            let task = MoveQueueTask(
                id: UUID(),
                sourceKey: item.key,
                destinationKey: destKey,
                fileName: item.name,
                isDirectory: item.isDirectory
            )

            tasks.append(task)
        }

        // 显示队列面板并开始处理
        if !tasks.isEmpty {
            isQueuePanelVisible = true
            processQueue()
        }
    }

    /// 取消任务
    func cancelTask(_ task: MoveQueueTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].status = .cancelled
        }
    }

    /// 重试任务
    func retryTask(_ task: MoveQueueTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].status = .pending
            tasks[index].progress = 0
            processQueue()
        }
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

    /// 获取路径的父目录
    private func getParentPath(of key: String) -> String {
        let trimmedKey = key.hasSuffix("/") ? String(key.dropLast()) : key
        if let lastSlashIndex = trimmedKey.lastIndex(of: "/") {
            return String(trimmedKey[..<lastSlashIndex]) + "/"
        }
        return ""
    }

    /// 处理移动队列
    private func processQueue() {
        guard !isProcessing else { return }
        isProcessing = true

        AsyncTask { @MainActor in
            while hasActiveTasks {
                // 检查是否可以启动新任务
                while activeMoveCount < maxConcurrentMoves,
                      let nextTask = pendingTasks.first {
                    // 标记为处理中
                    if let index = tasks.firstIndex(where: { $0.id == nextTask.id }) {
                        tasks[index].status = .processing
                    }
                    activeMoveCount += 1

                    // 启动移动任务
                    let taskId = nextTask.id
                    AsyncTask {
                        await self.performMove(taskId: taskId, task: nextTask)
                    }
                }

                // 节流 UI 更新
                let now = Date()
                if now.timeIntervalSince(lastUIUpdateTime) >= uiUpdateInterval {
                    lastUIUpdateTime = now
                    objectWillChange.send()
                }

                // 等待一小段时间再检查
                try? await AsyncTask.sleep(nanoseconds: 500_000_000) // 0.5秒
            }

            // 完成后重置
            isProcessing = false

            // 最终 UI 更新
            objectWillChange.send()

            // 触发完成回调
            if completedTasks.count > 0 {
                onQueueComplete?()
            }
        }
    }

    /// 执行单个移动任务
    private func performMove(taskId: UUID, task: MoveQueueTask) async {
        guard let r2Service = r2Service else {
            await MainActor.run {
                activeMoveCount -= 1
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[idx].status = .failed(L.Error.Service.r2NotInitialized)
                }
            }
            return
        }

        do {
            // 更新进度为 10%
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[idx].progress = 0.1
                }
            }

            // 检查目标是否存在
            let exists = try await r2Service.objectExists(bucket: bucketName, key: task.destinationKey)

            if exists {
                // 存在冲突，先删除目标
                if task.isDirectory {
                    _ = try await r2Service.deleteFolder(bucket: bucketName, folderKey: task.destinationKey)
                } else {
                    try await r2Service.deleteObject(bucket: bucketName, key: task.destinationKey)
                }
            }

            // 更新进度为 30%
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[idx].progress = 0.3
                }
            }

            // 执行移动
            if task.isDirectory {
                _ = try await r2Service.moveFolder(
                    bucket: bucketName,
                    sourceFolderKey: task.sourceKey,
                    destinationFolderKey: task.destinationKey
                )
            } else {
                try await r2Service.moveObject(
                    bucket: bucketName,
                    sourceKey: task.sourceKey,
                    destinationKey: task.destinationKey
                )
            }

            // 更新状态为完成
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[idx].progress = 1.0
                    tasks[idx].status = .completed
                }
                activeMoveCount -= 1
            }

        } catch {
            // 更新失败状态
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[idx].status = .failed(error.localizedDescription)
                }
                activeMoveCount -= 1
            }
        }
    }
}
