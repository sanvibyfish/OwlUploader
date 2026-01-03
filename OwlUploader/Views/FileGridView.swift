//
//  FileGridView.swift
//  OwlUploader
//
//  Finder风格图标网格视图
//  以网格形式展示文件和文件夹
//

import SwiftUI

/// 图标网格视图
struct FileGridView: View {
    /// 文件列表
    let files: [FileObject]

    /// 选择管理器
    @ObservedObject var selectionManager: SelectionManager

    /// 图标尺寸
    var iconSize: CGFloat = 64

    // Dependencies
    var r2Service: R2Service?
    var bucketName: String?
    var messageManager: MessageManager?

    // Actions
    var onNavigate: ((FileObject) -> Void)?
    var onDeleteFile: ((FileObject) -> Void)?
    var onDownloadFile: ((FileObject) -> Void)?

    /// 移动到指定路径回调：(文件, 目标路径)
    var onMoveToPath: ((FileObject, String) -> Void)?

    /// 当前目录下的文件夹列表（用于移动到子菜单）
    var currentFolders: [FileObject] = []

    /// 当前路径前缀
    var currentPrefix: String = ""

    /// 网格列配置
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: iconSize + 40, maximum: iconSize + 60), spacing: 8)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(files) { file in
                    FileGridItemView(
                        fileObject: file,
                        isSelected: selectionManager.isSelected(file),
                        iconSize: iconSize,
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
                        },
                        onMoveToPath: onMoveToPath,
                        currentFolders: currentFolders,
                        currentPrefix: currentPrefix
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppColors.contentBackground)
        .onTapGesture {
            // 点击空白区域清除选择
            selectionManager.clearSelection()
        }
    }

    // MARK: - 私有方法

    private func handleTap(_ file: FileObject) {
        // 获取当前修饰键
        let modifiers = NSEvent.modifierFlags
        let mode = SelectionManager.modeFromModifiers(modifiers)

        selectionManager.select(file, mode: mode, allFiles: files)
    }

    private func handleDoubleTap(_ file: FileObject) {
        // 双击：文件夹进入，文件预览
        onNavigate?(file)
    }
}

// MARK: - 预览

#Preview {
    FileGridView(
        files: [
            FileObject(name: "Documents", key: "Documents/", size: nil, lastModifiedDate: nil, isDirectory: true),
            FileObject(name: "photo1.jpg", key: "photo1.jpg", size: 1024 * 512, lastModifiedDate: Date(), isDirectory: false, eTag: "a"),
            FileObject(name: "photo2.png", key: "photo2.png", size: 1024 * 1024, lastModifiedDate: Date(), isDirectory: false, eTag: "b"),
            FileObject(name: "document.pdf", key: "document.pdf", size: 2048 * 1024, lastModifiedDate: Date(), isDirectory: false, eTag: "c"),
            FileObject(name: "archive.zip", key: "archive.zip", size: 4096 * 1024, lastModifiedDate: Date(), isDirectory: false, eTag: "d"),
        ],
        selectionManager: SelectionManager()
    )
    .frame(width: 500, height: 400)
}
