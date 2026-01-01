//
//  FileDropView.swift
//  OwlUploader
//
//  Created by Sanvi Lu on 2025/5/25.
//

import SwiftUI
import AppKit

/// 文件拖拽视图
/// 基于 NSView 的简单可靠实现，参考 AttachmentDroppableView
struct FileDropView: NSViewRepresentable {
    /// 是否启用拖拽
    let isEnabled: Bool

    /// 文件拖拽处理回调
    let onFileDrop: (URL, String) -> Void

    /// 错误处理回调
    let onError: (String, String) -> Void

    /// 是否有文件正在拖拽到上方
    @Binding var isTargeted: Bool

    init(
        isEnabled: Bool = true,
        isTargeted: Binding<Bool>,
        onFileDrop: @escaping (URL, String) -> Void,
        onError: @escaping (String, String) -> Void
    ) {
        self.isEnabled = isEnabled
        self._isTargeted = isTargeted
        self.onFileDrop = onFileDrop
        self.onError = onError
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> FileDropNSView {
        let view = FileDropNSView()
        view.delegate = context.coordinator
        view.isDropEnabled = isEnabled
        return view
    }
    
    func updateNSView(_ nsView: FileDropNSView, context: Context) {
        nsView.isDropEnabled = isEnabled
        // Update coordinator's parent reference to keep bindings fresh
        context.coordinator.parent = self
    }
    
    /// Coordinator to handle delegation
    class Coordinator: NSObject, FileDropDelegate {
        var parent: FileDropView
        
        init(parent: FileDropView) {
            self.parent = parent
        }
        
        func onFileDrop(url: URL, originalName: String) {
            parent.onFileDrop(url, originalName)
        }
        
        func onError(title: String, description: String) {
            parent.onError(title, description)
        }
        
        func onTargetedChanged(_ targeted: Bool) {
            DispatchQueue.main.async {
                self.parent.isTargeted = targeted
            }
        }
    }
}

/// Protocol for FileDropNSView delegation
protocol FileDropDelegate: AnyObject {
    func onFileDrop(url: URL, originalName: String)
    func onError(title: String, description: String)
    func onTargetedChanged(_ targeted: Bool)
}

/// NSView 实现类
class FileDropNSView: NSView {
    /// Delegate for callbacks
    weak var delegate: FileDropDelegate?
    
    /// 是否启用拖拽
    var isDropEnabled: Bool = true {
        didSet {
            if isDropEnabled {
                registerForDraggedTypes([makeFileNameType()])
            } else {
                unregisterDraggedTypes()
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupDragAndDrop()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragAndDrop()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }
    
    private func setupDragAndDrop() {
        if isDropEnabled {
            registerForDraggedTypes([makeFileNameType()])
        }
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isDropEnabled else { return [] }
        
        do {
            let files = try getFiles(from: sender)
            
            // 检查是否有有效文件
            guard !files.isEmpty else {
                return []
            }
            
            // 检查第一个文件是否存在且可读
            let firstFile = files[0]
            guard FileManager.default.fileExists(atPath: firstFile.path) else {
                return []
            }
            
            print("🎯 FileDropView: 检测到有效拖拽文件: \(firstFile.lastPathComponent)")
            delegate?.onTargetedChanged(true)
            return .copy
            
        } catch {
            print("❌ FileDropView: 拖拽验证失败: \(error)")
            return []
        }
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        delegate?.onTargetedChanged(false)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        delegate?.onTargetedChanged(false)
        guard isDropEnabled else { return false }
        
        do {
            let files = try getFiles(from: sender)
            
            guard let firstFile = files.first else {
                delegate?.onError(title: "拖拽失败", description: "未检测到有效文件")
                return false
            }
            
            print("🚀 FileDropView: 开始处理拖拽文件: \(firstFile.path)")
            
            // 验证文件存在性
            guard FileManager.default.fileExists(atPath: firstFile.path) else {
                delegate?.onError(title: "文件不存在", description: "拖拽的文件无法找到，可能已被移动或删除")
                return false
            }
            
            // 验证文件可读性
            guard FileManager.default.isReadableFile(atPath: firstFile.path) else {
                delegate?.onError(title: "文件权限被拒绝", description: "无法读取拖拽的文件，请检查文件权限")
                return false
            }
            
            // 获取文件属性
            do {
                let resourceValues = try firstFile.resourceValues(forKeys: [
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isDirectoryKey
                ])
                
                // 检查是否为常规文件
                if resourceValues.isDirectory == true {
                    delegate?.onError(title: "不支持的内容", description: "不支持拖拽文件夹，请选择单个文件")
                    return false
                }
                
                guard resourceValues.isRegularFile == true else {
                    delegate?.onError(title: "不支持的内容", description: "只支持拖拽常规文件")
                    return false
                }
                
                // 检查文件大小
                let fileSize = resourceValues.fileSize ?? 0
                if fileSize == 0 {
                    delegate?.onError(title: "文件为空", description: "拖拽的文件大小为0，可能是空文件")
                    return false
                }
                
                // 检查文件大小限制（5GB）
                let maxFileSize = 5 * 1024 * 1024 * 1024
                if fileSize > maxFileSize {
                    let formatter = ByteCountFormatter()
                    formatter.allowedUnits = [.useGB, .useMB]
                    formatter.countStyle = .file
                    let sizeString = formatter.string(fromByteCount: Int64(fileSize))
                    delegate?.onError(title: "文件过大", description: "文件大小为 \(sizeString)，超过 5GB 限制")
                    return false
                }
                
                print("✅ FileDropView: 文件验证通过，大小: \(fileSize) bytes")
                
            } catch {
                print("⚠️ FileDropView: 无法获取文件属性: \(error)")
                // 继续处理，只记录警告
            }
            
            // 获取原始文件名
            let originalFileName = firstFile.lastPathComponent
            
            // 验证文件名有效性
            guard isValidFileName(originalFileName) else {
                delegate?.onError(title: "无效文件", description: "文件名包含无效字符或格式不正确")
                return false
            }
            
            print("🎯 FileDropView: 准备上传文件 '\(originalFileName)'")
            
            // 调用上传回调
            delegate?.onFileDrop(url: firstFile, originalName: originalFileName)
            
            return true
            
        } catch {
            print("❌ FileDropView: 拖拽操作失败: \(error)")
            delegate?.onError(title: "拖拽失败", description: "处理拖拽文件时发生错误: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    /// 从拖拽信息中获取文件列表
    private func getFiles(from sender: NSDraggingInfo) throws -> [URL] {
        let pasteboard = sender.draggingPasteboard
        
        // 获取文件路径字符串数组
        guard let fileNames = pasteboard.propertyList(forType: makeFileNameType()) as? [String] else {
            throw FileDropError.noFiles
        }
        
        guard !fileNames.isEmpty else {
            throw FileDropError.noFiles
        }
        
        // 转换为 URL 数组
        let fileURLs = fileNames.map { URL(fileURLWithPath: $0) }
        
        print("📋 FileDropView: 检测到 \(fileURLs.count) 个拖拽文件")
        for (index, url) in fileURLs.enumerated() {
            print("   \(index + 1). \(url.lastPathComponent)")
        }
        
        return fileURLs
    }
    
    /// 验证文件名是否有效
    private func isValidFileName(_ fileName: String) -> Bool {
        let trimmedName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查文件名不为空
        guard !trimmedName.isEmpty else { return false }
        
        // 检查不是隐藏文件（以.开头）
        guard !trimmedName.hasPrefix(".") else { return false }
        
        // 检查不包含非法字符
        let illegalCharacters = CharacterSet(charactersIn: "/<>:\"\\|?*")
        guard trimmedName.rangeOfCharacter(from: illegalCharacters) == nil else { return false }
        
        // 检查不是系统保留名称
        let reservedNames = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
        let nameWithoutExtension = URL(fileURLWithPath: trimmedName).deletingPathExtension().lastPathComponent.uppercased()
        guard !reservedNames.contains(nameWithoutExtension) else { return false }
        
        return true
    }
}

// MARK: - Helper Functions

/// 创建文件名粘贴板类型
private func makeFileNameType() -> NSPasteboard.PasteboardType {
    // 使用传统的 NSFilenamesPboardType，参考 AttachmentDroppableView
    return NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
}

/// 文件拖拽错误类型
private enum FileDropError: Error, LocalizedError {
    case noFiles
    
    var errorDescription: String? {
        switch self {
        case .noFiles:
            return "未检测到有效文件"
        }
    }
} 
