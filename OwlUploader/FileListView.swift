//
//  FileListView.swift
//  OwlUploader
//
//  Created by Sanvi Lu on 2025/5/25.
//

import SwiftUI

/// 文件列表视图
/// 用于显示选定存储桶中的文件和文件夹列表
struct FileListView: View {
    /// R2 服务实例
    @ObservedObject var r2Service: R2Service
    
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
    
    /// 是否显示诊断信息
    @State private var showingDiagnostics: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部状态栏
            statusBarView
            
            Divider()
            
            // 主内容区域
            mainContentView
        }
        .navigationTitle("文件管理")
        .onAppear {
            loadFileList()
        }
        .onChange(of: r2Service.selectedBucket) { _ in
            // 当选择的存储桶改变时，重置并重新加载
            currentPrefix = ""
            loadFileList()
        }
        .sheet(isPresented: $showingCreateFolderSheet) {
            CreateFolderSheet(
                isPresented: $showingCreateFolderSheet,
                onCreateFolder: createFolderWithName
            )
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.data, .item], // 允许所有文件类型
            allowsMultipleSelection: false
        ) { result in
            // 👇 立即在回调中处理文件上传，不缓存 fileURL
            switch result {
            case .success(let urls):
                guard let fileURL = urls.first else { return }
                
                // 立即进行所有验证和上传操作
                uploadFileImmediately(fileURL)
                
            case .failure(let error):
                messageManager.showError("文件选择失败", description: error.localizedDescription)
            }
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView(r2Service: r2Service)
        }
    }
    
    /// 顶部状态栏视图
    @ViewBuilder
    private var statusBarView: some View {
        VStack(spacing: 0) {
            // 第一行：连接状态和控制按钮
            HStack {
                // 连接和存储桶状态
                HStack(spacing: 8) {
                    Circle()
                        .fill(r2Service.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    if isUploading {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(uploadMessage)
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else if r2Service.isConnected {
                        if let bucket = r2Service.selectedBucket {
                            Text("已连接")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("未选择存储桶")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("未连接")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 控制按钮
                HStack(spacing: 12) {
                    // 主要操作按钮组
                    HStack(spacing: 8) {
                        // 上传文件按钮
                        Button(action: {
                            showingFileImporter = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("上传文件")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isUploading || r2Service.isLoading ? Color.gray.opacity(0.3) : Color.blue.opacity(0.1))
                        )
                        .foregroundColor(isUploading || r2Service.isLoading ? .secondary : .blue)
                        .disabled(!canLoadFiles || r2Service.isLoading || isUploading)
                        
                        // 创建文件夹按钮
                        Button(action: {
                            showingCreateFolderSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus")
                                Text("新建文件夹")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isUploading || r2Service.isLoading ? Color.gray.opacity(0.3) : Color.green.opacity(0.1))
                        )
                        .foregroundColor(isUploading || r2Service.isLoading ? .secondary : .green)
                        .disabled(!canLoadFiles || r2Service.isLoading || isUploading)
                    }
                    
                    // 分隔线
                    Divider()
                        .frame(height: 20)
                    
                    // 导航按钮组
                    HStack(spacing: 8) {
                        // 返回上级按钮（当不在根目录时显示）
                        if !currentPrefix.isEmpty {
                            Button(action: goUpOneLevel) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.circle")
                                    Text("上级")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.orange.opacity(0.1))
                            )
                            .foregroundColor(.orange)
                            .disabled(r2Service.isLoading || isUploading)
                        }
                        
                        // 刷新按钮
                        Button(action: loadFileList) {
                            HStack(spacing: 4) {
                                Image(systemName: r2Service.isLoading ? "arrow.clockwise" : "arrow.clockwise.circle")
                                Text("刷新")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .foregroundColor(.secondary)
                        .disabled(!canLoadFiles || r2Service.isLoading || isUploading)
                        
                        // 诊断按钮
                        Button(action: {
                            showingDiagnostics = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield")
                                Text("诊断")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.purple.opacity(0.1))
                        )
                        .foregroundColor(.purple)
                        .disabled(r2Service.isLoading || isUploading)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // 第二行：面包屑导航（当连接且选择存储桶时显示）
            if r2Service.isConnected, let bucket = r2Service.selectedBucket {
                Divider()
                
                BreadcrumbView(
                    currentPrefix: currentPrefix,
                    selectedBucket: bucket,
                    onNavigate: navigateToPath
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
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
            // 空列表状态
            emptyListView
        } else {
            // 正常文件列表
            fileListView
        }
    }
    
    /// 未连接提示视图
    private var notConnectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("未连接到 R2")
                .font(.headline)
            
            Text("请在侧边栏选择\"账户设置\"来配置您的 R2 账户连接")
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
            
            Text("请选择存储桶")
                .font(.headline)
            
            Text("请在侧边栏选择\"存储桶\"来选择要操作的存储桶")
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
                Text("正在加载文件列表...")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("请稍候")
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
            
            Text("加载失败")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                loadFileList()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 40)
    }
    
    /// 空列表视图
    private var emptyListView: some View {
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
                Text("文件夹为空")
                    .font(.title2)
                    .fontWeight(.medium)
                
                if currentPrefix.isEmpty {
                    Text("此存储桶中暂无文件或文件夹\n使用上方的按钮来上传文件或创建文件夹")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("此文件夹中暂无文件或文件夹\n使用上方的按钮来上传文件或创建文件夹")
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
                    Text("上传文件")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(.green)
                    Text("创建新文件夹")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
    
    /// 文件列表视图
    private var fileListView: some View {
        List {
            // 文件和文件夹列表
            ForEach(fileObjects, id: \.key) { fileObject in
                FileListItemView(
                    fileObject: fileObject,
                    r2Service: r2Service,
                    bucketName: r2Service.selectedBucket?.name,
                    messageManager: messageManager
                )
                .onTapGesture {
                    handleItemTap(fileObject)
                }
            }
        }
        .listStyle(PlainListStyle())
        .overlay(
            // 加载中或上传中的覆盖层
            Group {
                if (r2Service.isLoading && !isInitialLoading) || isUploading {
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .overlay(
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                
                                if isUploading {
                                    Text(uploadMessage)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
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
                    self.fileObjects = objects
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
        loadFileList()
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
                    messageManager.showSuccess("创建成功", description: "文件夹 '\(trimmedName)' 已成功创建")
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
    
    /// 立即上传文件（在 fileImporter 回调中使用）
    /// 必须在 fileImporter 回调的上下文中调用，以确保有文件访问权限
    /// - Parameter fileURL: 本地文件 URL
    private func uploadFileImmediately(_ fileURL: URL) {
        print("🎯 uploadFileImmediately 被调用，文件路径: \(fileURL.path)")
        
        guard canLoadFiles else { 
            print("❌ canLoadFiles = false，无法上传")
            messageManager.showError("无法上传", description: "服务未准备就绪，请先连接账户并选择存储桶")
            return 
        }
        guard let bucket = r2Service.selectedBucket else { 
            print("❌ 未选择存储桶，无法上传")
            messageManager.showError("无法上传", description: "请先选择一个存储桶")
            return 
        }
        
        let fileName = fileURL.lastPathComponent
        print("📄 准备上传文件: \(fileName)")
        
        // 🔐 立即启用安全作用域资源访问
        guard fileURL.startAccessingSecurityScopedResource() else {
            print("❌ 无法获取文件安全作用域权限: \(fileName)")
            messageManager.showError("权限不足", description: "无法获取文件 '\(fileName)' 的访问权限。请尝试将文件移动到文档文件夹或桌面后再试。")
            return
        }
        
        // 确保在方法结束时释放权限
        defer {
            fileURL.stopAccessingSecurityScopedResource()
            print("🔓 已释放文件权限: \(fileName)")
        }
        
        // 立即验证文件访问和读取数据（在权限上下文中）
        let fileData: Data
        do {
            // 先检查文件存在性
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("❌ 文件不存在: \(fileURL.path)")
                messageManager.showError("文件不存在", description: "找不到文件 '\(fileName)'，请重新选择")
                return
            }
            
            // 立即读取文件数据（这会验证权限是否有效）
            fileData = try Data(contentsOf: fileURL)
            print("✅ 成功读取文件数据: \(fileName), 大小: \(fileData.count) bytes")
            
            // 检查文件大小限制
            let maxSize: Int64 = 5 * 1024 * 1024 * 1024 // 5GB
            if fileData.count > maxSize {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useGB, .useMB]
                formatter.countStyle = .file
                let fileSizeString = formatter.string(fromByteCount: Int64(fileData.count))
                print("❌ 文件过大: \(fileSizeString)")
                messageManager.showError("文件过大", description: "文件 '\(fileName)' 大小为 \(fileSizeString)，超过 5GB 限制")
                return
            }
            
            // 显示文件大小信息
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB, .useKB]
            formatter.countStyle = .file
            let fileSizeString = formatter.string(fromByteCount: Int64(fileData.count))
            print("📊 文件大小检查通过: \(fileName) (\(fileSizeString))")
            
        } catch {
            print("❌ 无法读取文件数据: \(error)")
            // 特殊处理权限错误
            if let nsError = error as? NSError, nsError.domain == "NSCocoaErrorDomain", nsError.code == 257 {
                messageManager.showError("文件权限被拒绝", description: "无法访问文件 '\(fileName)'。应用没有读取此文件的权限。建议：1) 将文件移动到文档文件夹或桌面；2) 检查文件权限设置；3) 重新选择文件进行上传。")
            } else {
                messageManager.showError("文件读取失败", description: "无法读取文件 '\(fileName)': \(error.localizedDescription)")
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
        uploadMessage = "正在上传 '\(fileName)'..."
        
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
                    // 上传成功
                    isUploading = false
                    uploadMessage = ""
                    print("✅ 文件上传成功: \(objectKey)")
                    messageManager.showSuccess("上传成功", description: "文件 '\(fileName)' 已成功上传到 \(bucket.name)")
                    // 刷新文件列表以显示新上传的文件
                    loadFileList()
                }
            } catch {
                await MainActor.run {
                    // 上传失败
                    isUploading = false
                    uploadMessage = ""
                    print("❌ 文件上传失败: \(error)")
                    
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
                        messageManager.showError("上传失败", description: "文件 '\(fileName)' 上传失败: \(error.localizedDescription)")
                    }
                }
            }
        }
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
}

// MARK: - 预览

#Preview("未连接状态") {
    FileListView(r2Service: R2Service())
}

#Preview("正常状态") {
    FileListView(r2Service: R2Service.preview)
}

#Preview("加载中状态") {
    let service = R2Service.preview
    service.isLoading = true
    return FileListView(r2Service: service)
} 