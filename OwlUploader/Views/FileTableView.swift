//
//  FileTableView.swift
//  OwlUploader
//
//  Finder风格表格视图
//  使用 macOS 原生 Table 组件
//

import SwiftUI
import UniformTypeIdentifiers

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

    /// 移动文件回调：(要移动的文件列表, 目标文件夹)
    var onMoveFiles: (([DraggedFileItem], FileObject) -> Void)?

    /// 移动到指定路径回调：(文件, 目标路径)
    var onMoveToPath: ((FileObject, String) -> Void)?

    /// 当前目录下的文件夹列表（用于移动到子菜单）
    var currentFolders: [FileObject] = []

    /// 当前路径前缀
    var currentPrefix: String = ""

    /// 原生 Table 使用的选择状态
    @State private var tableSelection: Set<String> = []
    
    /// 原生 Table 使用的排序描述符
    @State private var sortComparators: [KeyPathComparator<FileObject>] = [
        KeyPathComparator(\.name, order: .forward)
    ]
    
    /// 当前正在拖拽悬停的文件夹 ID
    @State private var dropTargetFolderID: String? = nil

    var body: some View {
        Table(files, selection: $tableSelection, sortOrder: $sortComparators) {
            // 名称列
            TableColumn(L.Files.TableColumn.name, value: \.name) { file in
                FileNameCell(
                    fileObject: file,
                    r2Service: r2Service,
                    bucketName: bucketName,
                    isDropTarget: false
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
            TableColumn("Kind", value: \.sortableKind) { file in
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
                if !file.isDirectory {
                    Button(action: { onDownloadFile?(file) }) {
                        Label(L.Files.ContextMenu.download, systemImage: "arrow.down.circle")
                    }
                    Button(action: { copyFileURL(file) }) {
                        Label(L.Files.ContextMenu.copyLink, systemImage: "link")
                    }
                    Divider()
                }

                // 移动到子菜单
                moveToMenu(for: file)

                Divider()

                Button(role: .destructive, action: { onDeleteFile?(file) }) {
                    Label(L.Files.ContextMenu.delete, systemImage: "trash")
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
        // 同步排序状态：列头 → 菜单
        .onChange(of: sortComparators) { _, newValue in
            syncSortOrderFromComparators(newValue)
        }
        // 同步排序状态：菜单 → 列头
        .onChange(of: sortOrder) { _, _ in
            syncSortComparatorsFromOrder()
        }
        .onChange(of: sortAscending) { _, _ in
            syncSortComparatorsFromOrder()
        }
        .onAppear {
            // 初始化排序描述符
            syncSortComparatorsFromOrder()
            // 初始化选择状态
            tableSelection = selectionManager.selectedIDs
        }
    }

    // MARK: - 私有方法

    /// 同步原生选择到 SelectionManager
    private func syncSelectionToManager(_ ids: Set<String>) {
        let selectedFiles = files.filter { ids.contains($0.id) }
        selectionManager.setSelection(selectedFiles)
    }

    /// 从 FileSortOrder 和 sortAscending 同步到原生排序描述符（菜单 → 列头）
    private func syncSortComparatorsFromOrder() {
        let order: SortOrder = sortAscending ? .forward : .reverse
        let newComparators: [KeyPathComparator<FileObject>]
        
        switch sortOrder {
        case .name:
            newComparators = [KeyPathComparator(\.name, order: order)]
        case .kind:
            newComparators = [KeyPathComparator(\.sortableKind, order: order)]
        case .dateModified:
            newComparators = [KeyPathComparator(\.sortableDate, order: order)]
        case .size:
            newComparators = [KeyPathComparator(\.sortableSize, order: order)]
        }
        
        // 避免无限循环：只有当排序描述符真正不同时才更新
        if !comparatorsMatch(sortComparators, newComparators) {
            sortComparators = newComparators
        }
    }

    /// 从原生排序描述符同步到 FileSortOrder 和 sortAscending（列头 → 菜单）
    private func syncSortOrderFromComparators(_ comparators: [KeyPathComparator<FileObject>]) {
        guard let first = comparators.first else { return }
        
        // 根据 KeyPath 确定排序类型
        let keyPathString = String(describing: first.keyPath)
        
        let newSortOrder: FileSortOrder
        if keyPathString.contains("name") {
            newSortOrder = .name
        } else if keyPathString.contains("sortableKind") {
            newSortOrder = .kind
        } else if keyPathString.contains("sortableSize") {
            newSortOrder = .size
        } else if keyPathString.contains("sortableDate") {
            newSortOrder = .dateModified
        } else {
            return
        }
        
        // 更新排序方向
        let newAscending = first.order == .forward
        if sortAscending != newAscending {
            sortAscending = newAscending
        }
        
        // 更新排序类型
        if sortOrder != newSortOrder {
            sortOrder = newSortOrder
        }
    }
    
    /// 比较两个排序描述符是否匹配
    private func comparatorsMatch(_ a: [KeyPathComparator<FileObject>], _ b: [KeyPathComparator<FileObject>]) -> Bool {
        guard a.count == b.count else { return false }
        for (c1, c2) in zip(a, b) {
            if String(describing: c1.keyPath) != String(describing: c2.keyPath) || c1.order != c2.order {
                return false
            }
        }
        return true
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
    
    /// 是否为拖放目标（悬停状态）
    var isDropTarget: Bool = false

    /// 缩略图URL
    private var thumbnailURL: String? {
        guard fileObject.isImage,
              let r2Service = r2Service,
              let bucketName = bucketName else { return nil }
        return r2Service.generateFileURL(for: fileObject, in: bucketName)
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
        // 拖放目标高亮效果
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isDropTarget && fileObject.isDirectory ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isDropTarget && fileObject.isDirectory ? Color.accentColor : Color.clear, lineWidth: 2)
        )
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
            return "Folder"
        }
        return fileExtension.lowercased()
    }
    
    /// 类型描述（用于显示）
    var kindDescription: String {
        if isDirectory {
            return "Folder"
        }
        
        let ext = fileExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "bmp", "tiff":
            return "Image"
        case "mp4", "mov", "avi", "mkv", "webm", "m4v":
            return "Video"
        case "mp3", "wav", "m4a", "aac", "flac", "ogg":
            return "Audio"
        case "pdf":
            return "PDF Document"
        case "doc", "docx":
            return "Word Document"
        case "xls", "xlsx":
            return "Excel Spreadsheet"
        case "ppt", "pptx":
            return "PowerPoint"
        case "txt":
            return "Text File"
        case "zip", "rar", "7z", "tar", "gz":
            return "Archive"
        case "html", "htm":
            return "HTML Document"
        case "css":
            return "CSS Stylesheet"
        case "js":
            return "JavaScript"
        case "json":
            return "JSON File"
        case "xml":
            return "XML File"
        case "swift":
            return "Swift Source"
        case "md":
            return "Markdown"
        default:
            return ext.isEmpty ? "Document" : "\(ext.uppercased()) File"
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
