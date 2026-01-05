//
//  QueueTask.swift
//  OwlUploader
//
//  通用任务队列协议定义
//  支持上传、移动等不同类型的队列任务
//

import Foundation
import SwiftUI

// MARK: - 任务状态

/// 通用任务状态
enum TaskStatus: Equatable {
    case pending      // 等待中
    case processing   // 处理中
    case completed    // 已完成
    case failed(String)  // 失败（附带错误信息）
    case cancelled    // 已取消

    /// 是否为活动状态（等待中或处理中）
    var isActive: Bool {
        switch self {
        case .pending, .processing:
            return true
        default:
            return false
        }
    }

    /// 是否已完成
    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    /// 是否失败
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    /// 是否已取消
    var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }

    /// 获取失败信息（仅失败状态有值）
    var failureMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }

    /// 状态图标名称
    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    /// 状态图标颜色
    var iconColor: Color {
        switch self {
        case .pending: return .secondary
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

// MARK: - 任务协议

/// 队列任务协议
protocol QueueTaskProtocol: Identifiable, Equatable {
    var id: UUID { get }

    /// 显示名称（文件名）
    var displayName: String { get }

    /// 显示详情（大小、路径等）
    var displayDetail: String { get }

    /// 任务进度 (0.0 - 1.0)
    var progress: Double { get set }

    /// 任务状态
    var status: TaskStatus { get set }
}

// MARK: - 队列管理器协议

/// 队列管理器协议
protocol TaskQueueManagerProtocol: ObservableObject {
    associatedtype Task: QueueTaskProtocol

    /// 所有任务
    var tasks: [Task] { get set }

    /// 是否正在处理队列
    var isProcessing: Bool { get }

    /// 队列面板是否可见
    var isQueuePanelVisible: Bool { get set }

    /// 队列标题
    var queueTitle: String { get }

    /// 处理中的动词（如"上传中"、"移动中"）
    var processingVerb: String { get }

    /// 取消任务
    func cancelTask(_ task: Task)

    /// 重试任务
    func retryTask(_ task: Task)

    /// 清除已完成的任务
    func clearCompleted()

    /// 清除所有任务
    func clearAll()
}

// MARK: - 队列管理器协议扩展（提供默认实现）

extension TaskQueueManagerProtocol {
    /// 等待中的任务
    var pendingTasks: [Task] {
        tasks.filter { $0.status == .pending }
    }

    /// 处理中的任务
    var processingTasks: [Task] {
        tasks.filter { $0.status == .processing }
    }

    /// 已完成的任务
    var completedTasks: [Task] {
        tasks.filter { $0.status.isCompleted }
    }

    /// 失败的任务
    var failedTasks: [Task] {
        tasks.filter { $0.status.isFailed }
    }

    /// 是否有活动任务
    var hasActiveTasks: Bool {
        !pendingTasks.isEmpty || !processingTasks.isEmpty
    }

    /// 总进度
    var totalProgress: Double {
        guard !tasks.isEmpty else { return 0 }
        let total = tasks.reduce(0.0) { $0 + $1.progress }
        return total / Double(tasks.count)
    }

    /// 总进度百分比
    var overallProgressPercent: Int {
        Int(totalProgress * 100)
    }
}
