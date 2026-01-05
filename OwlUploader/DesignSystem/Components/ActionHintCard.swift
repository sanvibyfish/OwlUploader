//
//  ActionHintCard.swift
//  OwlUploader
//
//  操作提示卡片组件
//  用于空状态视图中显示操作建议
//

import SwiftUI

/// 操作提示卡片
struct ActionHintCard: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            // 文字
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 12) {
        ActionHintCard(
            icon: "plus.circle.fill",
            color: .blue,
            text: "点击上传按钮添加文件"
        )
        
        ActionHintCard(
            icon: "folder.badge.plus",
            color: .green,
            text: "创建新文件夹组织内容"
        )
        
        ActionHintCard(
            icon: "arrow.down.circle.dotted",
            color: .purple,
            text: "或直接拖拽文件到此处"
        )
    }
    .padding()
    .frame(width: 350)
}
