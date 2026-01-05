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

// MARK: - 冲突解决策略

/// 冲突解决策略
enum ConflictResolution: String, CaseIterable {
    /// 跳过冲突文件
    case skip
    /// 重命名（添加序号如 file(1).txt）
    case rename
    /// 覆盖已存在的文件
    case replace

    var displayName: String {
        switch self {
        case .skip:
            return L.Move.ConflictResolution.skip
        case .rename:
            return L.Move.ConflictResolution.rename
        case .replace:
            return L.Move.ConflictResolution.replace
        }
    }
}

/// 重命名模式预设
enum RenamePattern: String, CaseIterable, Identifiable {
    case parentheses = "({n})"    // file(1).txt
    case underscore = "_{n}"       // file_1.txt
    case dash = "-{n}"             // file-1.txt
    case bracket = "[{n}]"         // file[1].txt
    case custom = "custom"         // 用户自定义

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .parentheses:
            return "file(1).txt"
        case .underscore:
            return "file_1.txt"
        case .dash:
            return "file-1.txt"
        case .bracket:
            return "file[1].txt"
        case .custom:
            return L.Move.ConflictResolution.custom
        }
    }

    /// 获取模式字符串（用于显示和应用）
    func patternString(customValue: String = "") -> String {
        switch self {
        case .custom:
            return customValue.isEmpty ? "({n})" : customValue
        default:
            return rawValue
        }
    }

    /// 应用模式生成新文件名
    func apply(to baseName: String, number: Int, customPattern: String = "") -> String {
        let pattern = patternString(customValue: customPattern)
        let replacement = pattern.replacingOccurrences(of: "{n}", with: "\(number)")
        return baseName + replacement
    }

    /// 预览示例
    func preview(customPattern: String = "") -> String {
        let pattern = patternString(customValue: customPattern)
        let example = pattern.replacingOccurrences(of: "{n}", with: "1")
        return "file\(example).txt"
    }
}

// MARK: - 移动错误

/// 移动操作错误
enum MoveError: LocalizedError {
    /// 目标已存在
    case destinationExists(String)
    /// 操作被跳过
    case skipped(String)

    var errorDescription: String? {
        switch self {
        case .destinationExists(let fileName):
            return L.Move.Message.destinationExistsDetail(fileName)
        case .skipped(let fileName):
            return L.Move.Message.skipped(fileName)
        }
    }
}

// MARK: - 移动任务

/// 移动任务
struct MoveQueueTask: QueueTaskProtocol {
    let id: UUID
    let sourceKey: String
    var destinationKey: String
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

    // MARK: - Conflict Resolution

    /// 冲突解决策略 UserDefaults 键
    private static let conflictResolutionKey = "moveConflictResolution"
    private static let renamePatternKey = "moveRenamePattern"
    private static let customPatternKey = "moveCustomPattern"

    /// 冲突解决策略（从 UserDefaults 读取，默认重命名）
    @Published var conflictResolution: ConflictResolution = .rename {
        didSet {
            UserDefaults.standard.set(conflictResolution.rawValue, forKey: Self.conflictResolutionKey)
        }
    }

    /// 重命名模式（从 UserDefaults 读取，默认括号格式）
    @Published var renamePattern: RenamePattern = .parentheses {
        didSet {
            UserDefaults.standard.set(renamePattern.rawValue, forKey: Self.renamePatternKey)
        }
    }

    /// 自定义模式字符串（用户输入的自定义格式，如 "-abc{n}"）
    @Published var customPatternString: String = "({n})" {
        didSet {
            UserDefaults.standard.set(customPatternString, forKey: Self.customPatternKey)
        }
    }

    /// 从 UserDefaults 加载设置
    private func loadSettings() {
        if let savedResolution = UserDefaults.standard.string(forKey: Self.conflictResolutionKey),
           let resolution = ConflictResolution(rawValue: savedResolution) {
            self.conflictResolution = resolution
        }

        if let savedPattern = UserDefaults.standard.string(forKey: Self.renamePatternKey),
           let pattern = RenamePattern(rawValue: savedPattern) {
            self.renamePattern = pattern
        }

        if let savedCustom = UserDefaults.standard.string(forKey: Self.customPatternKey), !savedCustom.isEmpty {
            self.customPatternString = savedCustom
        }
    }

    /// 获取当前冲突解决策略（用于 UI 显示）
    static func getConflictResolution() -> ConflictResolution {
        if let savedResolution = UserDefaults.standard.string(forKey: conflictResolutionKey),
           let resolution = ConflictResolution(rawValue: savedResolution) {
            return resolution
        }
        return .rename
    }

    /// 获取当前重命名模式（用于 UI 显示）
    static func getRenamePattern() -> RenamePattern {
        if let savedPattern = UserDefaults.standard.string(forKey: renamePatternKey),
           let pattern = RenamePattern(rawValue: savedPattern) {
            return pattern
        }
        return .parentheses
    }

    /// 获取自定义模式字符串（用于 UI 显示）
    static func getCustomPatternString() -> String {
        UserDefaults.standard.string(forKey: customPatternKey) ?? "({n})"
    }

    // MARK: - Callbacks

    /// 队列完成回调
    var onQueueComplete: (() -> Void)?

    // MARK: - Private Properties

    /// 当前正在移动的任务数量
    private var activeMoveCount: Int = 0

    /// 存储活跃的移动 Task 句柄（用于取消）
    private var activeTasks: [UUID: AsyncTask<Void, Never>] = [:]

    /// R2 服务引用
    private weak var r2Service: R2Service?

    /// 当前存储桶名称
    private var bucketName: String = ""

    // MARK: - Public Methods

    /// 配置管理器
    func configure(r2Service: R2Service, bucketName: String) {
        self.r2Service = r2Service
        self.bucketName = bucketName
        loadSettings()
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

            // 跳过已存在的活跃任务（防止重复添加）
            let existingActiveTask = tasks.first { task in
                task.sourceKey == item.key && task.status.isActive
            }
            if existingActiveTask != nil {
                print("⚠️ [Move] 跳过重复任务: \(item.key)")
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
        // 取消正在执行的 Task
        activeTasks[task.id]?.cancel()
        activeTasks[task.id] = nil

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

                    // 启动移动任务并存储句柄
                    let taskId = nextTask.id
                    let moveTask = AsyncTask {
                        await self.performMove(taskId: taskId, task: nextTask)
                    }
                    activeTasks[taskId] = moveTask
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
            var finalDestinationKey = task.destinationKey
            let exists = try await r2Service.objectExists(bucket: bucketName, key: finalDestinationKey)

            if exists {
                // 根据冲突解决策略处理
                switch conflictResolution {
                case .skip:
                    // 跳过此文件
                    await MainActor.run {
                        if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                            tasks[idx].status = .cancelled
                        }
                        activeMoveCount -= 1
                    }
                    return

                case .rename:
                    // 生成唯一的新名称
                    finalDestinationKey = try await generateUniqueDestinationKey(
                        r2Service: r2Service,
                        originalKey: task.destinationKey,
                        isDirectory: task.isDirectory
                    )
                    // 更新任务中的目标路径
                    await MainActor.run {
                        if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                            tasks[idx].destinationKey = finalDestinationKey
                        }
                    }

                case .replace:
                    // 安全起见，不再支持覆盖操作，而是报错
                    // 这可以防止意外删除目标文件夹中的重要数据
                    throw MoveError.destinationExists(task.destinationKey)
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
                    destinationFolderKey: finalDestinationKey
                )
            } else {
                try await r2Service.moveObject(
                    bucket: bucketName,
                    sourceKey: task.sourceKey,
                    destinationKey: finalDestinationKey
                )
            }

            // 更新状态为完成（仅当任务仍在处理中时，避免覆盖已取消状态）
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                    if tasks[idx].status == .processing {
                        tasks[idx].progress = 1.0
                        tasks[idx].status = .completed
                    }
                }
                activeMoveCount -= 1
                activeTasks[taskId] = nil
            }

        } catch {
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
                activeMoveCount -= 1
                activeTasks[taskId] = nil
            }
        }
    }

    /// 生成唯一的目标路径（根据用户选择的模式添加序号）
    private func generateUniqueDestinationKey(
        r2Service: R2Service,
        originalKey: String,
        isDirectory: Bool
    ) async throws -> String {
        var counter = 1
        var newKey = originalKey

        while try await r2Service.objectExists(bucket: bucketName, key: newKey) {
            if isDirectory {
                // 文件夹：folder/ -> folder(1)/ 或用户自定义模式
                let trimmedKey = originalKey.hasSuffix("/") ? String(originalKey.dropLast()) : originalKey
                // 提取文件夹名和父路径
                let folderName: String
                let parentPath: String
                if let lastSlash = trimmedKey.lastIndex(of: "/") {
                    parentPath = String(trimmedKey[...lastSlash])
                    folderName = String(trimmedKey[trimmedKey.index(after: lastSlash)...])
                } else {
                    parentPath = ""
                    folderName = trimmedKey
                }
                let newFolderName = renamePattern.apply(to: folderName, number: counter, customPattern: customPatternString)
                newKey = parentPath + newFolderName + "/"
            } else {
                // 文件：file.txt -> file(1).txt 或用户自定义模式
                let pathExtension = (originalKey as NSString).pathExtension
                let pathWithoutExtension = (originalKey as NSString).deletingPathExtension
                // 提取文件名（不含扩展名）和父路径
                let baseName: String
                let parentPath: String
                if let lastSlash = pathWithoutExtension.lastIndex(of: "/") {
                    parentPath = String(pathWithoutExtension[...lastSlash])
                    baseName = String(pathWithoutExtension[pathWithoutExtension.index(after: lastSlash)...])
                } else {
                    parentPath = ""
                    baseName = pathWithoutExtension
                }
                let newBaseName = renamePattern.apply(to: baseName, number: counter, customPattern: customPatternString)

                if pathExtension.isEmpty {
                    newKey = parentPath + newBaseName
                } else {
                    newKey = parentPath + newBaseName + "." + pathExtension
                }
            }
            counter += 1

            // 防止无限循环
            if counter > 100 {
                throw MoveError.destinationExists(originalKey)
            }
        }

        return newKey
    }
}
