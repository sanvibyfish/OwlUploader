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
    
    /// 浏览历史管理器
    @StateObject private var navigationHistory = NavigationHistoryManager()
    
    /// 文件对象列表
    @State private var fileObjects: [FileObject] = []
    
    /// 初始加载状态
    @State private var isInitialLoading: Bool = true
    
    /// 是否显示创建文件夹Sheet
    @State private var showingCreateFolderSheet: Bool = false
    
    /// 是否显示文件选择器
    @State private var showingFileImporter: Bool = false
    

    /// 上传队列管理器
    @StateObject private var uploadQueueManager = UploadQueueManager()

    /// 下载队列管理器
    @StateObject private var downloadQueueManager = DownloadQueueManager()

    /// 移动队列管理器
    @StateObject private var moveQueueManager = MoveQueueManager()

    /// 是否显示诊断信息
    @State private var showingDiagnostics: Bool = false
    
    /// 要删除的文件对象（用于确认对话框）
    @State private var fileToDelete: FileObject?

    /// 要删除的多个文件对象（用于批量删除确认对话框）
    @State private var filesToDelete: [FileObject] = []

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
    
    /// 排序方向（true = 升序，false = 降序）
    @State private var sortAscending: Bool = true
    
    /// 要预览的文件对象
    @State private var fileToPreview: FileObject?

    /// 要重命名的文件对象
    @State private var fileToRename: FileObject?
    
    /// 缓存的过滤+排序结果，仅在输入变化时重新计算
    @State private var filteredFiles: [FileObject] = []

    /// 拖拽目标状态
    @State private var isTargeted: Bool = false

    /// 上次成功加载的路径（用于空状态显示，防止导航时闪烁）
    @State private var lastLoadedPrefix: String = ""

    // MARK: - 上传冲突状态

    /// 当前检测到的上传冲突（使用 item 方式显示 sheet，确保数据传递正确）
    @State private var uploadConflictData: UploadConflictData?

    /// 冲突处理回调（用户选择后调用）
    @State private var conflictResolutionHandler: (([UUID: ConflictAction]) -> Void)?

    /// 文件来源枚举
    private enum FileSource {
        case fileImporter  // 文件选择器
        case dragDrop     // 拖拽上传
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏和内容区分隔线
            if r2Service.isConnected, r2Service.selectedBucket != nil {
                Divider()
            }
            
            // 主内容区域
            mainContentView
                .overlay {
                    if isTargeted {
                        dropZoneOverlay
                    }
                }

            // 组合队列面板（上传 + 下载 + 移动）
            if uploadQueueManager.isQueuePanelVisible || downloadQueueManager.isQueuePanelVisible || moveQueueManager.isQueuePanelVisible {
                Divider()
                CombinedQueueView(uploadManager: uploadQueueManager, downloadManager: downloadQueueManager, moveManager: moveQueueManager)
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
        .animation(.easeInOut(duration: 0.2), value: uploadQueueManager.isQueuePanelVisible || downloadQueueManager.isQueuePanelVisible || moveQueueManager.isQueuePanelVisible)
        .navigationTitle(r2Service.selectedBucket?.name ?? "Files")
        .navigationSubtitle(currentPrefix.isEmpty ? "" : currentPrefix)
        .toolbar { fileListToolbarContent }
        .onAppear {
            loadFileList()
            // 设置上传完成回调，自动刷新文件列表
            uploadQueueManager.onQueueComplete = {
                loadFileList()
            }
            // 设置移动完成回调，自动刷新文件列表
            moveQueueManager.onQueueComplete = {
                loadFileList()
            }
            // 设置上传冲突检测回调
            uploadQueueManager.onConflictsDetected = { conflicts, handler in
                conflictResolutionHandler = handler
                uploadConflictData = UploadConflictData(conflicts: conflicts)
            }
        }
        .onChange(of: r2Service.selectedBucket) { _ in
            currentPrefix = ""
            navigationHistory.reset(to: "")  // 切换存储桶时重置历史
            loadFileList()
        }
        .onChange(of: isActive) { active in
            if active {
                loadFileList()
            }
        }
        .onChange(of: fileObjects) { _ in updateFilteredFiles() }
        .onChange(of: searchText) { _ in updateFilteredFiles() }
        .onChange(of: filterType) { _ in updateFilteredFiles() }
        .onChange(of: sortOrder) { _ in updateFilteredFiles() }
        .onChange(of: sortAscending) { _ in updateFilteredFiles() }
        .sheet(isPresented: $showingCreateFolderSheet) {
            CreateFolderSheet(
                isPresented: $showingCreateFolderSheet,
                onCreateFolder: createFolderWithName
            )
        }
        .sheet(item: $fileToRename) { file in
            RenameSheet(
                isPresented: Binding(
                    get: { fileToRename != nil },
                    set: { if !$0 { fileToRename = nil } }
                ),
                file: file,
                onRename: handleRename
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
        // 上传冲突处理弹窗（使用 item 方式确保数据正确传递）
        .sheet(item: $uploadConflictData) { data in
            UploadConflictSheet(
                conflicts: data.conflicts,
                onResolution: { resolutions in
                    uploadConflictData = nil
                    conflictResolutionHandler?(resolutions)
                    conflictResolutionHandler = nil
                }
            )
        }
        // 删除确认对话框（支持单文件和多文件）
        .alert(L.Alert.Delete.title, isPresented: $showingDeleteConfirmation) {
            Button(L.Common.Button.cancel, role: .cancel) {
                fileToDelete = nil
                filesToDelete = []
                folderFileCount = 0
            }
            Button(L.Common.Button.delete, role: .destructive) {
                if !filesToDelete.isEmpty {
                    // 批量删除
                    deleteFiles(filesToDelete)
                    filesToDelete = []
                    folderFileCount = 0
                } else if let fileToDelete = fileToDelete {
                    // 单文件删除
                    deleteFile(fileToDelete)
                    self.fileToDelete = nil
                    self.folderFileCount = 0
                }
            }
        } message: {
            if !filesToDelete.isEmpty {
                // 批量删除消息
                let fileCount = filesToDelete.filter { !$0.isDirectory }.count
                let folderCount = filesToDelete.filter { $0.isDirectory }.count
                if fileCount > 0 && folderCount > 0 {
                    Text(L.Alert.Delete.multipleItemsMessage(fileCount, folderCount))
                } else if folderCount > 0 {
                    Text(L.Alert.Delete.multipleFoldersMessage(folderCount))
                } else {
                    Text(L.Alert.Delete.multipleFilesMessage(fileCount))
                }
            } else if let file = fileToDelete {
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
                selectionManager.selectAll(filteredFiles.map { $0.key })
            },
            deselectAll: {
                selectionManager.clearSelection()
            },
            deleteSelected: {
                // 获取所有选中的文件
                let selectedKeys = selectionManager.getSelectedKeys()
                let selectedFiles = fileObjects.filter { selectedKeys.contains($0.key) }

                if selectedFiles.count > 1 {
                    // 多文件删除
                    requestDeleteFiles(selectedFiles)
                } else if let file = selectedFiles.first {
                    // 单文件删除
                    requestDeleteFile(file)
                }
            },
            refresh: { loadFileList() },
            goUp: navigateBack,
            newFolder: { showingCreateFolderSheet = true },
            hasSelection: selectionManager.hasSelection,
            canGoUp: navigationHistory.canGoBack
        ))
        .focusedValue(\.viewModeActions, ViewModeActions(
            setTableMode: { viewModeManager.setMode(.table) },
            setIconsMode: { viewModeManager.setMode(.icons) },
            currentMode: viewModeManager.currentMode
        ))
    }
    
    // MARK: - Toolbar Content
    
    /// 工具栏内容
    @ToolbarContentBuilder
    private var fileListToolbarContent: some ToolbarContent {
        // 左侧导航区
        ToolbarItemGroup(placement: .navigation) {
            navigationToolbarButtons
        }
        
        // 中间：视图模式切换
        ToolbarItem(placement: .principal) {
            if r2Service.isConnected, r2Service.selectedBucket != nil {
                viewModePicker
            }
        }
        
        // 右侧操作区
        ToolbarItemGroup(placement: .automatic) {
            if r2Service.isConnected, r2Service.selectedBucket != nil {
                rightToolbarContent
            }
        }
    }
    
    /// 导航工具栏按钮
    @ViewBuilder
    private var navigationToolbarButtons: some View {
        if r2Service.isConnected, r2Service.selectedBucket != nil {
            Button(action: navigateBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!navigationHistory.canGoBack || !canLoadFiles || r2Service.isLoading)
            .help(L.Help.back)
            
            Button(action: navigateForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!navigationHistory.canGoForward || !canLoadFiles || r2Service.isLoading)
            .help(L.Help.forward)
            
            Button {
                loadFileList()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(!canLoadFiles || r2Service.isLoading)
            .help(L.Help.refresh)
            
            if r2Service.isLoading && !isInitialLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }
        }
    }
    
    /// 右侧工具栏内容
    @ViewBuilder
    private var rightToolbarContent: some View {
        if selectionManager.selectedCount > 0 {
            batchOperationButtons
        } else {
            normalOperationButtons
        }
    }
    
    /// 批量操作按钮
    @ViewBuilder
    private var batchOperationButtons: some View {
        Text("\(selectionManager.selectedCount) \(L.Files.itemsSelected(selectionManager.selectedCount))")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        
        Button(action: { selectionManager.clearSelection() }) {
            Image(systemName: "xmark.circle")
        }
        .help(L.Help.clearSelection)
        
        Button(action: batchDownloadSelectedFiles) {
            Label(L.Files.Toolbar.download, systemImage: "arrow.down.circle")
        }
        .disabled(!canLoadFiles || r2Service.isLoading)
        
        Button(action: batchDeleteSelectedFiles) {
            Label(L.Files.Toolbar.deleteAction, systemImage: "trash")
        }
        .disabled(!canLoadFiles || r2Service.isLoading)
    }
    
    /// 正常操作按钮
    @ViewBuilder
    private var normalOperationButtons: some View {
        // 更多菜单
        moreOptionsMenu
        
        // 新建文件夹
        Button(action: { showingCreateFolderSheet = true }) {
            Image(systemName: "folder.badge.plus")
        }
        .disabled(!canLoadFiles || r2Service.isLoading)
        .help(L.Help.newFolder)
        
        // 上传文件
        Button(action: { showingFileImporter = true }) {
            Image(systemName: "arrow.up.doc")
        }
        .disabled(!canLoadFiles || r2Service.isLoading)
        .help(L.Help.uploadFile)
        
        // 搜索框
        toolbarSearchField
    }
    
    /// 更多选项菜单
    private var moreOptionsMenu: some View {
        Menu {
            Section(L.Files.Menu.filterSection) {
                ForEach(FileFilterType.allCases, id: \.self) { type in
                    Button {
                        filterType = type
                    } label: {
                        HStack {
                            Label(type.displayName, systemImage: type.iconName)
                            if filterType == type {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Section(L.Files.Menu.sortSection) {
                ForEach(FileSortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        HStack {
                            Label(order.displayName, systemImage: order.iconName)
                            if sortOrder == order {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .help(L.Help.moreOptions)
    }
    
    // MARK: - Subviews & Builders
    
    /// 视图模式选择器
    private var viewModePicker: some View {
        Picker("", selection: Binding(
            get: { viewModeManager.currentMode },
            set: { newMode in
                withAnimation(AppAnimations.fast) {
                    viewModeManager.setMode(newMode)
                }
            }
        )) {
            ForEach(FileViewMode.allCases) { mode in
                Image(systemName: mode.iconName)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 80)
    }
    
    /// 工具栏搜索框
    private var toolbarSearchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 100)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

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
        } else if isInitialLoading {
            // 初始加载状态 - 最高优先级，确保切换时立即显示
            loadingView
        } else if let error = r2Service.lastError {
            // 错误状态
            errorView(error)
        } else if fileObjects.isEmpty {
            // 空列表状态 - 使用新的拖拽视图
            emptyListView
        } else {
            // 正常文件列表 - 使用新的拖拽视图
            fileListView
        }
    }
    
    /// 未连接提示视图
    private var notConnectedView: some View {
        EmptyStateView(
            icon: "network.slash",
            title: L.Files.State.notConnectedToR2,
            description: L.Files.State.configureAccountPrompt
        )
    }
    
    /// 未选择存储桶提示视图
    private var noBucketSelectedView: some View {
        EmptyStateView(
            icon: "externaldrive",
            title: L.Files.State.selectBucket,
            description: L.Files.State.selectBucketPrompt
        )
    }
    
    /// 加载中视图 - 类似空文件夹样式
    private var loadingView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 28) {
                // 图标层 - 使用文件夹图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.08), Color.blue.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: currentPrefix.isEmpty ? "externaldrive" : "folder")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.blue)
                        .symbolRenderingMode(.hierarchical)
                }
                
                // 文字区 - 只保留文字，不显示进度条
                Text(L.Files.State.loadingFileList)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.contentBackground)
    }
    
    /// 错误视图
    /// - Parameter error: 要显示的错误
    private func errorView(_ error: R2ServiceError) -> some View {
        VStack {
            Spacer()
            
            VStack(spacing: 28) {
                // 错误图标 - 使用渐变
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.1), Color.red.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)
                }
                
                // 错误文字
                VStack(spacing: 12) {
                    Text(L.Files.State.loadFailed)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(error.localizedDescription)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                // 重试按钮
                Button {
                    loadFileList()
                } label: {
                    Label(L.Common.Button.retry, systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.contentBackground)
    }
    
    /// 空列表视图
    private var emptyListView: some View {
        ZStack {
            // 拖拽区域背景
            FileDropView(
                isEnabled: canLoadFiles && !r2Service.isLoading,
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
            
            // 前景内容 - 使用 EmptyStateView
            // 注意：使用 lastLoadedPrefix 而不是 currentPrefix，防止导航时显示错误的空状态
            EmptyStateView(
                icon: lastLoadedPrefix.isEmpty ? "externaldrive" : "folder",
                title: L.Files.Empty.title,
                description: lastLoadedPrefix.isEmpty ? L.Files.Empty.bucketDescription : L.Files.Empty.folderDescription,
                hints: [
                    (icon: "plus.circle.fill", color: .blue, text: L.Files.Empty.clickUpload),
                    (icon: "folder.badge.plus", color: .green, text: L.Files.Empty.clickNewFolder),
                    (icon: "arrow.down.circle.dotted", color: .purple, text: L.Files.Empty.orDragDrop)
                ]
            )
            .allowsHitTesting(false) // 让触摸事件穿透到背景的拖拽视图
        }
    }
    
    /// 文件列表视图
    private var fileListView: some View {
        ZStack {
            // 拖拽区域背景
            FileDropView(
                isEnabled: canLoadFiles && !r2Service.isLoading,
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

            // 双视图保持：两个视图都在内存中，用 zIndex 控制显示层级
            // 保持两个视图都完全渲染（opacity > 0），避免 Table 懒加载问题
            ZStack {
                // 表格视图
                FileTableView(
                    files: filteredFiles,
                    selectionManager: selectionManager,
                    sortOrder: $sortOrder,
                    sortAscending: $sortAscending,
                    r2Service: r2Service,
                    bucketName: r2Service.selectedBucket?.name,
                    messageManager: messageManager,
                    onNavigate: { file in
                        handleFileItemDoubleTap(file)
                    },
                    onDeleteFile: { file in
                        handleDeleteFile(file)
                    },
                    onDownloadFile: { file in
                        handleDownloadFile(file)
                    },
                    onPreview: { file in
                        fileToPreview = file
                    },
                    onCreateFolder: {
                        showingCreateFolderSheet = true
                    },
                    onUpload: {
                        showingFileImporter = true
                    },
                    onMoveToPath: { file, destinationPath in
                        handleMoveToPath(file: file, destinationPath: destinationPath)
                    },
                    onRename: { file in
                        print("📝 [Rename] Triggered for file: \(file.name)")
                        fileToRename = file
                    },
                    onPurgeCDNCache: { file in
                        handlePurgeCDNCache(file: file)
                    },
                    currentFolders: filteredFiles.filter { $0.isDirectory },
                    currentPrefix: currentPrefix
                )
                .zIndex(viewModeManager.currentMode == .table ? 1 : 0)
                .allowsHitTesting(viewModeManager.currentMode == .table)

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
                        handleDeleteFile(file)
                    },
                    onDownloadFile: { file in
                        handleDownloadFile(file)
                    },
                    onPreview: { file in
                        fileToPreview = file
                    },
                    onCreateFolder: {
                        showingCreateFolderSheet = true
                    },
                    onUpload: {
                        showingFileImporter = true
                    },
                    onMoveToPath: { file, destinationPath in
                        handleMoveToPath(file: file, destinationPath: destinationPath)
                    },
                    onRename: { file in
                        print("📝 [Rename] Triggered for file: \(file.name)")
                        fileToRename = file
                    },
                    onPurgeCDNCache: { file in
                        handlePurgeCDNCache(file: file)
                    },
                    currentFolders: filteredFiles.filter { $0.isDirectory },
                    currentPrefix: currentPrefix
                )
                .zIndex(viewModeManager.currentMode == .icons ? 1 : 0)
                .allowsHitTesting(viewModeManager.currentMode == .icons)
            }
            // 移除阻塞式 loading 覆盖层，改为在工具栏显示加载状态
            // 用户可以在加载过程中继续交互
            .sheet(item: $fileToPreview) { file in
                FilePreviewView(
                    r2Service: r2Service,
                    fileObject: file,
                    allFiles: filteredFiles.filter { !$0.isDirectory },  // 只传入非目录文件用于导航
                    bucketName: r2Service.selectedBucket?.name ?? "",
                    messageManager: messageManager,
                    onNavigate: { newFile in
                        // 导航时更新预览文件
                        fileToPreview = newFile
                    },
                    onDownload: { file in
                        downloadFile(file)
                    },
                    onDelete: { file in
                        deleteFile(file)
                        fileToPreview = nil  // 删除后关闭预览
                    },
                    onDismiss: { fileToPreview = nil }
                )
            }
            // 空格键触发预览（类似 Finder Quick Look）
            .onKeyPress(.space) {
                togglePreview()
                return .handled
            }
        }
    }

    /// 重新计算过滤+排序结果（仅在输入变化时调用）
    private func updateFilteredFiles() {
        filteredFiles = SearchFilterBar.filterAndSort(
            files: fileObjects,
            searchText: searchText,
            filterType: filterType,
            sortOrder: sortOrder,
            ascending: sortAscending
        )
    }

    /// 切换预览状态（空格键）
    private func togglePreview() {
        if fileToPreview != nil {
            // 已有预览，关闭
            fileToPreview = nil
        } else {
            // 没有预览，打开选中的第一个非目录文件
            if let firstSelectedKey = selectionManager.selectedItems.first,
               let file = fileObjects.first(where: { $0.key == firstSelectedKey && !$0.isDirectory }) {
                fileToPreview = file
            }
        }
    }

    
    /// 是否可以加载文件
    private var canLoadFiles: Bool {
        r2Service.isConnected && r2Service.selectedBucket != nil
    }
    
    /// 加载文件列表
    /// - Parameter showLoadingState: 是否显示全屏加载状态（导航操作时应传入 false）
    private func loadFileList(showLoadingState: Bool = true) {
        guard canLoadFiles else { return }
        
        guard let bucket = r2Service.selectedBucket else { return }
        
        // 只在首次加载且允许显示加载状态时才显示全屏加载界面
        // 导航操作（前进/后退/进入文件夹）时不显示，保持流畅体验
        if showLoadingState && fileObjects.isEmpty {
            isInitialLoading = true
        }
        
        selectionManager.clearSelection()
        r2Service.lastError = nil  // 清除旧的错误状态
        
        Task {
            do {
                let prefix = currentPrefix.isEmpty ? nil : currentPrefix
                let objects = try await r2Service.listObjects(bucket: bucket.name, prefix: prefix)

                await MainActor.run {
                    // 过滤掉空名称的文件夹（可能是根目录标记）
                    self.fileObjects = objects.filter { !$0.name.isEmpty }
                    self.lastLoadedPrefix = self.currentPrefix  // 记录已加载的路径
                    self.isInitialLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isInitialLoading = false
                    // 出错时才清空列表，显示错误状态
                    self.fileObjects = []
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

        // 使用历史管理器记录导航
        navigationHistory.navigateTo(fileObject.key)
        currentPrefix = fileObject.key
        selectionManager.clearSelection()
        loadFileList(showLoadingState: false)  // 导航时不显示全屏加载
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
            // 文件夹：进入目录，记录历史
            navigationHistory.navigateTo(fileObject.key)
            currentPrefix = fileObject.key
            selectionManager.clearSelection()
            loadFileList(showLoadingState: false)  // 导航时不显示全屏加载
        } else {
            // 文件：打开预览
            fileToPreview = fileObject
        }
    }

    /// 处理右键菜单下载文件
    /// 如果文件是多选的一部分，则下载所有选中的文件
    private func handleDownloadFile(_ file: FileObject) {
        let selectedKeys = selectionManager.getSelectedKeys()

        // 如果点击的文件是选中项的一部分，且选中了多个文件，则批量下载
        if selectedKeys.contains(file.key) && selectedKeys.count > 1 {
            batchDownloadSelectedFiles()
        } else {
            // 单文件下载
            downloadFile(file)
        }
    }

    /// 处理文件下载
    /// - Parameter fileObject: 要下载的文件或文件夹对象
    private func downloadFile(_ fileObject: FileObject) {
        guard let bucket = r2Service.selectedBucket else { return }

        if fileObject.isDirectory {
            // 文件夹下载：选择目标文件夹
            downloadFolder(fileObject, bucket: bucket)
        } else {
            // 单文件下载：选择保存位置和文件名
            downloadSingleFile(fileObject, bucket: bucket)
        }
    }

    /// 下载单个文件
    private func downloadSingleFile(_ fileObject: FileObject, bucket: BucketItem) {
        // 创建保存面板
        let savePanel = NSSavePanel()
        savePanel.title = L.SavePanel.saveFile
        savePanel.nameFieldStringValue = fileObject.name
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let saveURL = savePanel.url else { return }

            Task { @MainActor in
                // 获取保存目录
                let destinationFolder = saveURL.deletingLastPathComponent()

                // 配置下载队列管理器
                downloadQueueManager.configure(r2Service: r2Service, bucketName: bucket.name)

                // 设置完成回调
                downloadQueueManager.onQueueComplete = {
                    let completed = self.downloadQueueManager.completedTasks.count
                    let failed = self.downloadQueueManager.failedTasks.count

                    if failed == 0 && completed > 0 {
                        self.messageManager.showSuccess(
                            L.Message.Success.downloadComplete,
                            description: L.Message.Success.downloadDescription(fileObject.name)
                        )
                    } else if failed > 0 {
                        self.messageManager.showError(
                            L.Message.Error.downloadFailed,
                            description: self.downloadQueueManager.failedTasks.first?.status.failureMessage ?? ""
                        )
                    }
                }

                // 使用用户指定的文件名（可能与原文件名不同）
                let downloadFile: (key: String, name: String, size: Int64) = (
                    key: fileObject.key,
                    name: saveURL.lastPathComponent,
                    size: fileObject.size ?? 0
                )

                // 添加到下载队列
                downloadQueueManager.addDownloads([downloadFile], to: destinationFolder)
            }
        }
    }

    /// 下载文件夹
    private func downloadFolder(_ folderObject: FileObject, bucket: BucketItem) {
        // 使用 NSOpenPanel 选择目标文件夹
        let openPanel = NSOpenPanel()
        openPanel.title = "选择保存位置"
        openPanel.prompt = "选择文件夹"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false

        openPanel.begin { response in
            guard response == .OK, let destinationFolder = openPanel.url else { return }

            Task { @MainActor in
                do {
                    // 显示加载提示
                    self.messageManager.showInfo(
                        "正在扫描文件夹",
                        description: "正在列出 \(folderObject.name) 中的所有文件..."
                    )

                    // 递归列出文件夹内所有文件
                    let files = try await self.r2Service.listAllFilesInFolder(
                        bucket: bucket.name,
                        folderPrefix: folderObject.key
                    )

                    guard !files.isEmpty else {
                        self.messageManager.showWarning(
                            "文件夹为空",
                            description: "\(folderObject.name) 中没有文件"
                        )
                        return
                    }

                    // 创建文件夹目录结构
                    let folderName = folderObject.name.hasSuffix("/")
                        ? String(folderObject.name.dropLast())
                        : folderObject.name
                    let localFolderURL = destinationFolder.appendingPathComponent(folderName)

                    // 配置下载队列管理器
                    self.downloadQueueManager.configure(r2Service: self.r2Service, bucketName: bucket.name)

                    // 设置完成回调
                    self.downloadQueueManager.onQueueComplete = {
                        let completed = self.downloadQueueManager.completedTasks.count
                        let failed = self.downloadQueueManager.failedTasks.count

                        if failed == 0 && completed > 0 {
                            self.messageManager.showSuccess(
                                L.Message.Success.downloadComplete,
                                description: "成功下载 \(completed) 个文件"
                            )
                        } else if failed > 0 {
                            self.messageManager.showWarning(
                                "部分下载失败",
                                description: "成功: \(completed), 失败: \(failed)"
                            )
                        }
                    }

                    // 为每个文件创建下载任务，保持相对路径
                    let downloadFiles: [(key: String, name: String, size: Int64)] = files.map { file in
                        // 使用相对路径作为本地文件名（保持目录结构）
                        return (key: file.key, name: file.relativePath, size: file.size)
                    }

                    // 添加到下载队列
                    self.downloadQueueManager.addDownloads(downloadFiles, to: localFolderURL)

                    self.messageManager.showSuccess(
                        "开始下载",
                        description: "正在下载 \(files.count) 个文件到 \(folderName)"
                    )

                } catch {
                    self.messageManager.showError(
                        "文件夹下载失败",
                        description: error.localizedDescription
                    )
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
        let selectedItems = fileObjects.filter { selectedKeys.contains($0.key) }

        guard !selectedItems.isEmpty else {
            messageManager.showWarning(L.Message.Warning.noFilesSelected, description: L.Message.Warning.selectFilesToDownload)
            return
        }

        // 分离普通文件和文件夹
        let selectedFiles = selectedItems.filter { !$0.isDirectory }
        let selectedFolders = selectedItems.filter { $0.isDirectory }

        // 选择保存目录
        let openPanel = NSOpenPanel()
        openPanel.title = L.Files.selectDownloadFolder
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true

        openPanel.begin { response in
            guard response == .OK, let folderURL = openPanel.url else { return }

            Task { @MainActor in
                guard let bucket = r2Service.selectedBucket else { return }

                // 构建下载任务列表：先加入普通文件
                var allDownloadFiles: [(key: String, name: String, size: Int64)] = selectedFiles.map { file in
                    (key: file.key, name: file.name, size: file.size ?? 0)
                }

                // 对选中的文件夹递归获取子文件
                if !selectedFolders.isEmpty {
                    self.messageManager.showInfo(
                        L.Message.Info.scanningFolders,
                        description: L.Message.Info.scanningFoldersDescription(selectedFolders.count)
                    )

                    for folder in selectedFolders {
                        do {
                            let files = try await self.r2Service.listAllFilesInFolder(
                                bucket: bucket.name,
                                folderPrefix: folder.key
                            )

                            // 文件夹名去除末尾 /
                            let folderName = folder.name.hasSuffix("/")
                                ? String(folder.name.dropLast())
                                : folder.name

                            // 使用 folderName/relativePath 保持目录结构
                            let folderFiles: [(key: String, name: String, size: Int64)] = files.map { file in
                                (key: file.key, name: "\(folderName)/\(file.relativePath)", size: file.size)
                            }
                            allDownloadFiles.append(contentsOf: folderFiles)
                        } catch {
                            self.messageManager.showError(
                                L.Message.BatchDownload.scanFolderFailed,
                                description: L.Message.BatchDownload.scanFolderFailedDescription(folder.name, error.localizedDescription)
                            )
                        }
                    }
                }

                guard !allDownloadFiles.isEmpty else {
                    self.messageManager.showWarning(
                        L.Message.Warning.noFilesSelected,
                        description: L.Message.BatchDownload.selectedFoldersEmpty
                    )
                    return
                }

                // 配置下载队列管理器
                downloadQueueManager.configure(r2Service: r2Service, bucketName: bucket.name)

                // 设置完成回调
                downloadQueueManager.onQueueComplete = {
                    let completed = self.downloadQueueManager.completedTasks.count
                    let failed = self.downloadQueueManager.failedTasks.count

                    if failed == 0 && completed > 0 {
                        self.messageManager.showSuccess(
                            L.Message.Success.downloadComplete,
                            description: L.Message.Success.downloadBatchDescription(completed)
                        )
                    } else if failed > 0 {
                        self.messageManager.showWarning(
                            L.Message.Warning.partialDownload,
                            description: L.Message.Warning.partialDownloadDescription(completed, failed)
                        )
                    }
                }

                // 添加到下载队列
                downloadQueueManager.addDownloads(allDownloadFiles, to: folderURL)
            }
        }
    }

    /// 返回上一级目录
    /// 后退到上一个浏览位置
    private func navigateBack() {
        guard let previousPath = navigationHistory.goBack() else { return }
        
        currentPrefix = previousPath
        selectionManager.clearSelection()
        loadFileList(showLoadingState: false)  // 导航时不显示全屏加载
    }
    
    /// 前进到下一个浏览位置
    private func navigateForward() {
        guard let nextPath = navigationHistory.goForward() else { return }
        
        currentPrefix = nextPath
        selectionManager.clearSelection()
        loadFileList(showLoadingState: false)  // 导航时不显示全屏加载
    }
    
    /// 导航到指定路径
    /// 用于面包屑导航的路径跳转
    /// - Parameter path: 目标路径
    private func navigateToPath(_ path: String) {
        navigationHistory.navigateTo(path)
        currentPrefix = path
        loadFileList(showLoadingState: false)  // 导航时不显示全屏加载
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
        
        guard canLoadFiles else {
            messageManager.showError(L.Message.Error.cannotUpload, description: L.Message.Error.serviceNotReady)
            return
        }
        guard let bucket = r2Service.selectedBucket else {
            messageManager.showError(L.Message.Error.cannotUpload, description: L.Message.Error.noBucketSelected)
            return
        }
        
        // 配置并添加到队列
        uploadQueueManager.configure(r2Service: r2Service, bucketName: bucket.name)
        // 使用数组包装单个文件
        uploadQueueManager.addFiles([fileURL], to: currentPrefix)
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

    /// 请求删除多个文件或文件夹（显示确认对话框）
    /// - Parameter files: 要删除的文件对象列表
    private func requestDeleteFiles(_ files: [FileObject]) {
        print("🗑️ 请求批量删除 \(files.count) 个项目")
        filesToDelete = files
        folderFileCount = 0
        showingDeleteConfirmation = true
    }

    /// 处理右键菜单删除文件
    /// 如果文件是多选的一部分，则删除所有选中的文件
    private func handleDeleteFile(_ file: FileObject) {
        let selectedKeys = selectionManager.getSelectedKeys()

        if selectedKeys.contains(file.key) && selectedKeys.count > 1 {
            let selectedFiles = fileObjects.filter { selectedKeys.contains($0.key) }
            requestDeleteFiles(selectedFiles)
        } else {
            requestDeleteFile(file)
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

    /// 执行批量文件删除操作
    /// - Parameter files: 要删除的文件对象列表
    private func deleteFiles(_ files: [FileObject]) {
        guard canLoadFiles else {
            messageManager.showError(L.Message.Error.cannotDelete, description: L.Message.Error.serviceNotReady)
            return
        }

        guard let bucket = r2Service.selectedBucket else {
            messageManager.showError(L.Message.Error.cannotDelete, description: L.Message.Error.noBucketSelected)
            return
        }

        let bucketName = bucket.name
        print("🗑️ 开始批量删除 \(files.count) 个项目")

        // 分离文件和文件夹
        let regularFiles = files.filter { !$0.isDirectory }
        let folders = files.filter { $0.isDirectory }

        Task {
            var successCount = 0
            var failedCount = 0

            // 1. 使用批量 API 删除所有普通文件
            if !regularFiles.isEmpty {
                let fileKeys = regularFiles.map { $0.key }
                do {
                    let failedKeys = try await r2Service.deleteObjects(bucket: bucketName, keys: fileKeys)
                    successCount += fileKeys.count - failedKeys.count
                    failedCount += failedKeys.count
                } catch {
                    print("❌ 批量删除文件失败: \(error.localizedDescription)")
                    failedCount += fileKeys.count
                }
            }

            // 2. 逐个删除文件夹（每个文件夹内部使用批量删除）
            for folder in folders {
                do {
                    let (deletedCount, _) = try await r2Service.deleteFolder(bucket: bucketName, folderKey: folder.key)
                    if deletedCount > 0 {
                        successCount += 1
                    }
                } catch {
                    print("❌ 删除文件夹失败: \(folder.name) - \(error.localizedDescription)")
                    failedCount += 1
                }
            }

            await MainActor.run {
                if failedCount == 0 {
                    print("✅ 批量删除完成: 成功 \(successCount) 个")
                    messageManager.showSuccess(L.Message.Success.deleteComplete, description: L.Message.Success.deleteBatchDescription(successCount))
                } else {
                    print("⚠️ 批量删除完成: 成功 \(successCount) 个，失败 \(failedCount) 个")
                    messageManager.showWarning(L.Message.Warning.partialDelete, description: L.Message.Warning.partialDeleteDescription(successCount, failedCount))
                }
                // 清除选择并刷新列表
                selectionManager.clearSelection()
                loadFileList()
            }
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

    // MARK: - 重命名文件

    /// 处理重命名文件
    /// - Parameters:
    ///   - file: 要重命名的文件
    ///   - newName: 新名称
    private func handleRename(file: FileObject, newName: String) {
        guard let bucketName = r2Service.selectedBucket?.name else { return }

        let oldName = file.isDirectory ? String(file.name.dropLast()) : file.name

        Task {
            do {
                // 构建新的 key（保留目录路径）
                // 对于文件夹，先移除尾部斜杠再处理
                let keyForProcessing = file.isDirectory && file.key.hasSuffix("/")
                    ? String(file.key.dropLast())
                    : file.key
                let directory = keyForProcessing.components(separatedBy: "/").dropLast().joined(separator: "/")
                let newKey = directory.isEmpty ? newName : "\(directory)/\(newName)"

                // 文件夹需要保留尾部斜杠
                let finalNewKey = file.isDirectory ? "\(newKey)/" : newKey

                try await r2Service.renameObject(
                    bucket: bucketName,
                    oldKey: file.key,
                    newKey: finalNewKey
                )

                await MainActor.run {
                    messageManager.showSuccess(
                        L.Message.Success.renameComplete,
                        description: L.Message.Success.renameDescription(oldName, newName)
                    )
                    loadFileList()
                }
            } catch {
                await MainActor.run {
                    messageManager.showError(
                        L.Message.Error.renameFailed,
                        description: error.localizedDescription
                    )
                }
            }
        }
    }

    // MARK: - 移动文件

    /// 处理刷新 CDN 缓存
    /// 如果文件是多选的一部分，则刷新所有选中文件的缓存
    private func handlePurgeCDNCache(file: FileObject) {
        guard let bucket = r2Service.selectedBucket else {
            messageManager.showError(L.Message.Error.noBucketSelected)
            return
        }

        let selectedKeys = selectionManager.getSelectedKeys()
        let filesToPurge: [FileObject]

        if selectedKeys.contains(file.key) && selectedKeys.count > 1 {
            filesToPurge = fileObjects.filter { selectedKeys.contains($0.key) && !$0.isDirectory }
        } else {
            filesToPurge = file.isDirectory ? [] : [file]
        }

        guard !filesToPurge.isEmpty else {
            messageManager.showInfo(L.Message.Info.noFilesToPurge)
            return
        }

        // 收集所有需要清除缓存的 URL
        let urls = filesToPurge.compactMap { r2Service.generateBaseURL(for: $0.key, in: bucket.name) }

        guard !urls.isEmpty else {
            messageManager.showError(L.Message.Error.noPublicDomain)
            return
        }

        // 调用 CDN 缓存清除 API（手动触发使用 force 模式，绕过自动清除开关）
        Task {
            let success = await r2Service.purgeCDNCache(for: urls, force: true)
            await MainActor.run {
                if success {
                    // 同步清理本地缩略图缓存，使视图重新加载
                    ThumbnailCache.shared.clearCache()
                    messageManager.showSuccess(
                        L.Message.Success.cdnCachePurged,
                        description: L.Message.Success.cdnCachePurgedDescription(filesToPurge.count)
                    )
                } else {
                    messageManager.showError(
                        L.Message.Error.cdnPurgeFailed,
                        description: L.Message.Error.cdnPurgeFailedDescription
                    )
                }
            }
        }
    }

    /// 处理右键菜单移动文件到指定路径
    /// 如果文件是多选的一部分，则移动所有选中的文件
    private func handleMoveToPath(file: FileObject, destinationPath: String) {
        let selectedKeys = selectionManager.getSelectedKeys()

        if selectedKeys.contains(file.key) && selectedKeys.count > 1 {
            let selectedFiles = fileObjects.filter { selectedKeys.contains($0.key) }
            handleMoveFilesToPath(items: selectedFiles, toPath: destinationPath)
        } else {
            handleMoveFilesToPath(items: [file], toPath: destinationPath)
        }
    }

    /// 处理移动到指定路径
    /// - Parameters:
    ///   - items: 要移动的文件项列表
    ///   - destinationPath: 目标路径前缀
    private func handleMoveFilesToPath(items: [FileObject], toPath destinationPath: String) {
        guard let bucket = r2Service.selectedBucket else {
            messageManager.showError(L.Move.Message.moveFailed, description: L.Message.Error.noBucketSelected)
            return
        }

        // 过滤掉无效的移动（移动到当前位置）
        let validItems = items.filter { item in
            let itemParentPath = getParentPath(of: item.key)
            return itemParentPath != destinationPath
        }

        guard !validItems.isEmpty else {
            messageManager.showInfo(L.Move.Message.noMoveNeeded, description: L.Move.Message.alreadyAtDestination)
            return
        }

        print("📦 开始移动 \(validItems.count) 个项目到: \(destinationPath.isEmpty ? "根目录" : destinationPath)")

        // 配置移动队列管理器
        moveQueueManager.configure(r2Service: r2Service, bucketName: bucket.name)

        // 添加到移动队列
        moveQueueManager.addMoveTasks(validItems, to: destinationPath)
    }
    
    /// 获取路径的父目录
    private func getParentPath(of key: String) -> String {
        let trimmedKey = key.hasSuffix("/") ? String(key.dropLast()) : key
        if let lastSlashIndex = trimmedKey.lastIndex(of: "/") {
            return String(trimmedKey[..<lastSlashIndex]) + "/"
        }
        return ""
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
