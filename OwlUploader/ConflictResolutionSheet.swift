//
//  ConflictResolutionSheet.swift
//  OwlUploader
//
//  文件冲突解决对话框
//

import SwiftUI

/// 冲突解决对话框
struct ConflictResolutionSheet: View {
    /// 冲突信息
    let conflict: FileConflict
    
    /// 剩余冲突数量
    let remainingCount: Int
    
    /// 解决结果回调
    let onResolve: (ConflictResolution, Bool) -> Void
    
    /// 是否应用到所有冲突
    @State private var applyToAll: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题区域
            headerView
            
            Divider()
            
            // 内容区域
            contentView
            
            Divider()
            
            // 按钮区域
            buttonView
        }
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - 子视图
    
    /// 标题区域
    private var headerView: some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("文件已存在")
                    .font(.headline)
                
                Text("目标位置已存在同名\(conflict.isDirectory ? "文件夹" : "文件")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
    }
    
    /// 内容区域
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 冲突文件信息
            HStack(spacing: 12) {
                // 文件图标
                Image(systemName: conflict.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 36))
                    .foregroundColor(conflict.isDirectory ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(conflict.fileName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                    
                    Text("将被移动到的位置已存在")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            
            // 应用到所有选项
            if remainingCount > 0 {
                Toggle(isOn: $applyToAll) {
                    Text("对剩余 \(remainingCount) 个冲突应用相同操作")
                        .font(.subheadline)
                }
                .toggleStyle(.checkbox)
            }
        }
        .padding(20)
    }
    
    /// 按钮区域
    private var buttonView: some View {
        HStack(spacing: 12) {
            // 取消按钮
            Button(action: { onResolve(.cancel, applyToAll) }) {
                Text("取消")
                    .frame(minWidth: 60)
            }
            .keyboardShortcut(.escape)
            
            Spacer()
            
            // 跳过按钮
            Button(action: { onResolve(.skip, applyToAll) }) {
                Label("跳过", systemImage: "arrow.right.to.line")
            }
            .keyboardShortcut("s", modifiers: .command)
            
            // 保留两者按钮
            Button(action: { onResolve(.rename, applyToAll) }) {
                Label("保留两者", systemImage: "doc.badge.plus")
            }
            .keyboardShortcut("k", modifiers: .command)
            
            // 替换按钮
            Button(action: { onResolve(.replace, applyToAll) }) {
                Label("替换", systemImage: "arrow.triangle.swap")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return)
        }
        .padding(20)
    }
}

// MARK: - 预览

#Preview {
    ConflictResolutionSheet(
        conflict: FileConflict(
            sourceKey: "folder/document.pdf",
            destinationKey: "target/document.pdf",
            fileName: "document.pdf",
            isDirectory: false
        ),
        remainingCount: 3,
        onResolve: { resolution, applyToAll in
            print("Resolution: \(resolution), Apply to all: \(applyToAll)")
        }
    )
}
