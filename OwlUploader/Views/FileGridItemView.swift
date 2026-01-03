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

    @State private var isHovering = false

    /// 缩略图URL
    private var thumbnailURL: String? {
        guard fileObject.isImage,
              let r2Service = r2Service,
              let bucketName = bucketName else { return nil }
        return r2Service.generateFileURL(for: fileObject, in: bucketName)
    }

    var body: some View {
        VStack(spacing: 6) {
            // 图标或缩略图
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

            // 文件名
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
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering && !isSelected ? Color.gray.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? AppColors.primary.opacity(0.3) : Color.clear, lineWidth: 2)
        )
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
        .contextMenu {
            if !fileObject.isDirectory {
                Button(action: { onDownloadFile?(fileObject) }) {
                    Label(L.Files.ContextMenu.download, systemImage: "arrow.down.circle")
                }
                Button(action: copyFileURL) {
                    Label(L.Files.ContextMenu.copyLink, systemImage: "link")
                }
                Divider()
            }
            Button(role: .destructive, action: { onDeleteFile?(fileObject) }) {
                Label(L.Files.ContextMenu.delete, systemImage: "trash")
            }
        }
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
