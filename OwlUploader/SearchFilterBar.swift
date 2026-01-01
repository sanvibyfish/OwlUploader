//
//  SearchFilterBar.swift
//  OwlUploader
//
//  搜索和筛选栏组件
//  支持按文件名搜索和按类型筛选
//

import SwiftUI

/// 筛选类型
enum FileFilterType: String, CaseIterable {
    case all = "全部"
    case folder = "文件夹"
    case image = "图片"
    case video = "视频"
    case audio = "音频"
    case document = "文档"
    case archive = "压缩包"
    case other = "其他"
    
    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .folder: return "folder"
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "music.note"
        case .document: return "doc.text"
        case .archive: return "archivebox"
        case .other: return "doc"
        }
    }
    
    /// 检查文件是否匹配此类型
    func matches(_ fileObject: FileObject) -> Bool {
        switch self {
        case .all:
            return true
        case .folder:
            return fileObject.isDirectory
        case .image:
            let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "ico", "svg", "heic"]
            return matchesExtensions(fileObject, extensions: imageExts)
        case .video:
            let videoExts = ["mp4", "mov", "avi", "mkv", "webm", "m4v", "wmv"]
            return matchesExtensions(fileObject, extensions: videoExts)
        case .audio:
            let audioExts = ["mp3", "wav", "flac", "aac", "ogg", "m4a", "wma"]
            return matchesExtensions(fileObject, extensions: audioExts)
        case .document:
            let docExts = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "rtf"]
            return matchesExtensions(fileObject, extensions: docExts)
        case .archive:
            let archiveExts = ["zip", "rar", "7z", "tar", "gz", "bz2"]
            return matchesExtensions(fileObject, extensions: archiveExts)
        case .other:
            return !fileObject.isDirectory && 
                   !FileFilterType.image.matches(fileObject) &&
                   !FileFilterType.video.matches(fileObject) &&
                   !FileFilterType.audio.matches(fileObject) &&
                   !FileFilterType.document.matches(fileObject) &&
                   !FileFilterType.archive.matches(fileObject)
        }
    }
    
    private func matchesExtensions(_ fileObject: FileObject, extensions: [String]) -> Bool {
        let ext = fileObject.name.components(separatedBy: ".").last?.lowercased() ?? ""
        return extensions.contains(ext)
    }
}

/// 排序方式
enum FileSortOrder: String, CaseIterable {
    case name = "名称"
    case nameDesc = "名称 (降序)"
    case size = "大小"
    case sizeDesc = "大小 (降序)"
    case date = "日期"
    case dateDesc = "日期 (降序)"
    
    var iconName: String {
        switch self {
        case .name: return "textformat.abc"
        case .nameDesc: return "textformat.abc"
        case .size: return "arrow.up.arrow.down"
        case .sizeDesc: return "arrow.up.arrow.down"
        case .date: return "calendar"
        case .dateDesc: return "calendar"
        }
    }
}

/// 搜索筛选栏视图
struct SearchFilterBar: View {
    
    /// 搜索文本
    @Binding var searchText: String
    
    /// 当前筛选类型
    @Binding var filterType: FileFilterType
    
    /// 当前排序方式
    @Binding var sortOrder: FileSortOrder
    
    /// 是否显示筛选选项
    @State private var showFilterOptions: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索文件名...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .frame(maxWidth: 300)
            
            // 类型筛选下拉
            Menu {
                ForEach(FileFilterType.allCases, id: \.self) { type in
                    Button(action: { filterType = type }) {
                        Label(type.rawValue, systemImage: type.iconName)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: filterType.iconName)
                    Text(filterType.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(filterType == .all ? Color.clear : Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            
            // 排序方式下拉
            Menu {
                ForEach(FileSortOrder.allCases, id: \.self) { order in
                    Button(action: { sortOrder = order }) {
                        Label(order.rawValue, systemImage: order.iconName)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(sortOrder.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// 文件筛选和排序辅助方法
extension Array where Element == FileObject {
    
    /// 应用搜索和筛选
    func filtered(by searchText: String, filterType: FileFilterType) -> [FileObject] {
        var result = self
        
        // 应用类型筛选
        if filterType != .all {
            result = result.filter { filterType.matches($0) }
        }
        
        // 应用搜索
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(lowercasedSearch) }
        }
        
        return result
    }
    
    /// 应用排序
    func sorted(by order: FileSortOrder) -> [FileObject] {
        // 文件夹始终排在前面
        let folders = self.filter { $0.isDirectory }
        let files = self.filter { !$0.isDirectory }

        // 按名称升序排序
        func sortByNameAsc(_ items: [FileObject]) -> [FileObject] {
            items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        // 按名称降序排序
        func sortByNameDesc(_ items: [FileObject]) -> [FileObject] {
            items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }

        // 按大小升序排序
        func sortBySizeAsc(_ items: [FileObject]) -> [FileObject] {
            items.sorted { ($0.size ?? 0) < ($1.size ?? 0) }
        }

        // 按大小降序排序
        func sortBySizeDesc(_ items: [FileObject]) -> [FileObject] {
            items.sorted { ($0.size ?? 0) > ($1.size ?? 0) }
        }

        // 按日期升序排序
        func sortByDateAsc(_ items: [FileObject]) -> [FileObject] {
            items.sorted { (a: FileObject, b: FileObject) -> Bool in
                let dateA = a.lastModifiedDate ?? Date.distantPast
                let dateB = b.lastModifiedDate ?? Date.distantPast
                return dateA < dateB
            }
        }

        // 按日期降序排序
        func sortByDateDesc(_ items: [FileObject]) -> [FileObject] {
            items.sorted { (a: FileObject, b: FileObject) -> Bool in
                let dateA = a.lastModifiedDate ?? Date.distantPast
                let dateB = b.lastModifiedDate ?? Date.distantPast
                return dateA > dateB
            }
        }

        let sortedFolders: [FileObject]
        let sortedFiles: [FileObject]

        switch order {
        case .name:
            sortedFolders = sortByNameAsc(folders)
            sortedFiles = sortByNameAsc(files)
        case .nameDesc:
            sortedFolders = sortByNameDesc(folders)
            sortedFiles = sortByNameDesc(files)
        case .size:
            sortedFolders = sortByNameAsc(folders)
            sortedFiles = sortBySizeAsc(files)
        case .sizeDesc:
            sortedFolders = sortByNameAsc(folders)
            sortedFiles = sortBySizeDesc(files)
        case .date:
            sortedFolders = sortByDateAsc(folders)
            sortedFiles = sortByDateAsc(files)
        case .dateDesc:
            sortedFolders = sortByDateDesc(folders)
            sortedFiles = sortByDateDesc(files)
        }

        return sortedFolders + sortedFiles
    }
}

// MARK: - 预览

#Preview("搜索筛选栏") {
    SearchFilterBar(
        searchText: .constant("test"),
        filterType: .constant(.all),
        sortOrder: .constant(.name)
    )
    .frame(width: 600)
    .padding()
}
