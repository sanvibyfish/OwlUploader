//
//  EmptyStateView.swift
//  OwlUploader
//
//  统一的空状态视图组件
//  提供一致的设计语言和精致的视觉效果
//

import SwiftUI

/// 空状态视图
struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var hints: [(icon: String, color: Color, text: String)]? = nil
    
    var body: some View {
        VStack(spacing: 28) {
            // 图标层 - 使用渐变背景
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.08), Color.blue.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)
            }
            
            // 文字区 - 清晰的层次
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 操作按钮（可选）
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            // 操作提示卡片（可选）
            if let hints = hints {
                VStack(spacing: 12) {
                    ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                        ActionHintCard(
                            icon: hint.icon,
                            color: hint.color,
                            text: hint.text
                        )
                    }
                }
                .frame(maxWidth: 360)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .frame(maxWidth: 480)
    }
}

// MARK: - 预览

#Preview("Not Connected") {
    EmptyStateView(
        icon: "network.slash",
        title: "未连接到 R2",
        description: "请先配置你的 Cloudflare R2 账户",
        actionTitle: "配置账户",
        action: {}
    )
    .frame(width: 600, height: 400)
}

#Preview("No Bucket") {
    EmptyStateView(
        icon: "externaldrive",
        title: "选择存储桶",
        description: "请从侧边栏选择一个存储桶来管理文件",
        actionTitle: "浏览存储桶",
        action: {}
    )
    .frame(width: 600, height: 400)
}

#Preview("Empty List") {
    EmptyStateView(
        icon: "folder",
        title: "没有文件",
        description: "此文件夹是空的",
        hints: [
            (icon: "plus.circle.fill", color: .blue, text: "点击上传按钮添加文件"),
            (icon: "folder.badge.plus", color: .green, text: "创建新文件夹组织内容"),
            (icon: "arrow.down.circle.dotted", color: .purple, text: "或直接拖拽文件到此处")
        ]
    )
    .frame(width: 600, height: 400)
}
