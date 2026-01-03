//
//  FileTableView.swift
//  OwlUploader
//
//  Finder风格表格视图
//  带可排序列头的文件列表
//

import SwiftUI

/// 表格视图
struct FileTableView: View {
    /// 文件列表
    let files: [FileObject]

    /// 选择管理器
    @ObservedObject var selectionManager: SelectionManager

    /// 排序方式
    @Binding var sortOrder: FileSortOrder

    // Dependencies
    var r2Service: R2Service?
    var bucketName: String?
    var messageManager: MessageManager?

    // Actions
    var onNavigate: ((FileObject) -> Void)?
    var onDeleteFile: ((FileObject) -> Void)?
    var onDownloadFile: ((FileObject) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 列头
            TableHeader(sortOrder: $sortOrder)

            Divider()

            // 文件列表
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(files) { file in
                        FileTableRow(
                            fileObject: file,
                            isSelected: selectionManager.isSelected(file),
                            r2Service: r2Service,
                            bucketName: bucketName,
                            messageManager: messageManager,
                            onDeleteFile: onDeleteFile,
                            onDownloadFile: onDownloadFile,
                            onTap: {
                                handleTap(file)
                            },
                            onDoubleTap: {
                                handleDoubleTap(file)
                            }
                        )

                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .background(AppColors.contentBackground)
            .onTapGesture {
                selectionManager.clearSelection()
            }
        }
    }

    // MARK: - 私有方法

    private func handleTap(_ file: FileObject) {
        let modifiers = NSEvent.modifierFlags
        let mode = SelectionManager.modeFromModifiers(modifiers)
        selectionManager.select(file, mode: mode, allFiles: files)
    }

    private func handleDoubleTap(_ file: FileObject) {
        // 双击：文件夹进入，文件预览
        onNavigate?(file)
    }
}

// MARK: - 表格列头

struct TableHeader: View {
    @Binding var sortOrder: FileSortOrder

    var body: some View {
        HStack(spacing: 0) {
            // 名称列
            TableColumnHeader(
                title: L.Files.TableColumn.name,
                isActive: sortOrder == .name || sortOrder == .nameDescending,
                isAscending: sortOrder == .name,
                width: nil
            ) {
                toggleSort(.name, .nameDescending)
            }

            // 大小列
            TableColumnHeader(
                title: L.Files.TableColumn.size,
                isActive: sortOrder == .size || sortOrder == .sizeDescending,
                isAscending: sortOrder == .size,
                width: 80
            ) {
                toggleSort(.size, .sizeDescending)
            }

            // 修改日期列
            TableColumnHeader(
                title: L.Files.TableColumn.modified,
                isActive: sortOrder == .date || sortOrder == .dateDescending,
                isAscending: sortOrder == .date,
                width: 120
            ) {
                toggleSort(.date, .dateDescending)
            }

            // 占位（操作区域）
            Spacer()
                .frame(width: 80)
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func toggleSort(_ ascending: FileSortOrder, _ descending: FileSortOrder) {
        if sortOrder == ascending {
            sortOrder = descending
        } else {
            sortOrder = ascending
        }
    }
}

// MARK: - 列头组件

struct TableColumnHeader: View {
    let title: String
    let isActive: Bool
    let isAscending: Bool
    let width: CGFloat?
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? AppColors.primary : AppColors.textSecondary)

                if isActive {
                    Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: width ?? .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isHovering ? Color.gray.opacity(0.1) : Color.clear
        )
        .onHover { hovering in
            withAnimation(AppAnimations.hover) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - 表格行

struct FileTableRow: View {
    let fileObject: FileObject
    var isSelected: Bool = false

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

    var body: some View {
        HStack(spacing: 0) {
            // 图标 + 名称
            HStack(spacing: 10) {
                fileIcon
                    .font(.system(size: 16))
                    .frame(width: 20)

                Text(fileObject.name)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()
            }

            // 大小
            Text(fileObject.isDirectory ? "--" : fileObject.formattedSize)
                .font(.system(size: 12).monospacedDigit())
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 80, alignment: .leading)

            // 修改日期
            Text(fileObject.formattedLastModified)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 120, alignment: .leading)

            // 操作按钮
            HStack(spacing: 8) {
                if isHovering && !fileObject.isDirectory {
                    Button(action: { onDownloadFile?(fileObject) }) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .help(L.Help.download)

                    Button(action: copyFileURL) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .help(L.Help.copyLink)

                    Button(action: { onDeleteFile?(fileObject) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.destructive)
                    }
                    .buttonStyle(.plain)
                    .help(L.Help.delete)
                }
            }
            .frame(width: 80)
            .transition(AppTransitions.hoverActions)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundFillColor)
        .overlay(
            Rectangle()
                .strokeBorder(isSelected ? AppColors.primary.opacity(0.5) : Color.clear, lineWidth: 1)
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

    private var backgroundFillColor: Color {
        if isSelected {
            return AppColors.primary.opacity(0.12)
        } else if isHovering {
            return Color.gray.opacity(0.06)
        } else {
            return Color.clear
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

#Preview {
    FileTableView(
        files: [
            FileObject(name: "Documents", key: "Documents/", size: nil, lastModifiedDate: nil, isDirectory: true),
            FileObject(name: "photo.jpg", key: "photo.jpg", size: 1024 * 512, lastModifiedDate: Date(), isDirectory: false, eTag: "a"),
            FileObject(name: "document.pdf", key: "document.pdf", size: 2048 * 1024, lastModifiedDate: Date(), isDirectory: false, eTag: "b"),
        ],
        selectionManager: SelectionManager(),
        sortOrder: .constant(.name)
    )
    .frame(width: 600, height: 300)
}
