//
//  BreadcrumbView.swift
//  OwlUploader
//
//  Created by Sanvi Lu on 2025/5/25.
//

import SwiftUI

/// 面包屑导航组件
/// 用于显示当前路径层级，并支持点击任意层级进行跳转
/// 支持拖拽文件到面包屑上移动到对应目录
struct BreadcrumbView: View {
    /// 当前路径前缀
    let currentPrefix: String
    
    /// 当前选中的存储桶
    let selectedBucket: BucketItem?
    
    /// 路径跳转回调
    let onNavigate: (String) -> Void
    
    /// 移动文件回调：(要移动的文件列表, 目标路径前缀)
    var onMoveFiles: (([DraggedFileItem], String) -> Void)?
    
    /// 当前拖放目标的路径
    @State private var dropTargetPath: String? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            // 存储桶层级（根目录）
            if let bucket = selectedBucket {
                BreadcrumbSegmentView(
                    icon: "externaldrive",
                    title: bucket.name,
                    targetPath: "",
                    isDropTarget: dropTargetPath == "",
                    onTap: { onNavigate("") },
                    onDrop: { items in
                        onMoveFiles?(items, "")
                    },
                    onDropTargetChanged: { isTarget in
                        dropTargetPath = isTarget ? "" : nil
                    }
                )
                
                // 路径分隔符
                if !currentPrefix.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 路径层级
            ForEach(Array(pathSegments.enumerated()), id: \.offset) { index, segment in
                HStack(spacing: 4) {
                    BreadcrumbSegmentView(
                        icon: "folder",
                        title: segment.name,
                        targetPath: segment.path,
                        isDropTarget: dropTargetPath == segment.path,
                        onTap: {
                            let targetPrefix = pathSegments[0...index].map(\.name).joined(separator: "/") + "/"
                            onNavigate(targetPrefix)
                        },
                        onDrop: { items in
                            onMoveFiles?(items, segment.path)
                        },
                        onDropTargetChanged: { isTarget in
                            dropTargetPath = isTarget ? segment.path : nil
                        }
                    )
                    
                    // 路径分隔符（非最后一个）
                    if index < pathSegments.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    /// 路径段数组
    /// 将当前路径前缀解析为可显示的路径段
    private var pathSegments: [PathSegment] {
        guard !currentPrefix.isEmpty else { return [] }
        
        // 移除末尾的斜杠并分割路径
        let trimmedPrefix = currentPrefix.hasSuffix("/") ? String(currentPrefix.dropLast()) : currentPrefix
        let components = trimmedPrefix.split(separator: "/").map(String.init)
        
        return components.enumerated().map { index, component in
            PathSegment(
                name: component,
                path: components[0...index].joined(separator: "/") + "/"
            )
        }
    }
}

/// 路径段数据结构
/// 表示面包屑导航中的一个路径层级
private struct PathSegment {
    /// 显示名称
    let name: String
    
    /// 完整路径
    let path: String
}

// MARK: - 面包屑段视图（支持拖放）

/// 面包屑导航中的单个段视图
/// 支持点击导航和拖放文件
private struct BreadcrumbSegmentView: View {
    /// 图标名称
    let icon: String
    
    /// 显示标题
    let title: String
    
    /// 目标路径
    let targetPath: String
    
    /// 是否为拖放目标
    let isDropTarget: Bool
    
    /// 点击回调
    let onTap: () -> Void
    
    /// 拖放回调
    let onDrop: ([DraggedFileItem]) -> Void
    
    /// 拖放目标状态变化回调
    let onDropTargetChanged: (Bool) -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.blue)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDropTarget ? Color.accentColor.opacity(0.2) : Color.blue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isDropTarget ? Color.accentColor : Color.blue.opacity(0.2), lineWidth: isDropTarget ? 2 : 0.5)
        )
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.set()
            }
        }
        // 拖放目标
        .dropDestination(for: DraggedFileItem.self) { items, _ in
            // 不能拖到自己的子目录
            for item in items {
                if item.isDirectory && targetPath.hasPrefix(item.key) {
                    return false
                }
            }
            onDrop(items)
            return true
        } isTargeted: { isTargeted in
            onDropTargetChanged(isTargeted)
        }
    }
}

// MARK: - 预览

#Preview("根目录") {
    BreadcrumbView(
        currentPrefix: "",
        selectedBucket: BucketItem.sampleData.first,
        onNavigate: { path in
            print("导航到: \(path)")
        }
    )
    .padding()
}

#Preview("一级目录") {
    BreadcrumbView(
        currentPrefix: "documents/",
        selectedBucket: BucketItem.sampleData.first,
        onNavigate: { path in
            print("导航到: \(path)")
        }
    )
    .padding()
}

#Preview("多级目录") {
    BreadcrumbView(
        currentPrefix: "documents/projects/ios-app/",
        selectedBucket: BucketItem.sampleData.first,
        onNavigate: { path in
            print("导航到: \(path)")
        }
    )
    .padding()
}

#Preview("长路径") {
    BreadcrumbView(
        currentPrefix: "very-long-folder-name/another-very-long-folder/third-level-folder/",
        selectedBucket: BucketItem.sampleData.first,
        onNavigate: { path in
            print("导航到: \(path)")
        }
    )
    .padding()
} 