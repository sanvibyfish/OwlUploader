//
//  PathBar.swift
//  OwlUploader
//
//  Finder风格底部路径栏
//  显示当前路径，支持点击导航
//

import SwiftUI

/// 底部路径栏
struct PathBar: View {
    /// 存储桶名称
    let bucketName: String

    /// 当前路径前缀
    let currentPrefix: String

    /// 导航回调
    let onNavigate: (String) -> Void

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
                        onTap: {
                            onNavigate(component.path)
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
    let onTap: () -> Void

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
                    .fill(isHovering && !isLast ? Color.gray.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLast)
        .onHover { hovering in
            withAnimation(AppAnimations.hover) {
                isHovering = hovering
            }
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
