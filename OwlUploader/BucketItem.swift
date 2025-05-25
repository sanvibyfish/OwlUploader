import Foundation

/// 存储桶项目模型
/// 用于表示 R2/S3 存储桶的基本信息
struct BucketItem: Identifiable, Hashable, Codable {
    /// 唯一标识符，使用存储桶名称
    var id: String { name }
    
    /// 存储桶名称
    let name: String
    
    /// 创建日期
    let creationDate: Date?
    
    /// 所有者信息（可选）
    let owner: String?
    
    /// 区域信息（可选）
    let region: String?
    
    /// 初始化方法
    /// - Parameters:
    ///   - name: 存储桶名称
    ///   - creationDate: 创建日期
    ///   - owner: 所有者信息
    ///   - region: 区域信息
    init(name: String, creationDate: Date? = nil, owner: String? = nil, region: String? = nil) {
        self.name = name
        self.creationDate = creationDate
        self.owner = owner
        self.region = region
    }
}

// MARK: - 扩展方法

extension BucketItem {
    /// 格式化的创建日期字符串
    var formattedCreationDate: String {
        guard let creationDate = creationDate else {
            return "未知"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: creationDate)
    }
    
    /// 存储桶显示名称
    /// 如果有区域信息，显示区域；否则只显示名称
    var displayName: String {
        if let region = region, !region.isEmpty {
            return "\(name) (\(region))"
        }
        return name
    }
}

// MARK: - 预览和测试数据

extension BucketItem {
    /// 创建示例数据用于预览和测试
    static var sampleData: [BucketItem] {
        [
            BucketItem(
                name: "my-documents",
                creationDate: Date().addingTimeInterval(-86400 * 30), // 30天前
                region: "auto"
            ),
            BucketItem(
                name: "photo-backup",
                creationDate: Date().addingTimeInterval(-86400 * 7), // 7天前
                region: "auto"
            ),
            BucketItem(
                name: "app-assets",
                creationDate: Date().addingTimeInterval(-86400 * 365), // 1年前
                region: "auto"
            )
        ]
    }
    
    /// 创建空列表示例
    static var emptyData: [BucketItem] {
        []
    }
} 