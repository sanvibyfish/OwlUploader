//
//  FilePreviewView.swift
//  OwlUploader
//
//  文件预览组件 - 现代macOS风格（类似Finder快速查看）
//  支持图片、视频、音频、PDF、文本预览
//

import SwiftUI
import AVKit
import PDFKit
import QuickLook

/// 文件预览视图
struct FilePreviewView: View {
    /// R2 服务实例
    @ObservedObject var r2Service: R2Service
    
    /// 要预览的文件对象
    @State var fileObject: FileObject
    
    /// 所有文件列表（用于导航）
    let allFiles: [FileObject]
    
    /// 存储桶名称
    let bucketName: String
    
    /// 消息管理器
    var messageManager: MessageManager?
    
    /// 导航回调
    var onNavigate: ((FileObject) -> Void)?
    
    /// 下载回调
    var onDownload: ((FileObject) -> Void)?
    
    /// 删除回调
    var onDelete: ((FileObject) -> Void)?
    
    /// 关闭回调
    let onDismiss: () -> Void
    
    /// 预览数据
    @State private var previewData: Data?
    
    /// 加载状态
    @State private var isLoading: Bool = true
    
    /// 错误信息
    @State private var errorMessage: String?
    
    /// 本地临时文件 URL
    @State private var localFileURL: URL?
    
    /// 当前文件索引
    private var currentIndex: Int? {
        allFiles.firstIndex(where: { $0.id == fileObject.id })
    }
    
    /// 是否有上一个文件
    private var hasPrevious: Bool {
        guard let index = currentIndex else { return false }
        return index > 0
    }
    
    /// 是否有下一个文件
    private var hasNext: Bool {
        guard let index = currentIndex else { return false }
        return index < allFiles.count - 1
    }
    
    var body: some View {
        ZStack {
            // 系统背景（自适应亮暗模式）
            Color(nsColor: .controlBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 工具栏
                modernToolbar
                
                // 预览内容
                contentView
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadPreviewData()
        }
        .onDisappear {
            // 清理临时文件
            cleanupTempFile()
        }
        .onChange(of: fileObject.id) { _, _ in
            // 文件变化时重新加载
            cleanupTempFile()
            resetState()
            loadPreviewData()
        }
        // 键盘快捷键
        .onKeyPress(.leftArrow) {
            navigateToPrevious()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateToNext()
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }
    
    // MARK: - 子视图
    
    /// 现代化工具栏（类似Quick Look）
    /// 使用 ZStack 三层布局：文件信息左对齐、导航按钮固定居中、操作按钮右对齐
    private var modernToolbar: some View {
        ZStack {
            // 中层：导航按钮（固定居中，不受文件名长度影响）
            toolbarNavigationButtons
            
            // 左右两侧使用 HStack
            HStack(spacing: 0) {
                // 左侧：文件信息
                toolbarFileInfo
                
                Spacer(minLength: 100) // 确保导航按钮有足够空间
                
                // 右侧：操作按钮
                toolbarActionButtons
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.95)
        )
    }
    
    /// 工具栏 - 文件信息（左侧）
    private var toolbarFileInfo: some View {
        HStack(spacing: 12) {
            // 文件类型图标
            Image(systemName: fileIcon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(fileObject.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 6) {
                    Text(fileObject.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    
                    Text("·")
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    
                    Text(fileType.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
            }
        }
        .frame(maxWidth: 280, alignment: .leading) // 限制最大宽度，防止挤压导航按钮
    }
    
    /// 工具栏 - 导航按钮（居中）
    private var toolbarNavigationButtons: some View {
        HStack(spacing: 8) {
            Button(action: navigateToPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .frame(width: 32, height: 32)
                    .background(hasPrevious ? Color(nsColor: .controlAccentColor).opacity(0.2) : Color.clear)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!hasPrevious)
            .opacity(hasPrevious ? 1.0 : 0.3)
            .help(L.Help.previousFile)
            
            Button(action: navigateToNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .frame(width: 32, height: 32)
                    .background(hasNext ? Color(nsColor: .controlAccentColor).opacity(0.2) : Color.clear)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!hasNext)
            .opacity(hasNext ? 1.0 : 0.3)
            .help(L.Help.nextFile)
        }
    }
    
    /// 工具栏 - 操作按钮（右侧）
    private var toolbarActionButtons: some View {
        HStack(spacing: 12) {
            // 下载按钮
            if !fileObject.isDirectory {
                Button(action: { onDownload?(fileObject) }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 18))
                        .foregroundColor(Color(nsColor: .controlAccentColor))
                }
                .buttonStyle(.plain)
                .help(L.Help.download)
            }
            
            // 复制链接按钮
            if !fileObject.isDirectory {
                Button(action: copyFileURL) {
                    Image(systemName: "link")
                        .font(.system(size: 18))
                        .foregroundColor(Color(nsColor: .controlAccentColor))
                }
                .buttonStyle(.plain)
                .help(L.Help.copyLink)
            }
            
            // 删除按钮
            Button(action: { onDelete?(fileObject) }) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(Color(nsColor: .systemRed))
            }
            .buttonStyle(.plain)
            .help(L.Help.delete)
            
            // 分隔线
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1, height: 20)
            
            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
            }
            .buttonStyle(.plain)
            .help(L.Help.closeEsc)
        }
    }
    
    /// 内容视图
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            // 系统背景色（自适应亮暗模式）
            Color(nsColor: .controlBackgroundColor)
            
            if let error = errorMessage {
                errorView(error)
            } else if isLoading {
                loadingView
            } else {
                // 预览内容居中显示
                previewContent
            }
        }
    }
    
    /// 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(.circular)
            
            Text(L.Preview.loading)
                .font(.system(size: 14))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 错误视图
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(nsColor: .systemOrange))

            Text(L.Preview.cannotPreview)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(nsColor: .labelColor))

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 预览内容
    @ViewBuilder
    private var previewContent: some View {
        switch fileType {
        case .image:
            imagePreview
        case .video:
            videoPreview
        case .audio:
            audioPreview
        case .pdf:
            pdfPreview
        case .text:
            textPreview
        case .unknown:
            unknownTypeView
        }
    }
    
    /// 图片预览（居中显示，类似Quick Look）
    private var imagePreview: some View {
        Group {
            if let data = previewData, let nsImage = NSImage(data: data) {
                GeometryReader { geometry in
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .padding(40)
            } else {
                errorView(L.Preview.cannotLoadImage)
            }
        }
    }

    /// 视频预览
    private var videoPreview: some View {
        Group {
            if let url = localFileURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
            } else {
                errorView(L.Preview.cannotLoadVideo)
            }
        }
    }
    
    /// 音频预览
    private var audioPreview: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.note.list")
                .font(.system(size: 72))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
            
            Text(fileObject.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(nsColor: .labelColor))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if let url = localFileURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 60)
                    .frame(maxWidth: 400)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// PDF 预览
    private var pdfPreview: some View {
        Group {
            if let data = previewData, let pdfDocument = PDFDocument(data: data) {
                PDFKitView(document: pdfDocument)
                    .padding(20)
            } else {
                errorView(L.Preview.cannotLoadPDF)
            }
        }
    }

    /// 文本预览
    private var textPreview: some View {
        Group {
            if let data = previewData, let text = String(data: data, encoding: .utf8) {
                ScrollView {
                    Text(text)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(40)
                        .textSelection(.enabled)
                }
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                errorView(L.Preview.cannotLoadText)
            }
        }
    }
    
    /// 未知类型视图
    private var unknownTypeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.questionmark.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))

            Text(L.Preview.unsupportedType)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(nsColor: .labelColor))

            Text(L.Preview.fileType(fileObject.name.components(separatedBy: ".").last ?? L.Files.FileType.unknown))
                .font(.system(size: 14))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 计算属性
    
    /// 文件类型
    private var fileType: PreviewFileType {
        let ext = fileObject.name.components(separatedBy: ".").last?.lowercased() ?? ""
        
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "bmp", "ico", "svg":
            return .image
        case "mp4", "mov", "avi", "mkv", "webm":
            return .video
        case "mp3", "wav", "flac", "aac", "ogg", "m4a":
            return .audio
        case "pdf":
            return .pdf
        case "txt", "md", "json", "xml", "html", "css", "js", "swift", "py", "rb", "go", "java", "c", "cpp", "h":
            return .text
        default:
            return .unknown
        }
    }
    
    /// 文件图标
    private var fileIcon: String {
        if fileObject.isDirectory {
            return "folder.fill"
        }
        
        switch fileType {
        case .image:
            return "photo.fill"
        case .video:
            return "film.fill"
        case .audio:
            return "music.note"
        case .pdf:
            return "doc.fill"
        case .text:
            return "doc.text.fill"
        case .unknown:
            return "doc.fill"
        }
    }
    
    /// 图标颜色
    private var iconColor: Color {
        if fileObject.isDirectory {
            return .blue
        }
        
        switch fileType {
        case .image:
            return .purple
        case .video:
            return .orange
        case .audio:
            return .pink
        case .pdf:
            return .red
        case .text:
            return .cyan
        case .unknown:
            return .gray
        }
    }
    
    // MARK: - 方法
    
    /// 导航到上一个文件
    private func navigateToPrevious() {
        guard let index = currentIndex, index > 0 else { return }
        let previousFile = allFiles[index - 1]
        
        // 只导航非目录文件
        if !previousFile.isDirectory {
            fileObject = previousFile
            onNavigate?(previousFile)
        }
    }
    
    /// 导航到下一个文件
    private func navigateToNext() {
        guard let index = currentIndex, index < allFiles.count - 1 else { return }
        let nextFile = allFiles[index + 1]
        
        // 只导航非目录文件
        if !nextFile.isDirectory {
            fileObject = nextFile
            onNavigate?(nextFile)
        }
    }
    
    /// 复制文件URL
    private func copyFileURL() {
        guard let fileURL = r2Service.generateFileURL(for: fileObject, in: bucketName) else {
            return
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fileURL, forType: .string)
        messageManager?.showSuccess(L.Message.Success.linkCopied, description: L.Message.Success.linkCopiedDescription)
    }
    
    /// 重置状态
    private func resetState() {
        previewData = nil
        localFileURL = nil
        isLoading = true
        errorMessage = nil
    }
    
    /// 清理临时文件
    private func cleanupTempFile() {
        if let url = localFileURL {
            try? FileManager.default.removeItem(at: url)
            localFileURL = nil
        }
    }
    
    /// 加载预览数据
    private func loadPreviewData() {
        Task {
            do {
                // 创建临时文件
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = UUID().uuidString + "_" + fileObject.name
                let tempURL = tempDir.appendingPathComponent(fileName)
                
                // 下载文件
                try await r2Service.downloadObject(
                    bucket: bucketName,
                    key: fileObject.key,
                    to: tempURL
                )
                
                // 读取数据
                let data = try Data(contentsOf: tempURL)
                
                await MainActor.run {
                    self.previewData = data
                    self.localFileURL = tempURL
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

/// 预览文件类型
enum PreviewFileType {
    case image
    case video
    case audio
    case pdf
    case text
    case unknown

    var displayName: String {
        switch self {
        case .image: return L.Files.FileType.image
        case .video: return L.Files.FileType.video
        case .audio: return L.Files.FileType.audio
        case .pdf: return L.Files.FileType.pdf
        case .text: return L.Files.FileType.text
        case .unknown: return L.Files.FileType.unknown
        }
    }
}

/// PDFKit 视图包装器
struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}
