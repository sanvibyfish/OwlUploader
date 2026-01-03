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

    /// 移动队列管理器
    @StateObject private var moveQueueManager = MoveQueueManager()

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
    
    /// 排序方向（true = 升序，false = 降序）
    @State private var sortAscending: Bool = true
    
    /// 要预览的文件对象
    @State private var fileToPreview: FileObject?
    
    /// 拖拽目标状态
    @State private var isTargeted: Bool = false
    
    // MARK: - 拖拽移动相关状态
    
    /// 当前文件冲突（用于显示冲突解决对话框）
    @State private var currentConflict: FileConflict?
    
    /// 待处理的移动操作队列
    @State private var pendingMoveItems: [DraggedFileItem] = []
    
    /// 移动操作的目标路径
    @State private var moveDestinationPrefix: String = ""
    
    /// 应用到所有冲突的解决方式
    @State private var applyToAllResolution: ConflictResolution?
    
    /// 是否正在执行移动操作
    @State private var isMovingFiles: Bool = false

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

            // 组合队列面板（上传 + 移动）
            if uploadQueueManager.isQueuePanelVisible || moveQueueManager.isQueuePanelVisible {
                Divider()
                CombinedQueueView(uploadManager: uploadQueueManager, moveManager: moveQueueManager)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 底部路径栏
            if r2Service.isConnected, let bucket = r2Service.selectedBucket {
                Divider()
                PathBar(
                    bucketName: bucket.name,
                    currentPrefix: currentPrefix,
                    onNavigate: navigateToPath,
                    onMoveFiles: { items, destinationPath in
                        handleMoveFilesToPath(items: items, toPath: destinationPath)
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: uploadQueueManager.isQueuePanelVisible || moveQueueManager.isQueuePanelVisible)
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
        // 冲突解决对话框
        .sheet(item: $currentConflict) { conflict in
            ConflictResolutionSheet(
                conflict: conflict,
                remainingCount: pendingMoveItems.count,
                onResolve: { resolution, applyToAll in
                    handleConflictDialogResult(resolution: resolution, applyToAll: applyToAll)
                }
            )
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
                let filteredFiles = SearchFilterBar.filterAndSort(files: fileObjects, searchText: searchText, filterType: filterType, sortOrder: sortOrder, ascending: sortAscending)
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
            .help("Back")
            
            Button(action: navigateForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!navigationHistory.canGoForward || !canLoadFiles || r2Service.isLoading)
            .help("Forward")
            
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
            Section("筛选") {
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
            
            Section("排序") {
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
        .help("更多选项")
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
            EmptyStateView(
                icon: currentPrefix.isEmpty ? "externaldrive" : "folder",
                title: L.Files.Empty.title,
                description: currentPrefix.isEmpty ? L.Files.Empty.bucketDescription : L.Files.Empty.folderDescription,
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
        let filteredFiles = SearchFilterBar.filterAndSort(files: fileObjects, searchText: searchText, filterType: filterType, sortOrder: sortOrder, ascending: sortAscending)

        return ZStack {
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
                        requestDeleteFile(file)
                    },
                    onDownloadFile: { file in
                        downloadFile(file)
                    },
                    onMoveFiles: { items, targetFolder in
                        handleMoveFiles(items: items, toFolder: targetFolder)
                    },
                    onMoveToPath: { file, destinationPath in
                        handleMoveToPath(file: file, destinationPath: destinationPath)
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
                        requestDeleteFile(file)
                    },
                    onDownloadFile: { file in
                        downloadFile(file)
                    },
                    onMoveFiles: { items, targetFolder in
                        handleMoveFiles(items: items, toFolder: targetFolder)
                    },
                    onMoveToPath: { file, destinationPath in
                        handleMoveToPath(file: file, destinationPath: destinationPath)
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
                let filteredFiles = SearchFilterBar.filterAndSort(files: fileObjects, searchText: searchText, filterType: filterType, sortOrder: sortOrder, ascending: sortAscending)

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
                    self.isInitialLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isInitialLoading = false
                    // 出错时清空列表，显示错误状态
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
    
    // MARK: - 拖拽移动文件
    
    /// 处理拖拽文件到文件夹
    /// - Parameters:
    ///   - items: 要移动的文件项列表
    ///   - targetFolder: 目标文件夹对象
    private func handleMoveFiles(items: [DraggedFileItem], toFolder targetFolder: FileObject) {
        handleMoveFilesToPath(items: items, toPath: targetFolder.key)
    }

    /// 处理右键菜单移动文件到指定路径
    /// 如果文件是多选的一部分，则移动所有选中的文件
    private func handleMoveToPath(file: FileObject, destinationPath: String) {
        // 检查当前文件是否是多选的一部分
        let selectedKeys = selectionManager.getSelectedKeys()

        if selectedKeys.contains(file.key) && selectedKeys.count > 1 {
            // 多选情况：移动所有选中的文件
            let selectedFiles = fileObjects.filter { selectedKeys.contains($0.key) }
            let items = selectedFiles.map { DraggedFileItem(from: $0) }
            handleMoveFilesToPath(items: items, toPath: destinationPath)
        } else {
            // 单选情况：只移动右键点击的文件
            let item = DraggedFileItem(from: file)
            handleMoveFilesToPath(items: [item], toPath: destinationPath)
        }
    }

    /// 处理拖拽文件到指定路径
    /// - Parameters:
    ///   - items: 要移动的文件项列表
    ///   - destinationPath: 目标路径前缀
    private func handleMoveFilesToPath(items: [DraggedFileItem], toPath destinationPath: String) {
        guard let bucket = r2Service.selectedBucket else {
            messageManager.showError("移动失败", description: "未选择存储桶")
            return
        }

        // 过滤掉无效的移动（移动到当前位置）
        let validItems = items.filter { item in
            let itemParentPath = getParentPath(of: item.key)
            return itemParentPath != destinationPath
        }

        guard !validItems.isEmpty else {
            messageManager.showInfo("无需移动", description: "文件已在目标位置")
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
    
    /// 处理移动队列中的下一个项目
    private func processMoveQueue() {
        guard !pendingMoveItems.isEmpty else {
            // 所有项目处理完毕
            finishMoveOperation()
            return
        }
        
        let item = pendingMoveItems.removeFirst()
        
        Task {
            await moveItem(item)
        }
    }
    
    /// 移动单个项目
    private func moveItem(_ item: DraggedFileItem) async {
        guard let bucket = r2Service.selectedBucket else { return }
        
        // 计算目标键
        let destKey = moveDestinationPrefix + item.name + (item.isDirectory ? "/" : "")
        
        do {
            // 检查目标是否存在
            let exists = try await r2Service.objectExists(bucket: bucket.name, key: destKey)
            
            if exists {
                // 存在冲突
                if let resolution = applyToAllResolution {
                    // 使用之前选择的解决方式
                    await handleConflictResolution(item: item, destKey: destKey, resolution: resolution)
                } else {
                    // 显示冲突对话框
                    await MainActor.run {
                        currentConflict = FileConflict(
                            sourceKey: item.key,
                            destinationKey: destKey,
                            fileName: item.name,
                            isDirectory: item.isDirectory
                        )
                    }
                }
            } else {
                // 没有冲突，直接移动
                await performMove(item: item, destKey: destKey)
            }
        } catch {
            await MainActor.run {
                messageManager.showError("检查失败", description: error.localizedDescription)
                processMoveQueue() // 继续处理下一个
            }
        }
    }
    
    /// 处理冲突解决
    private func handleConflictResolution(item: DraggedFileItem, destKey: String, resolution: ConflictResolution) async {
        switch resolution {
        case .replace:
            // 先删除目标，再移动
            await performMove(item: item, destKey: destKey, deleteFirst: true)
        case .skip:
            // 跳过此文件
            await MainActor.run {
                processMoveQueue()
            }
        case .rename:
            // 生成新的文件名
            let newDestKey = await generateUniqueKey(for: destKey)
            await performMove(item: item, destKey: newDestKey)
        case .cancel:
            // 取消整个操作
            await MainActor.run {
                pendingMoveItems.removeAll()
                finishMoveOperation()
            }
        }
    }
    
    /// 生成唯一的目标键（添加序号）
    private func generateUniqueKey(for key: String) async -> String {
        guard let bucket = r2Service.selectedBucket else { return key }
        
        let isDirectory = key.hasSuffix("/")
        let baseName: String
        let ext: String
        
        if isDirectory {
            baseName = String(key.dropLast())
            ext = "/"
        } else {
            let nsPath = key as NSString
            let name = nsPath.deletingPathExtension
            let pathExt = nsPath.pathExtension
            baseName = name
            ext = pathExt.isEmpty ? "" : ".\(pathExt)"
        }
        
        var counter = 1
        var newKey = key
        
        while counter < 100 {
            newKey = "\(baseName) (\(counter))\(ext)"
            do {
                let exists = try await r2Service.objectExists(bucket: bucket.name, key: newKey)
                if !exists {
                    return newKey
                }
            } catch {
                return newKey
            }
            counter += 1
        }
        
        return newKey
    }
    
    /// 执行移动操作
    private func performMove(item: DraggedFileItem, destKey: String, deleteFirst: Bool = false) async {
        guard let bucket = r2Service.selectedBucket else { return }
        
        await MainActor.run {
            isMovingFiles = true
        }
        
        do {
            if deleteFirst {
                // 先删除目标
                if item.isDirectory {
                    _ = try await r2Service.deleteFolder(bucket: bucket.name, folderKey: destKey)
                } else {
                    try await r2Service.deleteObject(bucket: bucket.name, key: destKey)
                }
            }
            
            // 执行移动
            if item.isDirectory {
                let result = try await r2Service.moveFolder(bucket: bucket.name, sourceFolderKey: item.key, destinationFolderKey: destKey)
                print("✅ 文件夹移动完成: \(result.movedCount) 个文件")
            } else {
                try await r2Service.moveObject(bucket: bucket.name, sourceKey: item.key, destinationKey: destKey)
                print("✅ 文件移动完成: \(item.name)")
            }
            
            await MainActor.run {
                processMoveQueue() // 继续处理下一个
            }
        } catch {
            await MainActor.run {
                messageManager.showError("移动失败", description: "\(item.name): \(error.localizedDescription)")
                processMoveQueue() // 继续处理下一个
            }
        }
    }
    
    /// 完成移动操作
    private func finishMoveOperation() {
        isMovingFiles = false
        currentConflict = nil
        applyToAllResolution = nil
        
        // 刷新文件列表
        loadFileList()
        messageManager.showSuccess("移动完成", description: nil)
    }
    
    /// 处理冲突对话框的选择
    private func handleConflictDialogResult(resolution: ConflictResolution, applyToAll: Bool) {
        guard let conflict = currentConflict else { return }
        
        if applyToAll {
            applyToAllResolution = resolution
        }
        
        currentConflict = nil
        
        // 找到对应的项目并处理
        let item = DraggedFileItem(
            key: conflict.sourceKey,
            name: conflict.fileName,
            isDirectory: conflict.isDirectory
        )
        
        Task {
            await handleConflictResolution(item: item, destKey: conflict.destinationKey, resolution: resolution)
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