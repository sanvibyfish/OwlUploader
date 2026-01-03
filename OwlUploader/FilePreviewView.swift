//
//  FilePreviewView.swift
//  OwlUploader
//
//  文件预览组件
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
    let fileObject: FileObject
    
    /// 存储桶名称
    let bucketName: String
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏（始终可见，包含关闭按钮）
            headerView
            
            Divider()
            
            // 内联加载指示器（不阻塞）
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L.Preview.loading)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            
            // 预览内容
            contentView
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            loadPreviewData()
        }
        .onDisappear {
            // 清理临时文件
            if let url = localFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(fileObject.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(fileObject.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Text(fileType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()

            Button(L.Common.Button.close) {
                onDismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    /// 内容视图
    @ViewBuilder
    private var contentView: some View {
        if let error = errorMessage {
            errorView(error)
        } else if !isLoading {
            // 只在加载完成后显示预览内容
            previewContent
        } else {
            // 加载中时显示空白（顶部有内联指示器）
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    /// 错误视图
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(L.Preview.cannotPreview)
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
    
    /// 图片预览
    private var imagePreview: some View {
        Group {
            if let data = previewData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
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
            } else {
                errorView(L.Preview.cannotLoadVideo)
            }
        }
    }
    
    /// 音频预览
    private var audioPreview: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text(fileObject.name)
                .font(.headline)
            
            if let url = localFileURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// PDF 预览
    private var pdfPreview: some View {
        Group {
            if let data = previewData, let pdfDocument = PDFDocument(data: data) {
                PDFKitView(document: pdfDocument)
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
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            } else {
                errorView(L.Preview.cannotLoadText)
            }
        }
    }
    
    /// 未知类型视图
    private var unknownTypeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(L.Preview.unsupportedType)
                .font(.headline)

            Text(L.Preview.fileType(fileObject.name.components(separatedBy: ".").last ?? L.Files.FileType.unknown))
                .font(.caption)
                .foregroundColor(.secondary)
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
    
    // MARK: - 方法
    
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
