//
//  CombinedQueueView.swift
//  OwlUploader
//
//  组合队列视图
//  同时显示上传和移动任务
//

import SwiftUI

/// 组合队列面板视图
struct CombinedQueueView: View {

    @ObservedObject var uploadManager: UploadQueueManager
    @ObservedObject var moveManager: MoveQueueManager

    /// 是否展开面板
    @State private var isExpanded: Bool = true

    /// 是否有任何任务
    var hasTasks: Bool {
        !uploadManager.tasks.isEmpty || !moveManager.tasks.isEmpty
    }

    /// 总任务数
    var totalTaskCount: Int {
        uploadManager.tasks.count + moveManager.tasks.count
    }

    /// 是否有活动任务
    var hasActiveTasks: Bool {
        uploadManager.hasActiveTasks || moveManager.hasActiveTasks
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            // 任务列表（展开时显示）
            if isExpanded {
                Divider()
                taskListView
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .clipShape(
            .rect(
                topLeadingRadius: 12,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 12
            )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: -2)
    }

    // MARK: - 子视图

    /// 标题栏
    private var headerView: some View {
        HStack(spacing: 12) {
            // 展开/收起按钮
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            // 标题和进度信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(L.Upload.Queue.title)
                        .font(.headline)

                    Text(L.Upload.Queue.fileCount(totalTaskCount))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 上传速度和剩余时间
                    if uploadManager.hasActiveTasks {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(uploadManager.formattedSpeed)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .monospacedDigit()

                        if uploadManager.estimatedTimeRemaining > 0 {
                            Text(L.Upload.Queue.remaining(uploadManager.formattedETA))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                // 进度信息
                progressInfoView
            }

            Spacer()

            // 总进度
            if hasActiveTasks {
                HStack(spacing: 6) {
                    Text("\(overallProgressPercent)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)

                    ProgressView(value: overallProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                }
            }

            // 操作按钮
            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// 进度信息
    private var progressInfoView: some View {
        HStack(spacing: 8) {
            // 上传中
            let uploadingCount = uploadManager.uploadingTasks.count
            if uploadingCount > 0 {
                Text(L.Upload.Queue.uploading(uploadingCount))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            // 移动中
            let movingCount = moveManager.processingTasks.count
            if movingCount > 0 {
                Text("\(movingCount) \(L.Move.Status.moving)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // 等待中
            let pendingCount = uploadManager.pendingTasks.count + moveManager.pendingTasks.count
            if pendingCount > 0 {
                Text(L.Upload.Queue.pending(pendingCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 已完成
            let completedCount = uploadManager.completedTasks.count + moveManager.completedTasks.count
            if completedCount > 0 {
                Text(L.Upload.Queue.completed(completedCount))
                    .font(.caption)
                    .foregroundColor(.green)
            }

            // 失败
            let failedCount = uploadManager.failedTasks.count + moveManager.failedTasks.count
            if failedCount > 0 {
                Text(L.Upload.Queue.failed(failedCount))
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    /// 操作按钮
    private var actionButtons: some View {
        HStack(spacing: 8) {
            let hasFailedTasks = !uploadManager.failedTasks.isEmpty || !moveManager.failedTasks.isEmpty
            if hasFailedTasks {
                Button(L.Upload.Action.retryFailed) {
                    uploadManager.retryAllFailed()
                    for task in moveManager.failedTasks {
                        moveManager.retryTask(task)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            let hasCompletedTasks = !uploadManager.completedTasks.isEmpty || !moveManager.completedTasks.isEmpty
            if hasCompletedTasks {
                Button(L.Upload.Action.clearCompleted) {
                    uploadManager.clearCompleted()
                    moveManager.clearCompleted()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button(action: {
                uploadManager.clearAll()
                moveManager.clearAll()
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
    }

    /// 任务列表
    private var taskListView: some View {
        ScrollView {
            VStack(spacing: 1) {
                // 上传任务
                ForEach(uploadManager.tasks) { task in
                    UploadTaskRow(
                        task: task,
                        onCancel: { uploadManager.cancelTask(task) },
                        onRetry: { uploadManager.retryTask(task) }
                    )
                }

                // 移动任务
                ForEach(moveManager.tasks) { task in
                    MoveTaskRow(
                        task: task,
                        onCancel: { moveManager.cancelTask(task) },
                        onRetry: { moveManager.retryTask(task) }
                    )
                }
            }
        }
        .frame(maxHeight: 200)
    }

    // MARK: - 计算属性

    /// 总进度
    private var overallProgress: Double {
        let uploadProgress = uploadManager.totalProgress * Double(uploadManager.tasks.count)
        let moveProgress = moveManager.totalProgress * Double(moveManager.tasks.count)
        let total = Double(totalTaskCount)
        guard total > 0 else { return 0 }
        return (uploadProgress + moveProgress) / total
    }

    /// 总进度百分比
    private var overallProgressPercent: Int {
        Int(overallProgress * 100)
    }
}

// MARK: - 上传任务行

/// 上传任务行视图
struct UploadTaskRow: View {
    let task: UploadQueueTask
    let onCancel: () -> Void
    let onRetry: () -> Void

    /// 状态显示文本
    private var statusText: String {
        switch task.status {
        case .pending:
            return L.Upload.Status.pending
        case .processing:
            return L.Upload.Status.uploading
        case .completed:
            return L.Upload.Status.completed
        case .failed(let error):
            return L.Upload.Status.failed(error)
        case .cancelled:
            return L.Upload.Status.cancelled
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            Image(systemName: task.status.iconName)
                .foregroundColor(task.status.iconColor)
                .frame(width: 20)

            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                Text(task.fileName)
                    .font(.caption)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(task.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(task.status.iconColor)
                }
            }

            Spacer()

            // 进度或操作按钮
            if task.status == .processing {
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 60)

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

            } else if case .failed = task.status {
                Button(L.Common.Button.retry) {
                    onRetry()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

            } else if task.status == .pending {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(task.status == .processing ? Color.blue.opacity(0.05) : Color.clear)
    }
}

// MARK: - 移动任务行

/// 移动任务行视图
struct MoveTaskRow: View {
    let task: MoveQueueTask
    let onCancel: () -> Void
    let onRetry: () -> Void

    /// 状态显示文本
    private var statusText: String {
        switch task.status {
        case .pending:
            return L.Upload.Status.pending
        case .processing:
            return L.Move.Status.moving
        case .completed:
            return L.Move.Status.completed
        case .failed(let error):
            return L.Move.Status.failed(error)
        case .cancelled:
            return L.Upload.Status.cancelled
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标（移动用橙色区分）
            Image(systemName: task.status == .processing ? "arrow.right.circle.fill" : task.status.iconName)
                .foregroundColor(task.status == .processing ? .orange : task.status.iconColor)
                .frame(width: 20)

            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                Text(task.displayName)
                    .font(.caption)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(task.displayDetail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(task.status == .processing ? .orange : task.status.iconColor)
                }
            }

            Spacer()

            // 进度或操作按钮
            if task.status == .processing {
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 60)
                    .tint(.orange)

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

            } else if case .failed = task.status {
                Button(L.Common.Button.retry) {
                    onRetry()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

            } else if task.status == .pending {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(task.status == .processing ? Color.orange.opacity(0.05) : Color.clear)
    }
}
