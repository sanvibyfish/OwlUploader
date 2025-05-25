//
//  FileListItemView.swift
//  OwlUploader
//
//  Created by Sanvi Lu on 2025/5/25.
//

import SwiftUI

/// 文件列表行视图
/// 用于在文件列表中显示单个文件或文件夹的信息
struct FileListItemView: View {
    /// 要显示的文件对象
    let fileObject: FileObject
    
    /// R2 服务实例（可选，用于生成文件URL）
    var r2Service: R2Service?
    
    /// 存储桶名称（可选，用于生成文件URL）
    var bucketName: String?
    
    /// 消息管理器（可选，用于显示复制成功消息）
    var messageManager: MessageManager?
    
    var body: some View {
        HStack(spacing: 12) {
            // 文件/文件夹图标
            Image(systemName: fileObject.iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                // 文件名
                Text(fileObject.name)
                    .font(.body)
                    .fontWeight(fileObject.isDirectory ? .medium : .regular)
                    .lineLimit(1)
                
                // 详细信息（大小和修改时间）
                HStack(spacing: 8) {
                    // 文件大小（仅文件显示）
                    if !fileObject.isDirectory && !fileObject.formattedSize.isEmpty {
                        Text(fileObject.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 最后修改时间
                    if !fileObject.formattedLastModified.isEmpty {
                        if !fileObject.isDirectory {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(fileObject.formattedLastModified)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 文件夹标识
                    if fileObject.isDirectory {
                        Text("文件夹")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // 文件操作按钮区域
            HStack(spacing: 8) {
                // 复制链接按钮（仅对文件显示）
                if !fileObject.isDirectory, 
                   let r2Service = r2Service,
                   let bucketName = bucketName {
                    Button(action: {
                        copyFileURL()
                    }) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("复制文件链接")
                }
                
                // 文件夹箭头指示器
                if fileObject.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // 使整行可点击
        .onHover { isHovered in
            if fileObject.isDirectory && isHovered {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
    
    /// 图标颜色
    /// 根据文件类型返回不同的颜色
    private var iconColor: Color {
        if fileObject.isDirectory {
            return .blue
        } else if fileObject.isImage {
            return .orange
        } else if fileObject.isVideo {
            return .purple
        } else if fileObject.isAudio {
            return .green
        } else {
            return .primary
        }
    }
    
    /// 复制文件URL到剪贴板
    private func copyFileURL() {
        guard let r2Service = r2Service,
              let bucketName = bucketName else {
            print("❌ 无法复制文件URL：缺少必要参数")
            return
        }
        
        guard let fileURL = r2Service.generateFileURL(for: fileObject, in: bucketName) else {
            print("❌ 无法生成文件URL")
            messageManager?.showError("复制失败", description: "无法生成文件链接")
            return
        }
        
        // 复制到剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fileURL, forType: .string)
        
        print("✅ 文件URL已复制到剪贴板: \(fileURL)")
        messageManager?.showSuccess("复制成功", description: "文件链接已复制到剪贴板")
    }
}

// MARK: - 预览

#Preview("文件夹") {
    FileListItemView(fileObject: FileObject.folder(name: "Documents", key: "documents/"))
        .padding()
}

#Preview("图片文件") {
    FileListItemView(
        fileObject: FileObject.file(
            name: "photo.jpg",
            key: "photos/photo.jpg", 
            size: 2_456_789,
            lastModifiedDate: Date().addingTimeInterval(-86400),
            eTag: "d41d8cd98f00b204e9800998ecf8427e"
        ),
        r2Service: R2Service(),
        bucketName: "test-bucket",
        messageManager: MessageManager()
    )
    .padding()
}

#Preview("文档文件") {
    FileListItemView(
        fileObject: FileObject.file(
            name: "report.pdf",
            key: "documents/report.pdf",
            size: 1_234_567,
            lastModifiedDate: Date().addingTimeInterval(-3600),
            eTag: "e41d8cd98f00b204e9800998ecf8427e"
        ),
        r2Service: R2Service(),
        bucketName: "test-bucket",
        messageManager: MessageManager()
    )
    .padding()
}

#Preview("文件列表预览") {
    List(FileObject.sampleData, id: \.key) { fileObject in
        FileListItemView(
            fileObject: fileObject,
            r2Service: R2Service(),
            bucketName: "test-bucket",
            messageManager: MessageManager()
        )
    }
    .listStyle(PlainListStyle())
} 