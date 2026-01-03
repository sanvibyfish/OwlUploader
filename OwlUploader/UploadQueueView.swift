//
//  UploadQueueView.swift
//  OwlUploader
//
//  上传队列 UI 组件
//  显示上传进度和操作按钮
//

import SwiftUI

/// 上传队列面板视图
struct UploadQueueView: View {
    
    @ObservedObject var queueManager: UploadQueueManager
    
    /// 是否展开面板
    @State private var isExpanded: Bool = true
    
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
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
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

                    Text(L.Upload.Queue.fileCount(queueManager.tasks.count))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 速度和剩余时间
                    if queueManager.hasActiveTasks {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(queueManager.formattedSpeed)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .monospacedDigit()

                        if queueManager.estimatedTimeRemaining > 0 {
                            Text(L.Upload.Queue.remaining(queueManager.formattedETA))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                // 进度信息
                HStack(spacing: 8) {
                    if !queueManager.uploadingTasks.isEmpty {
                        Text(L.Upload.Queue.uploading(queueManager.uploadingTasks.count))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    if !queueManager.pendingTasks.isEmpty {
                        Text(L.Upload.Queue.pending(queueManager.pendingTasks.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !queueManager.completedTasks.isEmpty {
                        Text(L.Upload.Queue.completed(queueManager.completedTasks.count))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if !queueManager.failedTasks.isEmpty {
                        Text(L.Upload.Queue.failed(queueManager.failedTasks.count))
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            Spacer()

            // 总进度（百分比 + 进度条）
            if queueManager.hasActiveTasks {
                HStack(spacing: 6) {
                    Text("\(queueManager.overallProgressPercent)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)

                    ProgressView(value: queueManager.totalProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                }
            }

            // 操作按钮
            HStack(spacing: 8) {
                if !queueManager.failedTasks.isEmpty {
                    Button(L.Upload.Action.retryFailed) {
                        queueManager.retryAllFailed()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if !queueManager.completedTasks.isEmpty {
                    Button(L.Upload.Action.clearCompleted) {
                        queueManager.clearCompleted()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(action: {
                    queueManager.clearAll()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    /// 任务列表
    private var taskListView: some View {
        ScrollView {
            VStack(spacing: 1) {
                ForEach(queueManager.tasks) { task in
                    UploadTaskRow(
                        task: task,
                        onCancel: { queueManager.cancelTask(task) },
                        onRetry: { queueManager.retryTask(task) }
                    )
                }
            }
        }
        .frame(maxHeight: 200)
    }
}

/// 上传任务行
struct UploadTaskRow: View {
    let task: UploadTask
    let onCancel: () -> Void
    let onRetry: () -> Void
    
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
                    
                    Text(task.status.displayText)
                        .font(.caption2)
                        .foregroundColor(task.status.iconColor)
                }
            }
            
            Spacer()
            
            // 进度或操作按钮
            if task.status == .uploading {
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
        .background(task.status == .uploading ? Color.blue.opacity(0.05) : Color.clear)
    }
}

// MARK: - 预览

#Preview("上传队列") {
    let manager = UploadQueueManager()
    
    return VStack {
        Spacer()
        UploadQueueView(queueManager: manager)
            .frame(width: 500)
            .padding()
    }
    .frame(height: 400)
}
