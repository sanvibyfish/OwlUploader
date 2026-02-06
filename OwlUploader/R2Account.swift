//
//  R2Account.swift
//  OwlUploader
//
//  Created on 2025-05-25.
//

import Foundation

/// R2 账户配置数据模型
/// 用于存储和管理用户的 Cloudflare R2 或 S3 兼容服务的账户信息
struct R2Account: Codable, Identifiable {
    
    // MARK: - 属性
    
    /// 唯一标识符
    let id: UUID
    
    /// 账户 ID（Cloudflare R2 账户 ID）
    var accountID: String
    
    /// Access Key ID（用于 API 认证）
    var accessKeyID: String
    
    /// 服务端点 URL（默认为 Cloudflare R2 端点）
    var endpointURL: String
    
    /// 账户名称（用户自定义，便于识别）
    var displayName: String
    
    /// 默认存储桶名称（已废弃，使用 bucketNames 代替）
    @available(*, deprecated, message: "使用 bucketNames 代替")
    var defaultBucketName: String? {
        get { bucketNames.first }
        set {
            if let name = newValue, !name.isEmpty {
                if !bucketNames.contains(name) {
                    bucketNames.insert(name, at: 0)
                }
            }
        }
    }

    /// 存储桶名称列表（支持多个存储桶）
    var bucketNames: [String]

    /// 公共域名列表（用于生成文件的公共访问链接）
    var publicDomains: [String]

    /// 默认公共域名索引
    var defaultPublicDomainIndex: Int

    /// Cloudflare Zone ID（用于清除 CDN 缓存，可选）
    var cloudflareZoneID: String?

    /// 是否启用自动清除 CDN 缓存
    var autoPurgeCDNCache: Bool

    /// 获取默认公共域名
    var defaultPublicDomain: String? {
        guard !publicDomains.isEmpty,
              defaultPublicDomainIndex >= 0,
              defaultPublicDomainIndex < publicDomains.count else {
            return nil
        }
        return publicDomains[defaultPublicDomainIndex]
    }

    /// 账户创建时间
    let createdAt: Date

    /// 最后更新时间
    var updatedAt: Date
    
    // MARK: - 初始化方法
    
    /// 创建新的 R2 账户配置
    /// - Parameters:
    ///   - accountID: R2 账户 ID
    ///   - accessKeyID: Access Key ID
    ///   - endpointURL: 服务端点 URL，如果为空则使用默认的 Cloudflare R2 端点
    ///   - displayName: 显示名称，如果为空则使用 Account ID 的前8位字符
    ///   - bucketNames: 存储桶名称列表
    ///   - publicDomains: 公共域名列表
    ///   - defaultPublicDomainIndex: 默认域名索引
    ///   - cloudflareZoneID: Cloudflare Zone ID（可选）
    ///   - autoPurgeCDNCache: 是否自动清除 CDN 缓存
    init(accountID: String, accessKeyID: String, endpointURL: String? = nil, displayName: String? = nil, bucketNames: [String] = [], publicDomains: [String] = [], defaultPublicDomainIndex: Int = 0, cloudflareZoneID: String? = nil, autoPurgeCDNCache: Bool = false) {
        self.id = UUID()
        self.accountID = accountID
        self.accessKeyID = accessKeyID
        self.endpointURL = endpointURL ?? Self.defaultCloudflareR2EndpointURL(for: accountID)
        self.displayName = displayName ?? String(accountID.prefix(8))
        self.bucketNames = bucketNames
        self.publicDomains = publicDomains
        self.defaultPublicDomainIndex = defaultPublicDomainIndex
        self.cloudflareZoneID = cloudflareZoneID
        self.autoPurgeCDNCache = autoPurgeCDNCache
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Codable (支持旧数据迁移)

    private enum CodingKeys: String, CodingKey {
        case id, accountID, accessKeyID, endpointURL, displayName
        case bucketNames, defaultBucketName // 支持两种格式
        case publicDomain, publicDomains, defaultPublicDomainIndex // 支持两种格式
        case cloudflareZoneID, autoPurgeCDNCache // CDN 缓存配置
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        accountID = try container.decode(String.self, forKey: .accountID)
        accessKeyID = try container.decode(String.self, forKey: .accessKeyID)
        endpointURL = try container.decode(String.self, forKey: .endpointURL)
        displayName = try container.decode(String.self, forKey: .displayName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // 迁移逻辑：优先读取 bucketNames，否则从 defaultBucketName 迁移
        if let names = try container.decodeIfPresent([String].self, forKey: .bucketNames) {
            bucketNames = names
        } else if let defaultName = try container.decodeIfPresent(String.self, forKey: .defaultBucketName),
                  !defaultName.isEmpty {
            bucketNames = [defaultName]
        } else {
            bucketNames = []
        }

        // 迁移逻辑：优先读取 publicDomains，否则从 publicDomain 迁移
        if let domains = try container.decodeIfPresent([String].self, forKey: .publicDomains) {
            publicDomains = domains
            defaultPublicDomainIndex = try container.decodeIfPresent(Int.self, forKey: .defaultPublicDomainIndex) ?? 0
        } else if let singleDomain = try container.decodeIfPresent(String.self, forKey: .publicDomain),
                  !singleDomain.isEmpty {
            publicDomains = [singleDomain]
            defaultPublicDomainIndex = 0
        } else {
            publicDomains = []
            defaultPublicDomainIndex = 0
        }

        // CDN 缓存配置（可选，默认关闭）
        cloudflareZoneID = try container.decodeIfPresent(String.self, forKey: .cloudflareZoneID)
        autoPurgeCDNCache = try container.decodeIfPresent(Bool.self, forKey: .autoPurgeCDNCache) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(accountID, forKey: .accountID)
        try container.encode(accessKeyID, forKey: .accessKeyID)
        try container.encode(endpointURL, forKey: .endpointURL)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(bucketNames, forKey: .bucketNames)
        try container.encode(publicDomains, forKey: .publicDomains)
        try container.encode(defaultPublicDomainIndex, forKey: .defaultPublicDomainIndex)
        try container.encodeIfPresent(cloudflareZoneID, forKey: .cloudflareZoneID)
        try container.encode(autoPurgeCDNCache, forKey: .autoPurgeCDNCache)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
    // MARK: - 静态方法
    
    /// 为指定账户 ID 生成默认的 Cloudflare R2 端点 URL
    /// - Parameter accountID: R2 账户 ID
    /// - Returns: 默认的端点 URL
    static func defaultCloudflareR2EndpointURL(for accountID: String) -> String {
        return "https://\(accountID).r2.cloudflarestorage.com"
    }
    
    /// 验证账户配置是否有效
    /// - Returns: 如果配置有效返回 true，否则返回 false
    func isValid() -> Bool {
        return !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !accessKeyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !endpointURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               isValidURL(endpointURL)
    }
    
    /// 验证 URL 格式是否正确
    /// - Parameter urlString: 待验证的 URL 字符串
    /// - Returns: 如果 URL 格式正确返回 true，否则返回 false
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    // MARK: - 更新方法

    /// 更新账户信息
    /// - Parameters:
    ///   - accountID: 新的账户 ID
    ///   - accessKeyID: 新的 Access Key ID
    ///   - endpointURL: 新的端点 URL
    ///   - displayName: 新的显示名称
    ///   - bucketNames: 新的存储桶名称列表
    ///   - publicDomains: 新的公共域名列表
    ///   - defaultPublicDomainIndex: 新的默认域名索引
    ///   - cloudflareZoneID: 新的 Cloudflare Zone ID
    ///   - autoPurgeCDNCache: 是否自动清除 CDN 缓存
    /// - Returns: 更新后的账户对象
    func updated(accountID: String? = nil,
                 accessKeyID: String? = nil,
                 endpointURL: String? = nil,
                 displayName: String? = nil,
                 bucketNames: [String]? = nil,
                 publicDomains: [String]? = nil,
                 defaultPublicDomainIndex: Int? = nil,
                 cloudflareZoneID: String?? = nil,
                 autoPurgeCDNCache: Bool? = nil) -> R2Account {
        var updated = self
        if let accountID = accountID {
            updated.accountID = accountID
        }
        if let accessKeyID = accessKeyID {
            updated.accessKeyID = accessKeyID
        }
        if let endpointURL = endpointURL {
            updated.endpointURL = endpointURL
        }
        if let displayName = displayName {
            updated.displayName = displayName
        }
        if let bucketNames = bucketNames {
            updated.bucketNames = bucketNames
        }
        if let publicDomains = publicDomains {
            updated.publicDomains = publicDomains
        }
        if let defaultPublicDomainIndex = defaultPublicDomainIndex {
            updated.defaultPublicDomainIndex = defaultPublicDomainIndex
        }
        if let cloudflareZoneID = cloudflareZoneID {
            updated.cloudflareZoneID = cloudflareZoneID
        }
        if let autoPurgeCDNCache = autoPurgeCDNCache {
            updated.autoPurgeCDNCache = autoPurgeCDNCache
        }
        updated.updatedAt = Date()
        return updated
    }

    // MARK: - 存储桶管理

    /// 添加存储桶
    /// - Parameter bucketName: 存储桶名称
    /// - Returns: 更新后的账户对象
    func addingBucket(_ bucketName: String) -> R2Account {
        guard !bucketName.isEmpty, !bucketNames.contains(bucketName) else { return self }
        var updated = self
        updated.bucketNames.append(bucketName)
        updated.updatedAt = Date()
        return updated
    }

    /// 移除存储桶
    /// - Parameter bucketName: 存储桶名称
    /// - Returns: 更新后的账户对象
    func removingBucket(_ bucketName: String) -> R2Account {
        var updated = self
        updated.bucketNames.removeAll { $0 == bucketName }
        updated.updatedAt = Date()
        return updated
    }

    /// 检查是否包含指定存储桶
    /// - Parameter bucketName: 存储桶名称
    /// - Returns: 是否包含
    func hasBucket(_ bucketName: String) -> Bool {
        return bucketNames.contains(bucketName)
    }
}

// MARK: - Equatable

extension R2Account: Equatable {
    static func == (lhs: R2Account, rhs: R2Account) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension R2Account: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 用于存储的键值常量

extension R2Account {
    
    /// UserDefaults 中存储账户配置的键
    static let userDefaultsKey = "stored_r2_accounts"

    /// Keychain 中存储 Secret Access Key 的服务名
    static let keychainServiceName = "OwlUploader.R2Account"

    /// Keychain 中存储 Cloudflare API Token 的服务名
    static let cloudflareAPITokenServiceName = "OwlUploader.CloudflareAPIToken"

    /// 为当前账户生成 Keychain 账户标识符
    var keychainAccountIdentifier: String {
        return "\(accountID)_\(accessKeyID)"
    }
} 