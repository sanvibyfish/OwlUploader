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

    // Dependencies
    var r2Service: R2Service?
    var bucketName: String?
    var messageManager: MessageManager?

    // Actions
    var onNavigate: ((FileObject) -> Void)?
    var onDeleteFile: ((FileObject) -> Void)?
    var onDownloadFile: ((FileObject) -> Void)?

    /// 原生 Table 使用的选择状态
    @State private var tableSelection: Set<String> = []
    
    /// 原生 Table 使用的排序描述符
    @State private var sortComparators: [KeyPathComparator<FileObject>] = [
        KeyPathComparator(\.name, order: .forward)
    ]

    var body: some View {
        Table(files, selection: $tableSelection, sortOrder: $sortComparators) {
            // 名称列
            TableColumn(L.Files.TableColumn.name, value: \.name) { file in
                FileNameCell(
                    fileObject: file,
                    r2Service: r2Service,
                    bucketName: bucketName
                )
            }
            .width(min: 200)

            // 大小列
            TableColumn(L.Files.TableColumn.size, value: \.sortableSize) { file in
                Text(file.isDirectory ? "--" : file.formattedSize)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundColor(AppColors.textSecondary)
            }
            .width(90)

            // 修改日期列
            TableColumn(L.Files.TableColumn.modified, value: \.sortableDate) { file in
                Text(file.formattedLastModified)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            .width(140)
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
        // 同步排序状态
        .onChange(of: sortComparators) { _, newValue in
            syncSortOrderFromComparators(newValue)
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

    /// 从 FileSortOrder 同步到原生排序描述符
    private func syncSortComparatorsFromOrder() {
        switch sortOrder {
        case .name:
            sortComparators = [KeyPathComparator(\.name, order: .forward)]
        case .nameDescending:
            sortComparators = [KeyPathComparator(\.name, order: .reverse)]
        case .size:
            sortComparators = [KeyPathComparator(\.sortableSize, order: .forward)]
        case .sizeDescending:
            sortComparators = [KeyPathComparator(\.sortableSize, order: .reverse)]
        case .date:
            sortComparators = [KeyPathComparator(\.sortableDate, order: .forward)]
        case .dateDescending:
            sortComparators = [KeyPathComparator(\.sortableDate, order: .reverse)]
        case .type:
            // 按类型排序：使用名称作为备选（原生 Table 不直接支持自定义类型排序）
            sortComparators = [KeyPathComparator(\.name, order: .forward)]
        }
    }

    /// 从原生排序描述符同步到 FileSortOrder
    private func syncSortOrderFromComparators(_ comparators: [KeyPathComparator<FileObject>]) {
        guard let first = comparators.first else { return }
        
        // 根据 KeyPath 和排序方向确定 FileSortOrder
        // 使用字符串比较来判断 keyPath 类型
        let keyPathString = String(describing: first.keyPath)
        
        if keyPathString.contains("name") {
            sortOrder = first.order == .forward ? .name : .nameDescending
        } else if keyPathString.contains("sortableSize") {
            sortOrder = first.order == .forward ? .size : .sizeDescending
        } else if keyPathString.contains("sortableDate") {
            sortOrder = first.order == .forward ? .date : .dateDescending
        }
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
}

// MARK: - 文件名单元格

/// 文件名单元格（图标 + 名称）
private struct FileNameCell: View {
    let fileObject: FileObject
    var r2Service: R2Service?
    var bucketName: String?

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
        sortOrder: .constant(.name)
    )
    .frame(width: 600, height: 300)
}
