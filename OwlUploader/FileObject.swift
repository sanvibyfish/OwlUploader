import Foundation

/// 表示 R2/S3 存储中的文件或文件夹对象
/// 
/// FileObject 是一个统一的数据模型，用于表示对象存储中的文件和文件夹。
/// 由于 S3/R2 本质上是扁平的键值存储，"文件夹"是通过对象键中的分隔符 `/` 来模拟的。
/// 这个模型将两者统一抽象，通过 `isDirectory` 属性来区分类型。
struct FileObject: Identifiable, Hashable {
    
    // MARK: - Properties
    
    /// 唯一标识符，使用完整的 key 作为 ID
    var id: String { key }
    
    /// 显示名称（不含路径前缀）
    /// 例如：对于 key "documents/2023/report.pdf"，name 为 "report.pdf"
    let name: String
    
    /// 完整的 S3 对象键（完整路径）
    /// 例如："documents/2023/report.pdf" 或 "documents/2023/"
    let key: String
    
    /// 文件大小（字节）
    /// 文件夹为 nil，因为文件夹在 S3 中没有实际大小概念
    let size: Int64?
    
    /// 最后修改时间
    /// 文件夹为 nil，因为文件夹没有修改时间概念
    let lastModifiedDate: Date?
    
    /// 是否为文件夹
    /// true: 文件夹，false: 文件
    let isDirectory: Bool
    
    /// 文件的 ETag（实体标签）
    /// 用于文件完整性检查和缓存验证，文件夹为 nil
    let eTag: String?
    
    // MARK: - Initializers
    
    /// 创建文件对象的完整初始化器
    /// - Parameters:
    ///   - name: 显示名称
    ///   - key: 完整的对象键
    ///   - size: 文件大小（文件夹传 nil）
    ///   - lastModifiedDate: 最后修改时间（文件夹传 nil）
    ///   - isDirectory: 是否为文件夹
    ///   - eTag: 文件的 ETag（文件夹传 nil）
    init(name: String, key: String, size: Int64? = nil, lastModifiedDate: Date? = nil, isDirectory: Bool, eTag: String? = nil) {
        self.name = name
        self.key = key
        self.size = size
        self.lastModifiedDate = lastModifiedDate
        self.isDirectory = isDirectory
        self.eTag = eTag
    }
    
    /// 创建文件夹对象的便捷初始化器
    /// - Parameters:
    ///   - name: 文件夹显示名称
    ///   - key: 完整的文件夹键（通常以 `/` 结尾）
    static func folder(name: String, key: String) -> FileObject {
        return FileObject(
            name: name,
            key: key,
            size: nil,
            lastModifiedDate: nil,
            isDirectory: true,
            eTag: nil
        )
    }
    
    /// 创建文件对象的便捷初始化器
    /// - Parameters:
    ///   - name: 文件显示名称
    ///   - key: 完整的文件键
    ///   - size: 文件大小
    ///   - lastModifiedDate: 最后修改时间
    ///   - eTag: 文件的 ETag
    static func file(name: String, key: String, size: Int64, lastModifiedDate: Date, eTag: String) -> FileObject {
        return FileObject(
            name: name,
            key: key,
            size: size,
            lastModifiedDate: lastModifiedDate,
            isDirectory: false,
            eTag: eTag
        )
    }
    
    /// 从 S3 ListObjectsV2 的 CommonPrefix 创建文件夹对象
    /// - Parameter prefix: S3 返回的公共前缀
    /// - Parameter currentPrefix: 当前路径前缀，用于计算相对路径
    /// - Returns: 文件夹对象
    static func fromCommonPrefix(_ prefix: String, currentPrefix: String = "") -> FileObject {
        // 移除当前路径前缀，获取相对路径
        let relativePath = prefix.hasPrefix(currentPrefix) ? String(prefix.dropFirst(currentPrefix.count)) : prefix
        
        // 移除末尾的 `/` 获取文件夹名称
        let folderName = relativePath.hasSuffix("/") ? String(relativePath.dropLast()) : relativePath
        
        return FileObject.folder(name: folderName, key: prefix)
    }
    
    /// 从 S3 ListObjectsV2 的 Object 创建文件对象
    /// - Parameter object: S3 返回的对象信息
    /// - Parameter currentPrefix: 当前路径前缀，用于计算相对路径
    /// - Returns: 文件对象
    static func fromS3Object(key: String, size: Int64, lastModified: Date, eTag: String, currentPrefix: String = "") -> FileObject {
        // 移除当前路径前缀，获取相对路径
        let relativePath = key.hasPrefix(currentPrefix) ? String(key.dropFirst(currentPrefix.count)) : key
        
        // 获取文件名（路径的最后一部分）
        let fileName = relativePath.split(separator: "/").last.map(String.init) ?? relativePath
        
        return FileObject.file(
            name: fileName,
            key: key,
            size: size,
            lastModifiedDate: lastModified,
            eTag: eTag
        )
    }
}

// MARK: - Computed Properties

extension FileObject {
    
    /// 格式化的文件大小字符串
    /// 例如："1.2 MB", "345 KB", "2.1 GB"
    var formattedSize: String {
        guard let size = size, !isDirectory else { return "" }
        
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    /// 格式化的最后修改时间字符串
    /// 例如："2023-05-25 14:30"
    var formattedLastModified: String {
        guard let lastModifiedDate = lastModifiedDate, !isDirectory else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastModifiedDate)
    }
    
    /// 文件类型图标的 SF Symbol 名称
    /// 根据文件扩展名或是否为文件夹返回合适的图标
    var iconName: String {
        if isDirectory {
            return "folder.fill"
        }
        
        // 根据文件扩展名返回不同图标
        let fileExtension = (name as NSString).pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return "doc.fill"
        case "txt", "md", "rtf":
            return "doc.text.fill"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv":
            return "video.fill"
        case "mp3", "wav", "aac", "flac":
            return "music.note"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox.fill"
        case "xlsx", "xls", "csv":
            return "tablecells.fill"
        case "pptx", "ppt":
            return "rectangle.on.rectangle.fill"
        case "docx", "doc":
            return "doc.richtext.fill"
        default:
            return "doc.fill"
        }
    }
    
    /// 文件扩展名
    var fileExtension: String {
        if isDirectory { return "" }
        return (name as NSString).pathExtension
    }
    
    /// 是否为图片文件
    var isImage: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"]
        return imageExtensions.contains(fileExtension.lowercased())
    }
    
    /// 是否为视频文件
    var isVideo: Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm"]
        return videoExtensions.contains(fileExtension.lowercased())
    }
    
    /// 是否为音频文件
    var isAudio: Bool {
        let audioExtensions = ["mp3", "wav", "aac", "flac", "ogg", "m4a"]
        return audioExtensions.contains(fileExtension.lowercased())
    }
}

// MARK: - Preview Data

extension FileObject {
    
    /// 用于 SwiftUI 预览的示例数据
    static var sampleData: [FileObject] {
        [
            // 文件夹示例
            FileObject.folder(name: "Documents", key: "documents/"),
            FileObject.folder(name: "Images", key: "images/"),
            FileObject.folder(name: "Videos", key: "videos/"),
            
            // 文件示例
            FileObject.file(
                name: "Report.pdf",
                key: "documents/2023/report.pdf",
                size: 2_456_789,
                lastModifiedDate: Date().addingTimeInterval(-86400), // 昨天
                eTag: "d41d8cd98f00b204e9800998ecf8427e"
            ),
            FileObject.file(
                name: "Photo.jpg",
                key: "images/vacation/photo.jpg",
                size: 4_567_890,
                lastModifiedDate: Date().addingTimeInterval(-3600), // 1小时前
                eTag: "098f6bcd4621d373cade4e832627b4f6"
            ),
            FileObject.file(
                name: "Data.csv",
                key: "data/export/data.csv",
                size: 123_456,
                lastModifiedDate: Date().addingTimeInterval(-7200), // 2小时前
                eTag: "5d41402abc4b2a76b9719d911017c592"
            ),
            FileObject.file(
                name: "Presentation.pptx",
                key: "documents/presentation.pptx",
                size: 8_901_234,
                lastModifiedDate: Date().addingTimeInterval(-172800), // 2天前
                eTag: "7d865e959b2466918c9863afca942d0f"
            ),
            FileObject.file(
                name: "Archive.zip",
                key: "backups/archive.zip",
                size: 15_678_901,
                lastModifiedDate: Date().addingTimeInterval(-604800), // 1周前
                eTag: "098f6bcd4621d373cade4e832627b4f6"
            )
        ]
    }
    
    /// 用于测试的空文件夹列表
    static var emptyData: [FileObject] {
        []
    }
    
    /// 用于测试的仅包含文件夹的数据
    static var foldersOnlyData: [FileObject] {
        [
            FileObject.folder(name: "Documents", key: "documents/"),
            FileObject.folder(name: "Images", key: "images/"),
            FileObject.folder(name: "Videos", key: "videos/"),
            FileObject.folder(name: "Backups", key: "backups/")
        ]
    }
    
    /// 用于测试的仅包含文件的数据
    static var filesOnlyData: [FileObject] {
        [
            FileObject.file(
                name: "README.md",
                key: "README.md",
                size: 1234,
                lastModifiedDate: Date(),
                eTag: "d41d8cd98f00b204e9800998ecf8427e"
            ),
            FileObject.file(
                name: "config.json",
                key: "config.json",
                size: 567,
                lastModifiedDate: Date().addingTimeInterval(-3600),
                eTag: "098f6bcd4621d373cade4e832627b4f6"
            )
        ]
    }
} 