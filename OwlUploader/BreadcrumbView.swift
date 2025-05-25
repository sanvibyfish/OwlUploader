//
//  BreadcrumbView.swift
//  OwlUploader
//
//  Created by Sanvi Lu on 2025/5/25.
//

import SwiftUI

/// 面包屑导航组件
/// 用于显示当前路径层级，并支持点击任意层级进行跳转
struct BreadcrumbView: View {
    /// 当前路径前缀
    let currentPrefix: String
    
    /// 当前选中的存储桶
    let selectedBucket: BucketItem?
    
    /// 路径跳转回调
    let onNavigate: (String) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            // 存储桶层级（根目录）
            if let bucket = selectedBucket {
                Button(action: {
                    onNavigate("")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "externaldrive")
                            .font(.caption)
                        Text(bucket.name)
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
                        .fill(Color.blue.opacity(0.08))
                        .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
                )
                .onHover { isHovered in
                    NSCursor.pointingHand.set()
                }
                
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
                                         Button(action: {
                         let targetPrefix = pathSegments[0...index].map(\.name).joined(separator: "/") + "/"
                         onNavigate(targetPrefix)
                     }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.caption)
                            Text(segment.name)
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
                            .fill(Color.blue.opacity(0.08))
                            .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
                    )
                    .onHover { isHovered in
                        NSCursor.pointingHand.set()
                    }
                    
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