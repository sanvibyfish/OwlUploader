//
//  PathBar.swift
//  OwlUploader
//
//  Finder风格底部路径栏
//  显示当前路径，支持点击导航
//

import SwiftUI

/// 底部路径栏
/// 支持拖拽文件到路径组件上移动到对应目录
struct PathBar: View {
    /// 存储桶名称
    let bucketName: String

    /// 当前路径前缀
    let currentPrefix: String

    /// 导航回调
    let onNavigate: (String) -> Void
    
    /// 移动文件回调：(要移动的文件列表, 目标路径前缀)
    var onMoveFiles: (([DraggedFileItem], String) -> Void)?
    
    /// 当前拖放目标的路径
    @State private var dropTargetPath: String? = nil

    /// 路径组件
    private var pathComponents: [PathComponent] {
        var components: [PathComponent] = []

        // 根目录（存储桶）
        components.append(PathComponent(name: bucketName, path: "", isRoot: true))

        // 解析路径
        if !currentPrefix.isEmpty {
            let parts = currentPrefix.split(separator: "/").map(String.init)
            var accumulatedPath = ""

            for part in parts {
                accumulatedPath += part + "/"
                components.append(PathComponent(name: part, path: accumulatedPath, isRoot: false))
            }
        }

        return components
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(pathComponents) { component in
                    PathBarItem(
                        component: component,
                        isLast: component.id == pathComponents.last?.id,
                        isDropTarget: dropTargetPath == component.path,
                        onTap: {
                            onNavigate(component.path)
                        },
                        onDrop: { items in
                            onMoveFiles?(items, component.path)
                        },
                        onDropTargetChanged: { isTarget in
                            dropTargetPath = isTarget ? component.path : nil
                        }
                    )

                    // 分隔符（非最后一个）
                    if component.id != pathComponents.last?.id {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 22)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 路径组件模型

struct PathComponent: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isRoot: Bool
}

// MARK: - 路径项视图

struct PathBarItem: View {
    let component: PathComponent
    let isLast: Bool
    
    /// 是否为拖放目标
    var isDropTarget: Bool = false
    
    let onTap: () -> Void
    
    /// 拖放回调
    var onDrop: (([DraggedFileItem]) -> Void)?
    
    /// 拖放目标状态变化回调
    var onDropTargetChanged: ((Bool) -> Void)?

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if component.isRoot {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Text(component.name)
                    .font(.system(size: 12))
                    .foregroundColor(isLast ? .primary : .secondary)
                    .fontWeight(isLast ? .medium : .regular)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isDropTarget ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLast)
        .onHover { hovering in
            withAnimation(AppAnimations.hover) {
                isHovering = hovering
            }
        }
        // 拖放目标
        .dropDestination(for: DraggedFileItem.self) { items, _ in
            // 不能拖到自己的子目录
            for item in items {
                if item.isDirectory && component.path.hasPrefix(item.key) {
                    return false
                }
            }
            onDrop?(items)
            return true
        } isTargeted: { isTargeted in
            onDropTargetChanged?(isTargeted)
        }
    }
    
    /// 背景填充色
    private var backgroundFill: Color {
        if isDropTarget {
            return Color.accentColor.opacity(0.2)
        } else if isHovering && !isLast {
            return Color.gray.opacity(0.15)
        } else {
            return Color.clear
        }
    }
}

// MARK: - 预览

#Preview("根目录") {
    VStack {
        PathBar(
            bucketName: "my-bucket",
            currentPrefix: "",
            onNavigate: { path in print("Navigate to: \(path)") }
        )
        Divider()
    }
}

#Preview("子目录") {
    VStack {
        PathBar(
            bucketName: "my-bucket",
            currentPrefix: "images/2024/photos/",
            onNavigate: { path in print("Navigate to: \(path)") }
        )
        Divider()
    }
}
