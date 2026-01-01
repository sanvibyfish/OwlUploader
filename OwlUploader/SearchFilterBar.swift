//
//  SearchFilterBar.swift
//  OwlUploader
//
//  搜索和筛选工具栏
//

import SwiftUI

/// 文件筛选类型
enum FileFilterType: String, CaseIterable {
    case all = "全部"
    case folders = "文件夹"
    case images = "图片"
    case videos = "视频"
    case documents = "文档"
    case archives = "压缩包"
    case other = "其他"

    /// 筛选类型对应的图标名称
    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .folders: return "folder"
        case .images: return "photo"
        case .videos: return "video"
        case .documents: return "doc.text"
        case .archives: return "archivebox"
        case .other: return "questionmark.circle"
        }
    }
}

/// 文件排序方式
enum FileSortOrder: String, CaseIterable {
    case name = "名称"
    case size = "大小"
    case date = "日期"
    case type = "类型"

    /// 排序方式对应的图标名称
    var iconName: String {
        switch self {
        case .name: return "textformat"
        case .size: return "internaldrive"
        case .date: return "calendar"
        case .type: return "doc"
        }
    }
}

/// 搜索和筛选工具栏视图
struct SearchFilterBar: View {
    @Binding var searchText: String
    @Binding var filterType: FileFilterType
    @Binding var sortOrder: FileSortOrder

    var body: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索文件...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 200)

            // 筛选类型
            Picker("筛选", selection: $filterType) {
                ForEach(FileFilterType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            // 排序方式
            Picker("排序", selection: $sortOrder) {
                ForEach(FileSortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - 辅助方法

extension SearchFilterBar {
    /// 根据当前筛选条件过滤和排序文件
    static func filterAndSort(
        files: [FileObject],
        searchText: String,
        filterType: FileFilterType,
        sortOrder: FileSortOrder
    ) -> [FileObject] {
        var result = files

        // 搜索过滤
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // 类型过滤
        switch filterType {
        case .all:
            break
        case .folders:
            result = result.filter { $0.isDirectory }
        case .images:
            result = result.filter { $0.isImage }
        case .videos:
            result = result.filter { $0.isVideo }
        case .documents:
            result = result.filter { $0.isDocument }
        case .archives:
            result = result.filter { $0.isArchive }
        case .other:
            result = result.filter { !$0.isDirectory && !$0.isImage && !$0.isVideo && !$0.isDocument && !$0.isArchive }
        }

        // 排序
        switch sortOrder {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            result.sort { ($0.size ?? 0) < ($1.size ?? 0) }
        case .date:
            result.sort { ($0.lastModifiedDate ?? Date.distantPast) < ($1.lastModifiedDate ?? Date.distantPast) }
        case .type:
            result.sort { $0.fileExtension.lowercased() < $1.fileExtension.lowercased() }
        }

        // 文件夹始终在前面
        let folders = result.filter { $0.isDirectory }
        let files = result.filter { !$0.isDirectory }

        return folders + files
    }
}

// MARK: - FileObject 辅助扩展

extension FileObject {
    /// 是否为文档类型
    var isDocument: Bool {
        let docExtensions = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "keynote"]
        return docExtensions.contains(fileExtension.lowercased())
    }

    /// 是否为压缩包
    var isArchive: Bool {
        let archiveExtensions = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz"]
        return archiveExtensions.contains(fileExtension.lowercased())
    }
}
