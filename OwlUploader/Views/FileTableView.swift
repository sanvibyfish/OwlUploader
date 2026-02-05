//
//  FileTableView.swift
//  OwlUploader
//
//  Finder风格表格视图
//  使用 macOS 原生 Table 组件
//

import SwiftUI

/// 表格视图 - 使用原生 Table 组件
struct FileTableView: View {
    /// 文件列表
    let files: [FileObject]

    /// 选择管理器
    @ObservedObject var selectionManager: SelectionManager

    /// 排序方式
    @Binding var sortOrder: FileSortOrder
    
    /// 排序方向（true = 升序，false = 降序）
    @Binding var sortAscending: Bool

    // Dependencies
    var r2Service: R2Service?
    var bucketName: String?
    var messageManager: MessageManager?

    // Actions
    var onNavigate: ((FileObject) -> Void)?
    var onDeleteFile: ((FileObject) -> Void)?
    var onDownloadFile: ((FileObject) -> Void)?

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

    /// 原生 Table 使用的选择状态
    @State private var tableSelection: Set<String> = []
    
    /// 计算型排序 Binding：将 sortOrder + sortAscending 映射为 Table 所需的 KeyPathComparator
    /// 避免使用 @State + onChange 的循环同步问题
    private var sortComparatorBinding: Binding<[KeyPathComparator<FileObject>]> {
        Binding(
            get: { Self.comparators(from: sortOrder, ascending: sortAscending) },
            set: { newValue in
                let (order, ascending) = Self.sortOrder(from: newValue)
                sortOrder = order
                sortAscending = ascending
            }
        )
    }

    /// 从 FileSortOrder + ascending 生成 KeyPathComparator 数组
    static func comparators(from sortOrder: FileSortOrder, ascending: Bool) -> [KeyPathComparator<FileObject>] {
        let order: SortOrder = ascending ? .forward : .reverse
        switch sortOrder {
        case .name: return [KeyPathComparator(\.name, order: order)]
        case .kind: return [KeyPathComparator(\.sortableKind, order: order)]
        case .dateModified: return [KeyPathComparator(\.sortableDate, order: order)]
        case .size: return [KeyPathComparator(\.sortableSize, order: order)]
        }
    }

    /// 从 KeyPathComparator 数组反解出 FileSortOrder + ascending
    static func sortOrder(from comparators: [KeyPathComparator<FileObject>]) -> (FileSortOrder, Bool) {
        guard let first = comparators.first else { return (.name, true) }
        let keyPathString = String(describing: first.keyPath)
        let order: FileSortOrder
        if keyPathString.contains("sortableSize") {
            order = .size
        } else if keyPathString.contains("sortableKind") {
            order = .kind
        } else if keyPathString.contains("sortableDate") {
            order = .dateModified
        } else {
            order = .name
        }
        return (order, first.order == .forward)
    }

    var body: some View {
        Table(files, selection: $tableSelection, sortOrder: sortComparatorBinding) {
            // 名称列
            TableColumn(L.Files.TableColumn.name, value: \.name) { file in
                FileNameCell(
                    fileObject: file,
                    r2Service: r2Service,
                    bucketName: bucketName
                )
            }
            .width(min: 200)

            // 修改日期列
            TableColumn(L.Files.TableColumn.modified, value: \.sortableDate) { file in
                Text(file.formattedLastModified)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            .width(140)

            // 大小列
            TableColumn(L.Files.TableColumn.size, value: \.sortableSize) { file in
                Text(file.isDirectory ? "--" : file.formattedSize)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
            }
            .width(90)

            // 类型列 (Kind)
            TableColumn(L.Files.TableColumn.kind, value: \.sortableKind) { file in
                Text(file.kindDescription)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            .width(100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        // 双击和右键菜单
        .contextMenu(forSelectionType: String.self) { selectedIDs in
            // 右键菜单
            if let firstID = selectedIDs.first,
               let file = files.first(where: { $0.id == firstID }) {
                // 有选中文件时的完整菜单
                // 预览（仅文件显示）
                if !file.isDirectory {
                    Button(action: { onPreview?(file) }) {
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
                Button(action: { onDownloadFile?(file) }) {
                    Label(L.Files.ContextMenu.download, systemImage: "arrow.down.circle")
                }

                // 复制链接（仅文件显示）
                if !file.isDirectory {
                    Button(action: { copyFileURL(file) }) {
                        Label(L.Files.ContextMenu.copyLink, systemImage: "link")
                    }

                    // 刷新 CDN 缓存
                    Button(action: { onPurgeCDNCache?(file) }) {
                        Label(L.Files.ContextMenu.purgeCDNCache, systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                Divider()

                // 移动到子菜单
                moveToMenu(for: file)

                // 重命名
                Button(action: { onRename?(file) }) {
                    Label(L.Files.ContextMenu.rename, systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive, action: { onDeleteFile?(file) }) {
                    Label(L.Files.ContextMenu.delete, systemImage: "trash")
                }
            } else {
                // 未选中文件时的简化菜单（空白区域右键）
                Button(action: { onCreateFolder?() }) {
                    Label(L.Files.ContextMenu.newFolder, systemImage: "folder.badge.plus")
                }
                Button(action: { onUpload?() }) {
                    Label(L.Files.ContextMenu.upload, systemImage: "arrow.up.circle")
                }
            }
        } primaryAction: { selectedIDs in
            // 双击操作
            if let firstID = selectedIDs.first,
               let file = files.first(where: { $0.id == firstID }) {
                onNavigate?(file)
            }
        }
        // 同步选择状态
        .onChange(of: tableSelection) { _, newValue in
            syncSelectionToManager(newValue)
        }
        .onChange(of: selectionManager.selectedIDs) { _, newValue in
            if tableSelection != newValue {
                tableSelection = newValue
            }
        }
        .onAppear {
            tableSelection = selectionManager.selectedIDs
        }
    }

    // MARK: - 私有方法

    /// 同步原生选择到 SelectionManager
    private func syncSelectionToManager(_ ids: Set<String>) {
        let selectedFiles = files.filter { ids.contains($0.id) }
        selectionManager.setSelection(selectedFiles)
    }

    /// 复制文件 URL
    private func copyFileURL(_ file: FileObject) {
        guard let r2Service = r2Service,
              let bucketName = bucketName else { return }

        guard let fileURL = r2Service.generateFileURL(for: file, in: bucketName) else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fileURL, forType: .string)
        messageManager?.showSuccess(L.Message.Success.linkCopied, description: L.Message.Success.linkCopiedDescription)
    }

    /// 移动到子菜单
    @ViewBuilder
    private func moveToMenu(for file: FileObject) -> some View {
        let availableFolders = currentFolders.filter { $0.key != file.key && !$0.key.hasPrefix(file.key) }
        let hasParent = !currentPrefix.isEmpty
        let hasTargets = hasParent || !availableFolders.isEmpty

        if hasTargets {
            Menu {
                // 上级目录
                if hasParent {
                    Button(action: {
                        let parentPath = getParentPath(of: currentPrefix)
                        onMoveToPath?(file, parentPath)
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
                        onMoveToPath?(file, folder.key)
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
}

// MARK: - 文件名单元格

/// 文件名单元格（图标 + 名称）
private struct FileNameCell: View {
    let fileObject: FileObject
    var r2Service: R2Service?
    var bucketName: String?

    /// 缩略图URL（带版本参数，用于绕过 CDN 缓存）
    private var thumbnailURL: String? {
        guard fileObject.isImage,
              let r2Service = r2Service,
              let bucketName = bucketName else { return nil }
        return r2Service.generateThumbnailURL(for: fileObject, in: bucketName)
    }

    var body: some View {
        HStack(spacing: 8) {
            // 图标或缩略图
            ZStack {
                if fileObject.isImage, let url = thumbnailURL {
                    AsyncThumbnailView(urlString: url, size: 20) {
                        Image(systemName: "photo")
                            .font(.system(size: 12))
                            .foregroundColor(.purple.opacity(0.5))
                            .frame(width: 20, height: 20)
                    }
                } else {
                    fileIcon
                        .font(.system(size: 14))
                        .frame(width: 20, height: 20)
                }
            }

            Text(fileObject.name)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
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
}

// MARK: - FileObject 排序扩展

extension FileObject {
    /// 可排序的大小值（用于 Table 排序）
    var sortableSize: Int64 {
        size ?? 0
    }
    
    /// 可排序的日期值（用于 Table 排序）
    var sortableDate: Date {
        lastModifiedDate ?? Date.distantPast
    }
    
    /// 可排序的类型值（用于 Table 排序）
    var sortableKind: String {
        if isDirectory {
            return L.Files.FileType.folder
        }
        return fileExtension.lowercased()
    }
    
    /// 类型描述（用于显示）
    var kindDescription: String {
        if isDirectory {
            return L.Files.FileType.folder
        }

        let ext = fileExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "bmp", "tiff":
            return L.Files.FileType.image
        case "mp4", "mov", "avi", "mkv", "webm", "m4v":
            return L.Files.FileType.video
        case "mp3", "wav", "m4a", "aac", "flac", "ogg":
            return L.Files.FileType.audio
        case "pdf":
            return L.Files.FileType.pdf
        case "doc", "docx":
            return L.Files.FileType.wordDocument
        case "xls", "xlsx":
            return L.Files.FileType.excelSpreadsheet
        case "ppt", "pptx":
            return L.Files.FileType.powerPoint
        case "txt":
            return L.Files.FileType.text
        case "zip", "rar", "7z", "tar", "gz":
            return L.Files.FileType.archive
        case "html", "htm":
            return L.Files.FileType.htmlDocument
        case "css":
            return L.Files.FileType.cssStylesheet
        case "js":
            return L.Files.FileType.javaScript
        case "json":
            return L.Files.FileType.jsonFile
        case "xml":
            return L.Files.FileType.xmlFile
        case "swift":
            return L.Files.FileType.swiftSource
        case "md":
            return L.Files.FileType.markdown
        default:
            return ext.isEmpty ? L.Files.FileType.document : L.Files.FileType.extensionFile(ext.uppercased())
        }
    }
}

// MARK: - SelectionManager 扩展

extension SelectionManager {
    /// 设置选择（从文件列表）
    func setSelection(_ files: [FileObject]) {
        // 清除现有选择
        selectedItems.removeAll()
        // 添加新选择（使用文件的 id/key）
        for file in files {
            selectedItems.insert(file.id)
        }
    }
    
    /// 获取选中的 ID 集合
    var selectedIDs: Set<String> {
        selectedItems
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
        sortOrder: .constant(.name),
        sortAscending: .constant(true)
    )
    .frame(width: 600, height: 300)
}
