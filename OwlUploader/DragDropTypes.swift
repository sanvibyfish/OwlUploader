//
//  DragDropTypes.swift
//  OwlUploader
//
//  拖拽移动文件的数据类型定义
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 自定义 UTType

extension UTType {
    /// 自定义文件项类型，用于应用内拖拽
    static let owlFileItem = UTType(exportedAs: "com.owluploader.fileitem")
}

// MARK: - 拖拽项数据模型

/// 拖拽的文件项
struct DraggedFileItem: Codable, Transferable, Hashable {
    /// 对象键（完整路径）
    let key: String
    
    /// 文件/文件夹名称
    let name: String
    
    /// 是否为文件夹
    let isDirectory: Bool
    
    /// 从 FileObject 创建
    init(from fileObject: FileObject) {
        self.key = fileObject.key
        self.name = fileObject.name
        self.isDirectory = fileObject.isDirectory
    }
    
    init(key: String, name: String, isDirectory: Bool) {
        self.key = key
        self.name = name
        self.isDirectory = isDirectory
    }
    
    // MARK: - Transferable
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .owlFileItem)
    }
}

// MARK: - 冲突解决

/// 文件冲突解决选项
enum ConflictResolution: String, CaseIterable {
    /// 替换现有文件
    case replace
    
    /// 跳过此文件
    case skip
    
    /// 自动重命名（添加序号）
    case rename
    
    /// 取消整个操作
    case cancel
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .replace:
            return "替换"
        case .skip:
            return "跳过"
        case .rename:
            return "保留两者"
        case .cancel:
            return "取消"
        }
    }
    
    /// 图标
    var iconName: String {
        switch self {
        case .replace:
            return "arrow.triangle.swap"
        case .skip:
            return "arrow.right.to.line"
        case .rename:
            return "doc.badge.plus"
        case .cancel:
            return "xmark.circle"
        }
    }
}

/// 文件冲突信息
struct FileConflict: Identifiable {
    let id = UUID()
    
    /// 源文件键
    let sourceKey: String
    
    /// 目标文件键（冲突的位置）
    let destinationKey: String
    
    /// 文件名
    let fileName: String
    
    /// 是否为文件夹
    let isDirectory: Bool
}

// MARK: - 移动操作结果

/// 移动操作的结果
struct MoveOperationResult {
    /// 成功移动的文件数量
    let successCount: Int
    
    /// 跳过的文件数量
    let skippedCount: Int
    
    /// 失败的文件列表
    let failedKeys: [String]
    
    /// 是否全部成功
    var isFullSuccess: Bool {
        failedKeys.isEmpty && skippedCount == 0
    }
    
    /// 摘要信息
    var summary: String {
        var parts: [String] = []
        
        if successCount > 0 {
            parts.append("成功移动 \(successCount) 个")
        }
        if skippedCount > 0 {
            parts.append("跳过 \(skippedCount) 个")
        }
        if !failedKeys.isEmpty {
            parts.append("失败 \(failedKeys.count) 个")
        }
        
        return parts.joined(separator: "，")
    }
}

// MARK: - 拖放目标类型

/// 拖放目标类型
enum DropTargetType {
    /// 文件夹（文件列表中的文件夹项）
    case folder(FileObject)
    
    /// 面包屑路径段
    case breadcrumbPath(String)
    
    /// 根目录（存储桶根）
    case root
    
    /// 获取目标路径前缀
    var destinationPrefix: String {
        switch self {
        case .folder(let fileObject):
            return fileObject.key
        case .breadcrumbPath(let path):
            return path
        case .root:
            return ""
        }
    }
}
