//
//  FileListView.swift
//  OwlUploader
//
//  Created by Sanvi Lu on 2025/5/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// 文件列表视图
/// 用于显示选定存储桶中的文件和文件夹列表
struct FileListView: View {
    /// R2 服务实例
    @ObservedObject var r2Service: R2Service

    /// 选择状态管理器
    @ObservedObject var selectionManager: SelectionManager

    /// 视图模式管理器
    @ObservedObject var viewModeManager: ViewModeManager

    /// 视图是否激活（用于触发刷新）
    var isActive: Bool = true

    /// 消息管理器（通过环境对象传递）
    @EnvironmentObject var messageManager: MessageManager

    /// 当前路径前缀
    @State private var currentPrefix: String = ""
    
    /// 文件对象列表
    @State private var fileObjects: [FileObject] = []
    
    /// 初始加载状态
    @State private var isInitialLoading: Bool = true
    
    /// 是否显示创建文件夹Sheet
    @State private var showingCreateFolderSheet: Bool = false
    
    /// 是否显示文件选择器
    @State private var showingFileImporter: Bool = false
    
    /// 上传状态
    @State private var isUploading: Bool = false
    
    /// 上传进度信息
    @State private var uploadMessage: String = ""
    
    /// 上传队列管理器
    @StateObject private var uploadQueueManager = UploadQueueManager()
    
    /// 是否显示诊断信息
    @State private var showingDiagnostics: Bool = false
    
    /// 要删除的文件对象（用于确认对话框）
    @State private var fileToDelete: FileObject?

    /// 文件夹内文件数量（用于删除确认）
    @State private var folderFileCount: Int = 0

    /// 是否正在统计文件数量
    @State private var isCountingFiles: Bool = false

    /// 是否显示删除确认对话框
    @State private var showingDeleteConfirmation: Bool = false

    /// 搜索文本
    @State private var searchText: String = ""

    /// 筛选类型
    @State private var filterType: FileFilterType = .all

    /// 排序方式
    @State private var sortOrder: FileSortOrder = .name
    
    /// 要预览的文件对象
    @State private var fileToPreview: FileObject?
    
    /// 拖拽目标状态
    @State private var isTargeted: Bool = false

    /// 文件来源枚举
    private enum FileSource {
        case fileImporter  // 文件选择器
        case dragDrop     // 拖拽上传
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Finder风格工具栏
            if r2Service.isConnected, r2Service.selectedBucket != nil {
                FinderToolbar(
                    searchText: $searchText,
                    viewMode: $viewModeManager.currentMode,
                    sortOrder: $sortOrder,
                    filterType: $filterType,
                    canGoUp: !currentPrefix.isEmpty,
                    isDisabled: !canLoadFiles || r2Service.isLoading,
                    selectedCount: selectionManager.selectedCount,
                    onGoUp: goUpOneLevel,
                    onRefresh: loadFileList,
                    onNewFolder: { showingCreateFolderSheet = true },
                    onUpload: { showingFileImporter = true },
                    onBatchDelete: batchDeleteSelectedFiles,
                    onBatchDownload: batchDownloadSelectedFiles,
                    onClearSelection: { selectionManager.clearSelection() }
                )

                Divider()
            }

            // 主内容区域
            mainContentView
                .overlay {
                    if isTargeted {
                        dropZoneOverlay
                    }
                }

            // 上传队列面板
            if uploadQueueManager.isQueuePanelVisible {
                Divider()
                UploadQueueView(queueManager: uploadQueueManager)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 底部路径栏
            if r2Service.isConnected, let bucket = r2Service.selectedBucket {
                Divider()
                PathBar(
                    bucketName: bucket.name,
                    currentPrefix: currentPrefix,
                    onNavigate: navigateToPath
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: uploadQueueManager.isQueuePanelVisible)
        .navigationTitle(r2Service.selectedBucket?.name ?? "Files")
        .onAppear {
            loadFileList()
            // 设置上传完成回调，自动刷新文件列表
            uploadQueueManager.onQueueComplete = {
                loadFileList()
            }
        }
        .onChange(of: r2Service.selectedBucket) { _ in
            currentPrefix = ""
            loadFileList()
        }
        .onChange(of: isActive) { active in
            if active {
                loadFileList()
            }
        }
        .sheet(isPresented: $showingCreateFolderSheet) {
            CreateFolderSheet(
                isPresented: $showingCreateFolderSheet,
                onCreateFolder: createFolderWithName
            )
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: true,
            onCompletion: handleFileImport
        )
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView(r2Service: r2Service)
        }
        .alert(L.Alert.Delete.title, isPresented: $showingDeleteConfirmation) {
            Button(L.Common.Button.cancel, role: .cancel) {
                fileToDelete = nil
                folderFileCount = 0
            }
            Button(L.Common.Button.delete, role: .destructive) {
                if let fileToDelete = fileToDelete {
                    deleteFile(fileToDelete)
                    self.fileToDelete = nil
                    self.folderFileCount = 0
                }
            }
        } message: {
            if let file = fileToDelete {
                if file.isDirectory {
                    if folderFileCount > 0 {
                        Text(L.Alert.Delete.folderMessage(file.name, folderFileCount))
                    } else {
                        Text(L.Alert.Delete.emptyFolderMessage(file.name))
                    }
                } else {
                    Text(L.Alert.Delete.fileMessage(file.name, file.formattedSize))
                }
            }
        }
        // 键盘快捷键支持
        .focusedValue(\.fileActions, FileActions(
            selectAll: {
                let filteredFiles = SearchFilterBar.filterAndSort(files: fileObjects, searchText: searchText, filterType: filterType, sortOrder: sortOrder)
                selectionManager.selectAll(filteredFiles.map { $0.key })
            },
            deselectAll: {
                selectionManager.clearSelection()
            },
            deleteSelected: {
                // 目前只支持单个删除
                if let firstKey = selectionManager.selectedItems.first,
                   let file = fileObjects.first(where: { $0.key == firstKey }) {
                    requestDeleteFile(file)
                }
            },
            refresh: loadFileList,
            goUp: goUpOneLevel,
            newFolder: { showingCreateFolderSheet = true },
            hasSelection: selectionManager.hasSelection,
            canGoUp: !currentPrefix.isEmpty
        ))
        .focusedValue(\.viewModeActions, ViewModeActions(
            setListMode: { viewModeManager.setMode(.list) },
            setTableMode: { viewModeManager.setMode(.table) },
            setIconsMode: { viewModeManager.setMode(.icons) },
            currentMode: viewModeManager.currentMode
        ))
    }
    
    // MARK: - Subviews & Builders

    /// 拖拽区域覆盖层
    private var dropZoneOverlay: some View {
        ZStack {
            Color.blue.opacity(0.1)
            
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.blue, lineWidth: 3)
            
            VStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                Text(L.Files.DropZone.title)
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(8)
        .allowsHitTesting(false)
    }

    /// 主内容视图
    @ViewBuilder
    private var mainContentView: some View {
        if !r2Service.isConnected {
            // 未连接状态
            notConnectedView
        } else if r2Service.selectedBucket == nil {
            // 未选择存储桶状态
            noBucketSelectedView
        } else if r2Service.isLoading && isInitialLoading {
            // 初始加载状态
            loadingView
        } else if let error = r2Service.lastError {
            // 错误状态
            errorView(error)
        } else if fileObjects.isEmpty && !r2Service.isLoading {
            // 空列表状态 - 使用新的拖拽视图
            emptyListView
        } else {
            // 正常文件列表 - 使用新的拖拽视图
            fileListView
        }
    }
    
    /// 未连接提示视图
    private var notConnectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(L.Files.State.notConnectedToR2)
                .font(.headline)

            Text(L.Files.State.configureAccountPrompt)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
    
    /// 未选择存储桶提示视图
    private var noBucketSelectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(L.Files.State.selectBucket)
                .font(.headline)

            Text(L.Files.State.selectBucketPrompt)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
    
    /// 加载中视图
    private var loadingView: some View {
        VStack(spacing: 20) {
            // 自定义进度指示器
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.2)
            }

            VStack(spacing: 4) {
                Text(L.Files.State.loadingFileList)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(L.Common.Label.pleaseWait)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 40)
    }
    
    /// 错误视图
    /// - Parameter error: 要显示的错误
    private func errorView(_ error: R2ServiceError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(L.Files.State.loadFailed)
                .font(.headline)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(L.Common.Button.retry) {
                loadFileList()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 40)
    }
    
    /// 空列表视图
    private var emptyListView: some View {
        ZStack {
            // 拖拽区域背景
            FileDropView(
                isEnabled: canLoadFiles && !isUploading && !r2Service.isLoading,
                isTargeted: $isTargeted,
                onFileDrop: { [self] fileURL, originalFileName in
                    print("🎯 空列表区域拖拽上传: \(originalFileName)")
                    uploadFileImmediately(fileURL: fileURL, originalFileName: originalFileName, source: .dragDrop)
                },
                onMultiFileDrop: { [self] urls in
                    print("🎯 空列表区域多文件拖拽上传: \(urls.count) 个文件")
                    if let bucket = r2Service.selectedBucket {
                        uploadQueueManager.configure(r2Service: r2Service, bucketName: bucket.name)
                        uploadQueueManager.addFiles(urls, to: currentPrefix)
                    } else {
                        print("❌ 无法上传：未选择存储桶")
                        messageManager.showError(L.Message.Error.uploadFailed, description: L.Message.Error.noBucketSelected)
                    }
                },
                onFolderDrop: { [self] urls, baseFolder in
                    print("📁 空列表区域文件夹拖拽上传: \(baseFolder.lastPathComponent)，包含 \(urls.count) 个文件")
                    if let bucket = r2Service.selectedBucket {
                        uploadQueueManager.configure(r2Service: r2Service, bucketName: bucket.name)
                        uploadQueueManager.addFiles(urls, to: currentPrefix, baseFolder: baseFolder)
                    } else {
                        print("❌ 无法上传：未选择存储桶")
                        messageManager.showError(L.Message.Error.uploadFailed, description: L.Message.Error.noBucketSelected)
                    }
                },
                onError: { [self] title, description in
                    messageManager.showError(title, description: description)
                }
            )
            
            // 前景内容
            VStack(spacing: 20) {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: currentPrefix.isEmpty ? "externaldrive" : "folder")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.blue)
                }
                
                // 标题和描述
                VStack(spacing: 8) {
                    Text(L.Files.Empty.title)
                        .font(.title2)
                        .fontWeight(.medium)

                    if currentPrefix.isEmpty {
                        Text(L.Files.Empty.bucketDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(L.Files.Empty.folderDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                // 操作提示
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text(L.Files.Empty.clickUpload)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .foregroundColor(.green)
                        Text(L.Files.Empty.clickNewFolder)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.dotted")
                            .foregroundColor(.purple)
                        Text(L.Files.Empty.orDragDrop)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .allowsHitTesting(false) // 让触摸事件穿透到背景的拖拽视图
        }
    }
    
    /// 文件列表视图
    private var fileListView: some View {
        let filteredFiles = SearchFilterBar.filterAndSort(files: fileObjects, searchText: searchText, filterType: filterType, sortOrder: sortOrder)

        return ZStack {
            // 拖拽区域背景
            FileDropView(
                isEnabled: canLoadFiles && !isUploading && !r2Service.isLoading,
                isTargeted: $isTargeted,
                onFileDrop: { [self] fileURL, originalFileName in
                    print("🎯 文件列表区域拖拽上传: \(originalFileName)")
                    uploadFileImmediately(fileURL: fileURL, originalFileName: originalFileName, source: .dragDrop)
                },
                onMultiFileDrop: { [self] urls in
                    print("🎯 文件列表区域多文件拖拽上传: \(urls.count) 个文件")
                    if let bucket = r2Service.selectedBucket {
                        uploadQueueManager.configure(r2Service: r2Service, bucketName: bucket.name)
                        uploadQueueManager.addFiles(urls, to: currentPrefix)
                    } else {
                        print("❌ 无法上传：未选择存储桶")
                        messageManager.showError(L.Message.Error.uploadFailed, description: L.Message.Error.noBucketSelected)
                    }
                },
                onFolderDrop: { [self] urls, baseFolder in
                    print("📁 文件列表区域文件夹拖拽上传: \(baseFolder.lastPathComponent)，包含 \(urls.count) 个文件")
                    if let bucket = r2Service.selectedBucket {
                        uploadQueueManager.configure(r2Service: r2Service, bucketName: bucket.name)
                        uploadQueueManager.addFiles(urls, to: currentPrefix, baseFolder: baseFolder)
                    } else {
                        print("❌ 无法上传：未选择存储桶")
                        messageManager.showError(L.Message.Error.uploadFailed, description: L.Message.Error.noBucketSelected)
                    }
                },
                onError: { [self] title, description in
                    messageManager.showError(title, description: description)
                }
            )

            // 根据视图模式显示不同的文件列表
            Group {
                switch viewModeManager.currentMode {
                case .list:
                    // 旧列表视图（简化版）
                    listModeView(files: filteredFiles)
                case .table:
                    // 表格视图（带列头）
                    FileTableView(
                        files: filteredFiles,
                        selectionManager: selectionManager,
                        sortOrder: $sortOrder,
                        r2Service: r2Service,
                        bucketName: r2Service.selectedBucket?.name,
                        messageManager: messageManager,
                        onNavigate: { file in
                            handleFileItemDoubleTap(file)
                        },
                        onDeleteFile: { file in
                            requestDeleteFile(file)
                        },
                        onDownloadFile: { file in
                            downloadFile(file)
                        }
                    )
                case .icons:
                    // 图标网格视图
                    FileGridView(
                        files: filteredFiles,
                        selectionManager: selectionManager,
                        iconSize: viewModeManager.iconSizeValue,
                        r2Service: r2Service,
                        bucketName: r2Service.selectedBucket?.name,
                        messageManager: messageManager,
                        onNavigate: { file in
                            handleFileItemDoubleTap(file)
                        },
                        onDeleteFile: { file in
                            requestDeleteFile(file)
                        },
                        onDownloadFile: { file in
                            downloadFile(file)
                        }
                    )
                }
            }
            .overlay(
                // 仅在加载文件列表时显示覆盖层（上传使用队列面板，不阻塞界面）
                Group {
                    if r2Service.isLoading && !isInitialLoading && !uploadQueueManager.isProcessing {
                        Rectangle()
                            .fill(Color.black.opacity(0.1))
                            .overlay(
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text(L.Common.Label.loading)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .shadow(radius: 2)
                                )
                            )
                    }
                }
            )
            .sheet(item: $fileToPreview) { file in
                FilePreviewView(
                    r2Service: r2Service,
                    fileObject: file,
                    bucketName: r2Service.selectedBucket?.name ?? "",
                    onDismiss: { fileToPreview = nil }
                )
            }
        }
    }

    /// 列表模式视图
    private func listModeView(files: [FileObject]) -> some View {
        List {
            ForEach(files, id: \.key) { fileObject in
                FileListItemView(
                    fileObject: fileObject,
                    isSelected: selectionManager.isSelected(fileObject),
                    r2Service: r2Service,
                    bucketName: r2Service.selectedBucket?.name,
                    messageManager: messageManager,
                    onDeleteFile: { fileToDelete in
                        requestDeleteFile(fileToDelete)
                    },
                    onDownloadFile: { file in
                        downloadFile(file)
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    handleFileItemDoubleTap(fileObject)
                }
                .onTapGesture(count: 1) {
                    handleFileItemTap(fileObject, allFiles: files)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    /// 是否可以加载文件
    private var canLoadFiles: Bool {
        r2Service.isConnected && r2Service.selectedBucket != nil
    }
    
    /// 加载文件列表
    private func loadFileList() {
        guard canLoadFiles else { return }
        guard let bucket = r2Service.selectedBucket else { return }
        
        Task {
            do {
                let prefix = currentPrefix.isEmpty ? nil : currentPrefix
                let objects = try await r2Service.listObjects(bucket: bucket.name, prefix: prefix)

                await MainActor.run {
                    // 过滤掉空名称的文件夹（可能是根目录标记）
                    self.fileObjects = objects.filter { !$0.name.isEmpty }
                    self.isInitialLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isInitialLoading = false
                    if let r2Error = error as? R2ServiceError {
                        messageManager.showError(r2Error)
                    }
                }
            }
        }
    }
    
    /// 处理条目点击
    /// - Parameter fileObject: 被点击的文件对象
    private func handleItemTap(_ fileObject: FileObject) {
        // 只有文件夹可以点击进入
        guard fileObject.isDirectory else { return }

        // 更新当前路径并重新加载列表
        currentPrefix = fileObject.key
        selectionManager.clearSelection()
        loadFileList()
    }

    /// 处理文件列表项单击
    /// - Parameters:
    ///   - fileObject: 被点击的文件对象
    ///   - allFiles: 所有文件列表（用于范围选择）
    private func handleFileItemTap(_ fileObject: FileObject, allFiles: [FileObject]) {
        // 获取当前修饰键
        let modifiers = NSEvent.modifierFlags

        // 根据修饰键确定选择模式
        let mode = SelectionManager.modeFromModifiers(modifiers)

        // 执行选择
        selectionManager.select(fileObject, mode: mode, allFiles: allFiles)
    }

    /// 处理文件列表项双击
    /// - Parameter fileObject: 被双击的文件对象
    private func handleFileItemDoubleTap(_ fileObject: FileObject) {
        if fileObject.isDirectory {
            // 文件夹：进入目录
            currentPrefix = fileObject.key
            selectionManager.clearSelection()
            loadFileList()
        } else {
            // 文件：打开预览
            fileToPreview = fileObject
        }
    }

    /// 处理文件下载
    /// - Parameter fileObject: 要下载的文件对象
    private func downloadFile(_ fileObject: FileObject) {
        guard !fileObject.isDirectory else { return }
        guard let bucket = r2Service.selectedBucket else { return }

        // 创建保存面板
        let savePanel = NSSavePanel()
        savePanel.title = "Save File"
        savePanel.nameFieldStringValue = fileObject.name
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let saveURL = savePanel.url else { return }

            Task {
                do {
                    try await r2Service.downloadObject(
                        bucket: bucket.name,
                        key: fileObject.key,
                        to: saveURL
                    )
                    await MainActor.run {
                        messageManager.showSuccess(
                            L.Message.Success.downloadComplete,
                            description: L.Message.Success.downloadDescription(fileObject.name)
                        )
                    }
                } catch {
                    await MainActor.run {
                        messageManager.showError(
                            L.Message.Error.downloadFailed,
                            description: error.localizedDescription
                        )
                    }
                }
            }
        }
    }

    /// 批量删除选中的文件
    private func batchDeleteSelectedFiles() {
        let selectedKeys = selectionManager.getSelectedKeys()
        let selectedFiles = fileObjects.filter { selectedKeys.contains($0.key) && !$0.isDirectory }

        guard !selectedFiles.isEmpty else {
            messageManager.showWarning(L.Message.Warning.noFilesSelected, description: L.Message.Warning.selectFilesToDelete)
            return
        }

        // 创建确认对话框
        let alert = NSAlert()
        alert.messageText = L.Alert.Delete.batchMessage(selectedFiles.count)
        alert.informativeText = L.Alert.Delete.irreversible
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.Common.Button.delete)
        alert.addButton(withTitle: L.Common.Button.cancel)

        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                guard let bucket = r2Service.selectedBucket else { return }

                var successCount = 0
                var failCount = 0

                for file in selectedFiles {
                    do {
                        try await r2Service.deleteObject(bucket: bucket.name, key: file.key)
                        successCount += 1
                    } catch {
                        failCount += 1
                        print("Failed to delete \(file.name): \(error)")
                    }
                }

                await MainActor.run {
                    selectionManager.clearSelection()
                    loadFileList()

                    if failCount == 0 {
                        messageManager.showSuccess(
                            L.Message.Success.deleteComplete,
                            description: L.Message.Success.deleteBatchDescription(successCount)
                        )
                    } else {
                        messageManager.showWarning(
                            L.Message.Warning.partialDelete,
                            description: L.Message.Warning.partialDeleteDescription(successCount, failCount)
                        )
                    }
                }
            }
        }
    }

    /// 批量下载选中的文件
    private func batchDownloadSelectedFiles() {
        let selectedKeys = selectionManager.getSelectedKeys()
        let selectedFiles = fileObjects.filter { selectedKeys.contains($0.key) && !$0.isDirectory }

        guard !selectedFiles.isEmpty else {
            messageManager.showWarning(L.Message.Warning.noFilesSelected, description: L.Message.Warning.selectFilesToDownload)
            return
        }

        // 选择保存目录
        let openPanel = NSOpenPanel()
        openPanel.title = L.Files.selectDownloadFolder
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true

        openPanel.begin { response in
            guard response == .OK, let folderURL = openPanel.url else { return }

            Task {
                guard let bucket = r2Service.selectedBucket else { return }

                var successCount = 0
                var failCount = 0

                for file in selectedFiles {
                    let saveURL = folderURL.appendingPathComponent(file.name)

                    do {
                        try await r2Service.downloadObject(
                            bucket: bucket.name,
                            key: file.key,
                            to: saveURL
                        )
                        successCount += 1
                    } catch {
                        failCount += 1
                        print("Failed to download \(file.name): \(error)")
                    }
                }

                await MainActor.run {
                    if failCount == 0 {
                        messageManager.showSuccess(
                            L.Message.Success.downloadComplete,
                            description: L.Message.Success.downloadBatchDescription(successCount)
                        )
                    } else {
                        messageManager.showWarning(
                            L.Message.Warning.partialDownload,
                            description: L.Message.Warning.partialDeleteDescription(successCount, failCount)
                        )
                    }
                }
            }
        }
    }

    /// 返回上一级目录
    private func goUpOneLevel() {
        // 计算上一级路径
        if currentPrefix.hasSuffix("/") {
            let trimmed = String(currentPrefix.dropLast())
            if let lastSlashIndex = trimmed.lastIndex(of: "/") {
                currentPrefix = String(trimmed[...lastSlashIndex])
            } else {
                currentPrefix = ""
            }
        } else {
            currentPrefix = ""
        }
        
        loadFileList()
    }
    
    /// 导航到指定路径
    /// 用于面包屑导航的路径跳转
    /// - Parameter path: 目标路径
    private func navigateToPath(_ path: String) {
        currentPrefix = path
        loadFileList()
    }
    
    /// 验证文件夹名称是否有效
    /// - Parameter name: 文件夹名称
    /// - Returns: 是否有效
    private func isValidFolderName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查是否为空
        guard !trimmedName.isEmpty else { return false }
        
        // 检查是否包含非法字符
        // S3/R2 中文件夹名不能包含：/ \ : * ? " < > |
        let illegalCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return trimmedName.rangeOfCharacter(from: illegalCharacters) == nil
    }
    
    /// 创建文件夹（带文件夹名称参数）
    /// 供 CreateFolderSheet 调用
    /// - Parameter folderName: 文件夹名称
    private func createFolderWithName(_ folderName: String) {
        guard canLoadFiles else { return }
        guard let bucket = r2Service.selectedBucket else { return }
        
        let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, isValidFolderName(trimmedName) else { return }
        
        // 构造完整的文件夹路径
        let folderPath: String
        if currentPrefix.isEmpty {
            folderPath = trimmedName + "/"
        } else {
            // 确保当前前缀以 `/` 结尾
            let normalizedPrefix = currentPrefix.hasSuffix("/") ? currentPrefix : currentPrefix + "/"
            folderPath = normalizedPrefix + trimmedName + "/"
        }
        
        Task {
            do {
                try await r2Service.createFolder(bucket: bucket.name, folderPath: folderPath)
                
                await MainActor.run {
                    // 创建成功后刷新列表
                    messageManager.showSuccess(L.Message.Success.folderCreated, description: L.Message.Success.folderCreatedDescription(trimmedName))
                    loadFileList()
                }
            } catch {
                await MainActor.run {
                    if let r2Error = error as? R2ServiceError {
                        messageManager.showError(r2Error)
                    }
                }
            }
        }
    }
    
    /// 处理文件导入结果
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if urls.count == 1 {
                guard let fileURL = urls.first else { return }
                let originalFileName = fileURL.lastPathComponent
                uploadFileImmediately(fileURL: fileURL, originalFileName: originalFileName, source: .fileImporter)
            } else {
                if let bucket = r2Service.selectedBucket {
                    uploadQueueManager.configure(r2Service: r2Service, bucketName: bucket.name)
                    uploadQueueManager.addFiles(urls, to: currentPrefix)
                }
            }
        case .failure(let error):
            messageManager.showError(L.Message.Error.importFailed, description: error.localizedDescription)
        }
    }

    /// 立即上传文件（支持文件选择器和拖拽上传）
    /// - Parameters:
    ///   - fileURL: 本地文件 URL
    ///   - originalFileName: 原始文件名
    ///   - source: 文件来源
    private func uploadFileImmediately(fileURL: URL, originalFileName: String, source: FileSource = .dragDrop) {
        print("🎯 uploadFileImmediately 被调用，文件路径: \(fileURL.path)")
        print("📤 上传文件: \(originalFileName)")
        print("📍 文件来源: \(source)")
        
        // 根据来源调用不同的上传方法
        actuallyUpload(fileURL: fileURL, originalFileName: originalFileName, source: source)
    }
    
    /// 实际执行文件上传的方法
    /// - Parameters:
    ///   - fileURL: 本地文件 URL
    ///   - originalFileName: 原始文件名
    ///   - source: 文件来源
    private func actuallyUpload(fileURL: URL, originalFileName: String, source: FileSource) {
        guard canLoadFiles else { 
            print("❌ canLoadFiles = false，无法上传")
            messageManager.showError(L.Message.Error.cannotUpload, description: L.Message.Error.serviceNotReady)
            return 
        }
        guard let bucket = r2Service.selectedBucket else { 
            print("❌ 未选择存储桶，无法上传")
            messageManager.showError(L.Message.Error.cannotUpload, description: L.Message.Error.noBucketSelected)
            return 
        }
        
        // 使用传入的原始文件名
        let fileName = sanitizeFileName(originalFileName)
        print("📄 准备上传文件: \(originalFileName) -> \(fileName)")
        
        // 检查是否是临时文件名被替换的情况
        if originalFileName != fileURL.lastPathComponent {
            print("🔄 使用原始文件名替换文件URL名:")
            print("   文件URL名: \(fileURL.lastPathComponent)")
            print("   原始文件名: \(originalFileName)")
        }
        
        // 获取沙盒安全作用域权限（文件选择器和拖拽都需要）
        let needsSecurityScope = fileURL.startAccessingSecurityScopedResource()
        let sourceDesc = source == .fileImporter ? "文件选择器" : "拖拽上传"
        print("🔐 安全作用域权限 [\(sourceDesc)]: \(needsSecurityScope ? "已获取" : "未获取/不需要")")
        
        // 立即验证文件访问和读取数据
        let fileData: Data
        do {
            // 先检查文件存在性
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("❌ 文件不存在: \(fileURL.path)")
                if needsSecurityScope {
                    fileURL.stopAccessingSecurityScopedResource()
                }
                messageManager.showError(L.Message.Error.uploadFailed, description: L.Message.Error.fileNotExists(originalFileName))
                return
            }
            
            // 立即读取文件数据（这会验证权限是否有效）
            fileData = try Data(contentsOf: fileURL)
            print("✅ 成功读取文件数据: \(fileName), 大小: \(fileData.count) bytes")
            
            // 检查文件大小限制
            let maxSize: Int64 = 5 * 1024 * 1024 * 1024 // 5GB
            if fileData.count > maxSize {
                if needsSecurityScope {
                    fileURL.stopAccessingSecurityScopedResource()
                }
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useGB, .useMB]
                formatter.countStyle = .file
                let fileSizeString = formatter.string(fromByteCount: Int64(fileData.count))
                print("❌ 文件过大: \(fileSizeString)")
                messageManager.showError(L.Message.Error.uploadFailed, description: L.Message.Error.fileTooLarge(originalFileName, fileSizeString))
                return
            }
            
            // 显示文件大小信息
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB, .useKB]
            formatter.countStyle = .file
            let fileSizeString = formatter.string(fromByteCount: Int64(fileData.count))
            print("📊 文件大小检查通过: \(fileName) (\(fileSizeString))")
            
        } catch {
            // 出错时立即释放权限
            if needsSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
            
            print("❌ 无法读取文件数据: \(error)")
            // 特殊处理权限错误
            if let nsError = error as? NSError, nsError.domain == "NSCocoaErrorDomain", nsError.code == 257 {
                messageManager.showError(L.Message.Error.filePermissionDenied, description: L.Message.Error.filePermissionDeniedDetail(originalFileName))
            } else {
                messageManager.showError(L.Message.Error.uploadFailed, description: L.Message.Error.fileReadFailed(originalFileName, error.localizedDescription))
            }
            return
        }
        
        // 构造目标对象键
        let objectKey: String
        if currentPrefix.isEmpty {
            objectKey = fileName
        } else {
            // 确保当前前缀以 `/` 结尾
            let normalizedPrefix = currentPrefix.hasSuffix("/") ? currentPrefix : currentPrefix + "/"
            objectKey = normalizedPrefix + fileName
        }
        
        print("🚀 准备上传到: \(bucket.name)/\(objectKey)")
        
        // 立即更新 UI 状态
        isUploading = true
        uploadMessage = L.Upload.uploadingFile(originalFileName)
        
        // 👇 立即执行上传，使用已读取的数据，避免异步权限问题
        Task {
            do {
                print("🔄 开始上传，使用预读取的数据...")
                
                // 使用 Data 版本的上传方法，避免再次访问文件
                try await r2Service.uploadData(
                    bucket: bucket.name,
                    key: objectKey,
                    data: fileData,
                    contentType: self.getContentType(for: fileName)
                )
                
                await MainActor.run {
                    // 上传成功后立即释放权限
                    if needsSecurityScope {
                        fileURL.stopAccessingSecurityScopedResource()
                        print("🔓 已释放安全作用域权限")
                    }
                    
                    // 上传成功
                    isUploading = false
                    uploadMessage = ""
                    print("✅ 文件上传成功: \(objectKey)")
                    messageManager.showSuccess(L.Message.Success.uploadComplete, description: L.Message.Success.uploadToBucket(originalFileName, bucket.name))
                    
                    // 清理临时复制的文件
                    self.cleanupTempFile(fileURL)
                    
                    // 刷新文件列表以显示新上传的文件
                    loadFileList()
                }
            } catch {
                await MainActor.run {
                    // 上传失败后立即释放权限
                    if needsSecurityScope {
                        fileURL.stopAccessingSecurityScopedResource()
                        print("🔓 已释放安全作用域权限（上传失败）")
                    }
                    
                    // 上传失败
                    isUploading = false
                    uploadMessage = ""
                    print("❌ 文件上传失败: \(error)")
                    
                    // 清理临时复制的文件
                    self.cleanupTempFile(fileURL)
                    
                    if let r2Error = error as? R2ServiceError {
                        // 提供更详细的错误诊断
                        print("🔍 R2ServiceError 详情: \(r2Error.errorDescription ?? "未知错误")")
                        if let suggestion = r2Error.suggestedAction {
                            print("💡 建议操作: \(suggestion)")
                        }
                        messageManager.showError(r2Error)
                    } else {
                        // 处理其他未知错误
                        print("🔍 其他错误类型: \(type(of: error))")
                        messageManager.showError(L.Message.Error.uploadFailed, description: L.Error.File.uploadFailed(originalFileName, error.localizedDescription))
                    }
                }
            }
        }
    }
    
    /// 清理文件名，确保符合 S3/R2 对象键要求
    /// - Parameter fileName: 原始文件名
    /// - Returns: 清理后的文件名
    private func sanitizeFileName(_ fileName: String) -> String {
        // 如果文件名已经是有效的，直接返回
        if isValidObjectKey(fileName) {
            return fileName
        }
        
        print("⚠️ 文件名包含特殊字符，正在清理: \(fileName)")
        
        // 分离文件名和扩展名
        let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
        let fileExtension = (fileName as NSString).pathExtension
        
        // 清理文件名主体
        var sanitized = fileNameWithoutExt
        
        // 替换不安全的字符为下划线
        let unsafeCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|{}[]")
        sanitized = sanitized.components(separatedBy: unsafeCharacters).joined(separator: "_")
        
        // 移除连续的下划线
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        
        // 移除开头和结尾的下划线和空格
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_ "))
        
        // 如果清理后为空，使用默认名称
        if sanitized.isEmpty {
            sanitized = L.Files.defaultFileName
        }
        
        // 重新组合文件名
        let result = fileExtension.isEmpty ? sanitized : "\(sanitized).\(fileExtension)"
        
        print("✅ 文件名清理完成: \(fileName) -> \(result)")
        return result
    }
    
    /// 检查是否为有效的 S3/R2 对象键
    /// - Parameter key: 对象键
    /// - Returns: 是否有效
    private func isValidObjectKey(_ key: String) -> Bool {
        // 基本检查
        guard !key.isEmpty else { return false }
        guard key.count <= 1024 else { return false } // S3 对象键最大长度限制
        
        // 检查是否包含不安全字符
        let unsafeCharacters = CharacterSet(charactersIn: "\\:*?\"<>|{}[]")
        if key.rangeOfCharacter(from: unsafeCharacters) != nil {
            return false
        }
        
        // 不能以 / 开头
        if key.hasPrefix("/") {
            return false
        }
        
        return true
    }
    
    /// 根据文件扩展名获取MIME类型
    /// - Parameter fileName: 文件名
    /// - Returns: MIME类型字符串
    private func getContentType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "html": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "zip": return "application/zip"
        case "mp4": return "video/mp4"
        case "mp3": return "audio/mpeg"
        default: return "application/octet-stream"
        }
    }
    
    /// 清理临时文件
    /// 删除应用documents/uploads目录中的临时复制文件
    /// - Parameter fileURL: 要清理的文件URL
    private func cleanupTempFile(_ fileURL: URL) {
        // 检查是否是应用的uploads目录中的文件
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let uploadsURL = documentsURL.appendingPathComponent("uploads")
        
        // 确保文件在uploads目录中才删除
        if fileURL.path.starts(with: uploadsURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("🧹 已清理临时文件: \(fileURL.lastPathComponent)")
            } catch {
                print("⚠️ 清理临时文件失败: \(error)")
            }
        }
    }
    
    /// 请求删除文件或文件夹（显示确认对话框）
    /// - Parameter fileObject: 要删除的文件或文件夹对象
    private func requestDeleteFile(_ fileObject: FileObject) {
        let type = fileObject.isDirectory ? "文件夹" : "文件"
        print("🗑️ 请求删除\(type): \(fileObject.name)")
        fileToDelete = fileObject
        folderFileCount = 0

        if fileObject.isDirectory {
            // 对于文件夹，先统计文件数量
            countFilesInFolder(fileObject)
        } else {
            showingDeleteConfirmation = true
        }
    }

    /// 统计文件夹内的文件数量
    private func countFilesInFolder(_ folder: FileObject) {
        guard let bucket = r2Service.selectedBucket else {
            showingDeleteConfirmation = true
            return
        }

        isCountingFiles = true

        Task {
            do {
                let prefix = folder.key.hasSuffix("/") ? folder.key : folder.key + "/"
                let objects = try await r2Service.listObjects(bucket: bucket.name, prefix: prefix)
                let count = objects.count

                await MainActor.run {
                    self.folderFileCount = count
                    self.isCountingFiles = false
                    self.showingDeleteConfirmation = true
                }
            } catch {
                await MainActor.run {
                    self.folderFileCount = 0
                    self.isCountingFiles = false
                    self.showingDeleteConfirmation = true
                }
            }
        }
    }
    
    /// 执行文件删除操作
    /// - Parameter fileObject: 要删除的文件对象
    private func deleteFile(_ fileObject: FileObject) {
        guard canLoadFiles else {
            messageManager.showError(L.Message.Error.cannotDelete, description: L.Message.Error.serviceNotReady)
            return
        }

        guard let bucket = r2Service.selectedBucket else {
            messageManager.showError(L.Message.Error.cannotDelete, description: L.Message.Error.noBucketSelected)
            return
        }

        // 根据是否为文件夹选择不同的删除方式
        if fileObject.isDirectory {
            deleteFolder(fileObject, in: bucket.name)
        } else {
            deleteSingleFile(fileObject, in: bucket.name)
        }
    }

    /// 删除单个文件
    private func deleteSingleFile(_ fileObject: FileObject, in bucketName: String) {
        print("🗑️ 开始删除文件: \(fileObject.name)")
        print("   存储桶: \(bucketName)")
        print("   对象键: \(fileObject.key)")

        Task {
            do {
                try await r2Service.deleteObject(bucket: bucketName, key: fileObject.key)

                await MainActor.run {
                    print("✅ 文件删除成功: \(fileObject.name)")
                    messageManager.showSuccess(L.Message.Success.deleteComplete, description: L.Message.Success.deleteFileDescription(fileObject.name))
                    loadFileList()
                }
            } catch {
                await MainActor.run {
                    print("❌ 文件删除失败: \(error)")
                    if let r2Error = error as? R2ServiceError {
                        messageManager.showError(r2Error)
                    } else {
                        messageManager.showError(L.Message.Error.deleteFailed, description: L.Message.Error.cannotDeleteFile(fileObject.name, error.localizedDescription))
                    }
                }
            }
        }
    }

    /// 删除文件夹及其所有内容
    private func deleteFolder(_ fileObject: FileObject, in bucketName: String) {
        print("📁 开始删除文件夹: \(fileObject.name)")
        print("   存储桶: \(bucketName)")
        print("   对象键: \(fileObject.key)")

        Task {
            do {
                let (deletedCount, failedKeys) = try await r2Service.deleteFolder(bucket: bucketName, folderKey: fileObject.key)

                await MainActor.run {
                    if failedKeys.isEmpty {
                        print("✅ 文件夹删除成功: \(fileObject.name)")
                        messageManager.showSuccess(L.Message.Success.deleteComplete, description: L.Message.Success.deleteFolderDescription(fileObject.name, deletedCount))
                    } else {
                        print("⚠️ 文件夹部分删除: \(deletedCount) 成功, \(failedKeys.count) 失败")
                        messageManager.showWarning(L.Message.Warning.partialDelete, description: L.Message.Warning.partialDeleteDescription(deletedCount, failedKeys.count))
                    }
                    loadFileList()
                }
            } catch {
                await MainActor.run {
                    print("❌ 文件夹删除失败: \(error)")
                    if let r2Error = error as? R2ServiceError {
                        messageManager.showError(r2Error)
                    } else {
                        messageManager.showError(L.Message.Error.deleteFailed, description: L.Message.Error.cannotDeleteFolder(fileObject.name, error.localizedDescription))
                    }
                    // 即使失败也刷新列表，因为部分文件可能已被删除
                    loadFileList()
                }
            }
        }
    }
}

// MARK: - 预览

#Preview("未连接状态") {
    FileListView(
        r2Service: R2Service(),
        selectionManager: SelectionManager(),
        viewModeManager: ViewModeManager()
    )
}

#Preview("正常状态") {
    FileListView(
        r2Service: R2Service.preview,
        selectionManager: SelectionManager(),
        viewModeManager: ViewModeManager()
    )
}

#Preview("加载中状态") {
    let service = R2Service.preview
    service.isLoading = true
    return FileListView(
        r2Service: service,
        selectionManager: SelectionManager(),
        viewModeManager: ViewModeManager()
    )
} 