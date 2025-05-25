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
    
    /// 默认存储桶名称（可选，用于没有 listBuckets 权限的情况）
    var defaultBucketName: String?
    
    /// 公共域名（可选，用于生成文件的公共访问链接）
    var publicDomain: String?
    
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
    ///   - defaultBucketName: 默认存储桶名称，可选
    ///   - publicDomain: 公共域名，可选
    init(accountID: String, accessKeyID: String, endpointURL: String? = nil, displayName: String? = nil, defaultBucketName: String? = nil, publicDomain: String? = nil) {
        self.id = UUID()
        self.accountID = accountID
        self.accessKeyID = accessKeyID
        self.endpointURL = endpointURL ?? Self.defaultCloudflareR2EndpointURL(for: accountID)
        self.displayName = displayName ?? String(accountID.prefix(8))
        self.defaultBucketName = defaultBucketName
        self.publicDomain = publicDomain
        self.createdAt = Date()
        self.updatedAt = Date()
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
    ///   - defaultBucketName: 新的默认存储桶名称
    ///   - publicDomain: 新的公共域名
    /// - Returns: 更新后的账户对象
    func updated(accountID: String? = nil, 
                 accessKeyID: String? = nil, 
                 endpointURL: String? = nil, 
                 displayName: String? = nil,
                 defaultBucketName: String? = nil,
                 publicDomain: String? = nil) -> R2Account {
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
        if let defaultBucketName = defaultBucketName {
            updated.defaultBucketName = defaultBucketName
        }
        if let publicDomain = publicDomain {
            updated.publicDomain = publicDomain
        }
        updated.updatedAt = Date()
        return updated
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
    
    /// 为当前账户生成 Keychain 账户标识符
    var keychainAccountIdentifier: String {
        return "\(accountID)_\(accessKeyID)"
    }
} 