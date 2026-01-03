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

    /// 单文件拖拽处理回调（向后兼容）
    let onFileDrop: (URL, String) -> Void

    /// 多文件拖拽处理回调
    var onMultiFileDrop: (([URL]) -> Void)?

    /// 文件夹拖拽处理回调（files, baseFolder）
    var onFolderDrop: (([URL], URL) -> Void)?

    /// 错误处理回调
    let onError: (String, String) -> Void

    /// 是否有文件正在拖拽到上方
    @Binding var isTargeted: Bool

    init(
        isEnabled: Bool = true,
        isTargeted: Binding<Bool>,
        onFileDrop: @escaping (URL, String) -> Void,
        onMultiFileDrop: (([URL]) -> Void)? = nil,
        onFolderDrop: (([URL], URL) -> Void)? = nil,
        onError: @escaping (String, String) -> Void
    ) {
        self.isEnabled = isEnabled
        self._isTargeted = isTargeted
        self.onFileDrop = onFileDrop
        self.onMultiFileDrop = onMultiFileDrop
        self.onFolderDrop = onFolderDrop
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

        func onMultiFileDrop(urls: [URL]) {
            if let handler = parent.onMultiFileDrop {
                handler(urls)
            } else {
                // 向后兼容：逐个处理
                for url in urls {
                    parent.onFileDrop(url, url.lastPathComponent)
                }
            }
        }

        func onFolderDrop(urls: [URL], baseFolder: URL) {
            if let handler = parent.onFolderDrop {
                handler(urls, baseFolder)
            } else {
                // 向后兼容：当作普通多文件处理
                onMultiFileDrop(urls: urls)
            }
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
    func onMultiFileDrop(urls: [URL])
    func onFolderDrop(urls: [URL], baseFolder: URL)
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

            guard !files.isEmpty else {
                delegate?.onError(title: L.Message.Error.dragFailed, description: L.Error.File.noFiles)
                return false
            }

            print("🚀 FileDropView: 开始处理 \(files.count) 个拖拽文件")

            // 分离文件夹和普通文件
            var regularFiles: [URL] = []
            var folderDrops: [(files: [URL], baseFolder: URL)] = []

            for file in files {
                // 验证文件存在性
                guard FileManager.default.fileExists(atPath: file.path) else {
                    print("⚠️ 跳过不存在的文件: \(file.lastPathComponent)")
                    continue
                }

                // 验证文件可读性
                guard FileManager.default.isReadableFile(atPath: file.path) else {
                    print("⚠️ 跳过无权限的文件: \(file.lastPathComponent)")
                    continue
                }

                // 获取文件属性
                do {
                    let resourceValues = try file.resourceValues(forKeys: [
                        .fileSizeKey,
                        .isRegularFileKey,
                        .isDirectoryKey
                    ])

                    // 处理文件夹（递归获取所有文件，保持目录结构）
                    if resourceValues.isDirectory == true {
                        print("📁 处理文件夹: \(file.lastPathComponent)")
                        let folderFiles = collectFilesFromFolder(file)
                        if !folderFiles.isEmpty {
                            folderDrops.append((files: folderFiles, baseFolder: file))
                        }
                        continue
                    }

                    guard resourceValues.isRegularFile == true else {
                        print("⚠️ 跳过非常规文件: \(file.lastPathComponent)")
                        continue
                    }

                    // 检查文件大小
                    let fileSize = resourceValues.fileSize ?? 0
                    if fileSize == 0 {
                        print("⚠️ 跳过空文件: \(file.lastPathComponent)")
                        continue
                    }

                    // 检查文件大小限制（5GB）
                    let maxFileSize = 5 * 1024 * 1024 * 1024
                    if fileSize > maxFileSize {
                        print("⚠️ 跳过超大文件: \(file.lastPathComponent)")
                        continue
                    }

                    // 验证文件名有效性
                    guard isValidFileName(file.lastPathComponent) else {
                        print("⚠️ 跳过无效文件名: \(file.lastPathComponent)")
                        continue
                    }

                    regularFiles.append(file)
                    print("✅ 有效文件: \(file.lastPathComponent)")

                } catch {
                    print("⚠️ 无法获取文件属性: \(file.lastPathComponent) - \(error)")
                    // 仍然尝试添加
                    regularFiles.append(file)
                }
            }

            // 检查是否有有效内容
            guard !regularFiles.isEmpty || !folderDrops.isEmpty else {
                delegate?.onError(title: L.Message.Error.noValidFiles, description: L.Message.Error.allFilesInvalid)
                return false
            }

            // 处理文件夹上传（保持目录结构）
            for folderDrop in folderDrops {
                print("📂 FileDropView: 文件夹上传 \(folderDrop.baseFolder.lastPathComponent)，包含 \(folderDrop.files.count) 个文件")
                delegate?.onFolderDrop(urls: folderDrop.files, baseFolder: folderDrop.baseFolder)
            }

            // 处理普通文件上传
            if !regularFiles.isEmpty {
                print("🎯 FileDropView: 准备上传 \(regularFiles.count) 个普通文件")
                delegate?.onMultiFileDrop(urls: regularFiles)
            }

            return true

        } catch {
            print("❌ FileDropView: 拖拽操作失败: \(error)")
            delegate?.onError(title: L.Message.Error.dragFailed, description: L.Message.Error.dragProcessFailed(error.localizedDescription))
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

    /// 递归收集文件夹中的所有文件
    private func collectFilesFromFolder(_ folderURL: URL) -> [URL] {
        var files: [URL] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return files
        }

        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])

                // 只收集文件，跳过子目录
                guard resourceValues.isRegularFile == true else { continue }

                // 检查文件大小
                let fileSize = resourceValues.fileSize ?? 0
                guard fileSize > 0, fileSize <= 5 * 1024 * 1024 * 1024 else { continue }

                // 验证文件名
                guard isValidFileName(fileURL.lastPathComponent) else { continue }

                files.append(fileURL)
                print("   📄 收集文件: \(fileURL.lastPathComponent)")

            } catch {
                print("⚠️ 无法获取文件属性: \(fileURL.lastPathComponent)")
            }
        }

        print("📁 从文件夹 \(folderURL.lastPathComponent) 收集了 \(files.count) 个文件")
        return files
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
            return L.Error.File.noFiles
        }
    }
} 
