//
//  UploadConflictSheet.swift
//  OwlUploader
//
//  上传冲突处理弹窗（macOS 原生风格）
//  参考 Finder 的文件替换对话框设计
//

import SwiftUI

/// 冲突处理动作
enum ConflictAction: Equatable {
    case replace    // 替换
    case keepBoth   // 保留两者（自动重命名）
    case skip       // 跳过
}

/// 上传冲突信息
struct UploadConflict: Identifiable, Equatable {
    let id = UUID()
    let localURL: URL
    let remotePath: String
    let localFileName: String
    let localFileSize: Int64
    let localModDate: Date?
    let remoteFileSize: Int64?
    let remoteModDate: Date?

    static func == (lhs: UploadConflict, rhs: UploadConflict) -> Bool {
        lhs.id == rhs.id
    }
}

/// 上传冲突数据包装（用于 sheet(item:) 方式）
struct UploadConflictData: Identifiable {
    let id = UUID()
    let conflicts: [UploadConflict]
}

/// 上传冲突处理弹窗（macOS 原生风格）
struct UploadConflictSheet: View {
    let conflicts: [UploadConflict]
    let onResolution: ([UUID: ConflictAction]) -> Void
    let onCancel: () -> Void

    /// 当前处理的冲突索引
    @State private var currentIndex: Int = 0

    /// 是否应用到全部剩余冲突
    @State private var applyToAll: Bool = false

    /// 已处理的冲突结果
    @State private var resolutions: [UUID: ConflictAction] = [:]

    var body: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .padding(.top, 24)

            // 标题和内容
            if currentIndex < conflicts.count {
                let conflict = conflicts[currentIndex]

                // 标题
                Text(L.Upload.Conflict.titleWithName(conflict.localFileName))
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)

                // 文件信息对比
                fileComparisonView(conflict)
                    .padding(.horizontal, 24)

                // 多文件时显示「应用到全部」
                if conflicts.count - currentIndex > 1 {
                    Toggle(L.Upload.Conflict.applyToAllRemaining(conflicts.count - currentIndex), isOn: $applyToAll)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))
                        .padding(.horizontal, 24)
                }
            }

            Spacer(minLength: 12)

            // 按钮区域
            HStack(spacing: 12) {
                Button(L.Upload.Conflict.Action.stop) {
                    handleStop()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(L.Upload.Conflict.Action.skip) {
                    handleAction(.skip)
                }

                Button(L.Upload.Conflict.Action.keepBoth) {
                    handleAction(.keepBoth)
                }

                Button(L.Upload.Conflict.Action.replace) {
                    handleAction(.replace)
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 450, height: 380)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - 文件对比视图

    private func fileComparisonView(_ conflict: UploadConflict) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 新文件（要上传的）
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.Upload.Conflict.newFile)
                        .font(.system(size: 12, weight: .medium))

                    HStack(spacing: 6) {
                        Text(formatFileSize(conflict.localFileSize))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        if let date = conflict.localModDate {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(formatDate(date))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)

            Divider()
                .padding(.leading, 46)

            // 现有文件（远程的）
            HStack(spacing: 10) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.Upload.Conflict.existingFile)
                        .font(.system(size: 12, weight: .medium))

                    HStack(spacing: 6) {
                        if let size = conflict.remoteFileSize {
                            Text(formatFileSize(size))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        if let date = conflict.remoteModDate {
                            if conflict.remoteFileSize != nil {
                                Text("·")
                                    .foregroundColor(.secondary)
                            }
                            Text(formatDate(date))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 操作处理

    private func handleAction(_ action: ConflictAction) {
        guard currentIndex < conflicts.count else { return }
        let conflict = conflicts[currentIndex]

        if applyToAll {
            // 应用到所有剩余冲突
            for i in currentIndex..<conflicts.count {
                resolutions[conflicts[i].id] = action
            }
            onResolution(resolutions)
        } else {
            // 只处理当前冲突
            resolutions[conflict.id] = action
            currentIndex += 1

            if currentIndex >= conflicts.count {
                onResolution(resolutions)
            }
        }
    }

    private func handleStop() {
        // 跳过所有剩余冲突
        for i in currentIndex..<conflicts.count {
            resolutions[conflicts[i].id] = .skip
        }
        onCancel()
    }

    // MARK: - 格式化

    private func formatFileSize(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 预览

#Preview("Single Conflict") {
    UploadConflictSheet(
        conflicts: [
            UploadConflict(
                localURL: URL(fileURLWithPath: "/tmp/photo.jpg"),
                remotePath: "images/photo.jpg",
                localFileName: "photo.jpg",
                localFileSize: 2_456_789,
                localModDate: Date(),
                remoteFileSize: 1_234_567,
                remoteModDate: Date().addingTimeInterval(-86400)
            )
        ],
        onResolution: { _ in },
        onCancel: { }
    )
}

#Preview("Multiple Conflicts") {
    UploadConflictSheet(
        conflicts: [
            UploadConflict(
                localURL: URL(fileURLWithPath: "/tmp/photo1.jpg"),
                remotePath: "images/photo1.jpg",
                localFileName: "photo1.jpg",
                localFileSize: 2_456_789,
                localModDate: Date(),
                remoteFileSize: 1_234_567,
                remoteModDate: Date().addingTimeInterval(-86400)
            ),
            UploadConflict(
                localURL: URL(fileURLWithPath: "/tmp/document.pdf"),
                remotePath: "docs/document.pdf",
                localFileName: "document.pdf",
                localFileSize: 5_678_901,
                localModDate: Date().addingTimeInterval(-3600),
                remoteFileSize: 4_567_890,
                remoteModDate: Date().addingTimeInterval(-172800)
            )
        ],
        onResolution: { _ in },
        onCancel: { }
    )
}
