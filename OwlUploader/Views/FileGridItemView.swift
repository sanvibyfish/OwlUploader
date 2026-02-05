//
//  FileGridItemView.swift
//  OwlUploader
//
//  Finder风格图标视图项
//  用于网格布局中显示单个文件/文件夹
//

import SwiftUI

/// 网格项视图
struct FileGridItemView: View {
    let fileObject: FileObject

    /// 是否被选中
    var isSelected: Bool = false

    /// 图标尺寸
    var iconSize: CGFloat = 64

    // Dependencies
    var r2Service: R2Service?
    var bucketName: String?
    var messageManager: MessageManager?

    // Actions
    var onDeleteFile: ((FileObject) -> Void)?
    var onDownloadFile: ((FileObject) -> Void)?
    var onTap: (() -> Void)?
    var onDoubleTap: (() -> Void)?

    /// 预览文件回调
    var onPreview: ((FileObject) -> Void)?

    /// 新建文件夹回调
    var onCreateFolder: (() -> Void)?

    /// 上传文件回调
    var onUpload: (() -> Void)?

    /// 移动到指定路径回调：(文件, 目标路径)
    var onMoveToPath: ((FileObject, String) -> Void)?

    /// 重命名回调
    var onRename: ((FileObject) -> Void)?

    /// 刷新 CDN 缓存回调
    var onPurgeCDNCache: ((FileObject) -> Void)?

    /// 当前目录下的文件夹列表（用于移动到子菜单）
    var currentFolders: [FileObject] = []

    /// 当前路径前缀
    var currentPrefix: String = ""

    @State private var isHovering = false

    /// 缩略图URL（带版本参数，用于绕过 CDN 缓存）
    private var thumbnailURL: String? {
        guard fileObject.isImage,
              let r2Service = r2Service,
              let bucketName = bucketName else { return nil }
        return r2Service.generateThumbnailURL(for: fileObject, in: bucketName)
    }

    // MARK: - 样式计算属性（简化类型推断）

    private var hoverBackgroundColor: Color {
        isHovering && !isSelected ? Color.gray.opacity(0.08) : Color.clear
    }

    private var selectionBorderColor: Color {
        isSelected ? AppColors.primary.opacity(0.3) : Color.clear
    }


    // MARK: - 视图组件

    private var contentView: some View {
        VStack(spacing: 6) {
            iconView
            nameView
        }
        .padding(8)
    }

    private var hoverBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(hoverBackgroundColor)
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(selectionBorderColor, lineWidth: 2)
    }


    @ViewBuilder
    private var contextMenuContent: some View {
        // 预览（仅文件显示）
        if !fileObject.isDirectory {
            Button(action: { onPreview?(fileObject) }) {
                Label(L.Files.ContextMenu.preview, systemImage: "eye")
            }
            Divider()
        }

        // 新建文件夹和上传（始终显示）
        Button(action: { onCreateFolder?() }) {
            Label(L.Files.ContextMenu.newFolder, systemImage: "folder.badge.plus")
        }
        Button(action: { onUpload?() }) {
            Label(L.Files.ContextMenu.upload, systemImage: "arrow.up.circle")
        }
        Divider()

        // 下载（文件和文件夹都支持）
        Button(action: { onDownloadFile?(fileObject) }) {
            Label(L.Files.ContextMenu.download, systemImage: "arrow.down.circle")
        }

        // 复制链接（仅文件显示）
        if !fileObject.isDirectory {
            Button(action: copyFileURL) {
                Label(L.Files.ContextMenu.copyLink, systemImage: "link")
            }

            // 刷新 CDN 缓存
            Button(action: { onPurgeCDNCache?(fileObject) }) {
                Label(L.Files.ContextMenu.purgeCDNCache, systemImage: "arrow.triangle.2.circlepath")
            }
        }

        Divider()

        // 移动到子菜单
        moveToMenu

        // 重命名
        Button(action: { onRename?(fileObject) }) {
            Label(L.Files.ContextMenu.rename, systemImage: "pencil")
        }

        Divider()

        Button(role: .destructive, action: { onDeleteFile?(fileObject) }) {
            Label(L.Files.ContextMenu.delete, systemImage: "trash")
        }
    }

    /// 移动到子菜单
    @ViewBuilder
    private var moveToMenu: some View {
        let availableFolders = currentFolders.filter { $0.key != fileObject.key && !$0.key.hasPrefix(fileObject.key) }
        let hasParent = !currentPrefix.isEmpty
        let hasTargets = hasParent || !availableFolders.isEmpty

        if hasTargets {
            Menu {
                // 上级目录
                if hasParent {
                    Button(action: {
                        let parentPath = getParentPath(of: currentPrefix)
                        onMoveToPath?(fileObject, parentPath)
                    }) {
                        Label(L.Files.ContextMenu.parentFolder, systemImage: "folder")
                    }

                    if !availableFolders.isEmpty {
                        Divider()
                    }
                }

                // 当前目录下的文件夹
                ForEach(availableFolders) { folder in
                    Button(action: {
                        onMoveToPath?(fileObject, folder.key)
                    }) {
                        Label(folder.name, systemImage: "folder.fill")
                    }
                }
            } label: {
                Label(L.Files.ContextMenu.moveTo, systemImage: "folder")
            }
        }
    }

    /// 获取上级目录路径
    private func getParentPath(of path: String) -> String {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        if let lastSlash = trimmed.lastIndex(of: "/") {
            return String(trimmed[..<lastSlash]) + "/"
        }
        return ""
    }

    var body: some View {
        contentView
            .background(hoverBackground)
            .overlay(selectionBorder)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(AppAnimations.hover) {
                    isHovering = hovering
                }
            }
            .animation(AppAnimations.selection, value: isSelected)
            .onTapGesture(count: 2) {
                onDoubleTap?()
            }
            .onTapGesture(count: 1) {
                onTap?()
            }
            .contextMenu { contextMenuContent }
    }

    private var iconView: some View {
        ZStack {
            if fileObject.isImage, let url = thumbnailURL {
                // 图片文件显示缩略图
                AsyncThumbnailView(urlString: url, size: iconSize) {
                    // 加载中显示占位图标
                    Image(systemName: "photo.fill")
                        .font(.system(size: iconSize * 0.5))
                        .foregroundColor(.purple.opacity(0.5))
                        .frame(width: iconSize, height: iconSize)
                }
            } else {
                // 其他文件显示图标
                fileIcon
                    .font(.system(size: iconSize * 0.6))
            }
        }
        .frame(width: iconSize, height: iconSize)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? AppColors.primary.opacity(0.15) : Color.clear)
        )
    }

    private var nameView: some View {
        Text(fileObject.name)
            .font(.system(size: 11))
            .foregroundColor(AppColors.textPrimary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .truncationMode(.middle)
            .frame(width: iconSize + 20)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? AppColors.primary : Color.clear)
            )
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
    }

    private var fileIcon: some View {
        Group {
            if fileObject.isDirectory {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
            } else if fileObject.isImage {
                Image(systemName: "photo.fill")
                    .foregroundColor(.purple)
            } else if fileObject.name.hasSuffix(".pdf") {
                Image(systemName: "doc.fill")
                    .foregroundColor(.red)
            } else if fileObject.name.hasSuffix(".zip") || fileObject.name.hasSuffix(".rar") {
                Image(systemName: "doc.zipper")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "doc.fill")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func copyFileURL() {
        guard let r2Service = r2Service,
              let bucketName = bucketName else { return }

        guard let fileURL = r2Service.generateFileURL(for: fileObject, in: bucketName) else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fileURL, forType: .string)
        messageManager?.showSuccess(L.Message.Success.linkCopied, description: L.Message.Success.linkCopiedDescription)
    }
}

// MARK: - 预览

#Preview("Selected") {
    HStack {
        FileGridItemView(
            fileObject: FileObject(
                name: "photo.jpg",
                key: "images/photo.jpg",
                size: 1024 * 1024,
                lastModifiedDate: Date(),
                isDirectory: false,
                eTag: "abc"
            ),
            isSelected: true
        )

        FileGridItemView(
            fileObject: FileObject(
                name: "Documents",
                key: "Documents/",
                size: nil,
                lastModifiedDate: nil,
                isDirectory: true
            ),
            isSelected: false
        )
    }
    .padding()
}
