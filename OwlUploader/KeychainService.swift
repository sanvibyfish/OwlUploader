//
//  KeychainService.swift
//  OwlUploader
//
//  Created on 2025-05-25.
//

import Foundation
import Security

/// Keychain 服务类
/// 提供安全存储和读取敏感数据（如 Secret Access Key）的功能
class KeychainService {
    
    // MARK: - 错误类型定义
    
    /// Keychain 操作错误
    enum KeychainError: Error, LocalizedError {
        case invalidData
        case itemNotFound
        case duplicateItem
        case unexpectedError(status: OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidData:
                return L.Error.Keychain.invalidData
            case .itemNotFound:
                return L.Error.Keychain.itemNotFound
            case .duplicateItem:
                return L.Error.Keychain.duplicateItem
            case .unexpectedError(let status):
                return L.Error.Keychain.unexpectedError(status)
            }
        }
    }
    
    // MARK: - 单例
    
    /// 共享实例
    static let shared = KeychainService()

    private static let keychainQueueKey = DispatchSpecificKey<Void>()
    private static let keychainQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "com.owluploader.keychain", qos: .userInitiated)
        queue.setSpecific(key: keychainQueueKey, value: ())
        return queue
    }()
    
    private init() {}
    
    // MARK: - 公共方法
    
    /// 存储字符串到 Keychain
    /// - Parameters:
    ///   - value: 要存储的字符串值
    ///   - service: 服务名称（用于分组）
    ///   - account: 账户标识符（用于唯一标识）
    /// - Throws: KeychainError
    func store(_ value: String, service: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        try store(data, service: service, account: account)
    }
    
    /// 存储数据到 Keychain
    /// - Parameters:
    ///   - data: 要存储的数据
    ///   - service: 服务名称
    ///   - account: 账户标识符
    /// - Throws: KeychainError
    func store(_ data: Data, service: String, account: String) throws {
        try performKeychainOperation {
            // 先尝试删除已存在的项目
            try? self.delete(service: service, account: account)

            // 创建新的查询字典
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]

            let status = SecItemAdd(query as CFDictionary, nil)

            guard status == errSecSuccess else {
                if status == errSecDuplicateItem {
                    throw KeychainError.duplicateItem
                } else {
                    throw KeychainError.unexpectedError(status: status)
                }
            }
        }
    }
    
    /// 从 Keychain 读取字符串
    /// - Parameters:
    ///   - service: 服务名称
    ///   - account: 账户标识符
    /// - Returns: 存储的字符串值
    /// - Throws: KeychainError
    func retrieve(service: String, account: String) throws -> String {
        let data = try retrieveData(service: service, account: account)
        
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return string
    }
    
    /// 从 Keychain 读取数据
    /// - Parameters:
    ///   - service: 服务名称
    ///   - account: 账户标识符
    /// - Returns: 存储的数据
    /// - Throws: KeychainError
    func retrieveData(service: String, account: String) throws -> Data {
        try performKeychainOperation {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            guard status == errSecSuccess else {
                if status == errSecItemNotFound {
                    throw KeychainError.itemNotFound
                } else {
                    throw KeychainError.unexpectedError(status: status)
                }
            }

            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }

            return data
        }
    }
    
    /// 更新 Keychain 中的字符串值
    /// - Parameters:
    ///   - value: 新的字符串值
    ///   - service: 服务名称
    ///   - account: 账户标识符
    /// - Throws: KeychainError
    func update(_ value: String, service: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        try update(data, service: service, account: account)
    }
    
    /// 更新 Keychain 中的数据
    /// - Parameters:
    ///   - data: 新的数据
    ///   - service: 服务名称
    ///   - account: 账户标识符
    /// - Throws: KeychainError
    func update(_ data: Data, service: String, account: String) throws {
        try performKeychainOperation {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]

            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]

            let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

            guard status == errSecSuccess else {
                if status == errSecItemNotFound {
                    throw KeychainError.itemNotFound
                } else {
                    throw KeychainError.unexpectedError(status: status)
                }
            }
        }
    }
    
    /// 从 Keychain 删除项目
    /// - Parameters:
    ///   - service: 服务名称
    ///   - account: 账户标识符
    /// - Throws: KeychainError
    func delete(service: String, account: String) throws {
        try performKeychainOperation {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]

            let status = SecItemDelete(query as CFDictionary)

            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.unexpectedError(status: status)
            }
        }
    }
    
    /// 检查 Keychain 中是否存在指定项目
    /// - Parameters:
    ///   - service: 服务名称
    ///   - account: 账户标识符
    /// - Returns: 如果项目存在返回 true，否则返回 false
    func exists(service: String, account: String) -> Bool {
        do {
            _ = try retrieveData(service: service, account: account)
            return true
        } catch {
            return false
        }
    }

    private func performKeychainOperation<T>(_ work: @escaping () throws -> T) throws -> T {
        if DispatchQueue.getSpecific(key: Self.keychainQueueKey) != nil {
            return try work()
        }

        let group = DispatchGroup()
        var result: Result<T, Error>!

        group.enter()
        Self.keychainQueue.async {
            result = Result { try work() }
            group.leave()
        }
        group.wait()

        return try result.get()
    }
}

// MARK: - R2Account 扩展

extension KeychainService {
    
    /// 为 R2Account 存储 Secret Access Key
    /// - Parameters:
    ///   - secretAccessKey: Secret Access Key
    ///   - account: R2 账户对象
    /// - Throws: KeychainError
    func storeSecretAccessKey(_ secretAccessKey: String, for account: R2Account) throws {
        try store(secretAccessKey, 
                 service: R2Account.keychainServiceName, 
                 account: account.keychainAccountIdentifier)
    }
    
    /// 为 R2Account 读取 Secret Access Key
    /// - Parameter account: R2 账户对象
    /// - Returns: Secret Access Key
    /// - Throws: KeychainError
    func retrieveSecretAccessKey(for account: R2Account) throws -> String {
        return try retrieve(service: R2Account.keychainServiceName, 
                          account: account.keychainAccountIdentifier)
    }
    
    /// 为 R2Account 更新 Secret Access Key
    /// - Parameters:
    ///   - secretAccessKey: 新的 Secret Access Key
    ///   - account: R2 账户对象
    /// - Throws: KeychainError
    func updateSecretAccessKey(_ secretAccessKey: String, for account: R2Account) throws {
        do {
            try update(secretAccessKey, 
                      service: R2Account.keychainServiceName, 
                      account: account.keychainAccountIdentifier)
        } catch KeychainError.itemNotFound {
            // 如果项目不存在，则创建新的
            try store(secretAccessKey, 
                     service: R2Account.keychainServiceName, 
                     account: account.keychainAccountIdentifier)
        }
    }
    
    /// 为 R2Account 删除 Secret Access Key
    /// - Parameter account: R2 账户对象
    /// - Throws: KeychainError
    func deleteSecretAccessKey(for account: R2Account) throws {
        try delete(service: R2Account.keychainServiceName, 
                  account: account.keychainAccountIdentifier)
    }
    
    /// 检查 R2Account 是否已存储 Secret Access Key
    /// - Parameter account: R2 账户对象
    /// - Returns: 如果已存储返回 true，否则返回 false
    func hasSecretAccessKey(for account: R2Account) -> Bool {
        return exists(service: R2Account.keychainServiceName,
                     account: account.keychainAccountIdentifier)
    }
}

// MARK: - Cloudflare API Token 扩展

extension KeychainService {

    /// 为 R2Account 存储 Cloudflare API Token
    /// - Parameters:
    ///   - apiToken: Cloudflare API Token
    ///   - account: R2 账户对象
    /// - Throws: KeychainError
    func storeCloudflareAPIToken(_ apiToken: String, for account: R2Account) throws {
        try store(apiToken,
                 service: R2Account.cloudflareAPITokenServiceName,
                 account: account.keychainAccountIdentifier)
    }

    /// 为 R2Account 读取 Cloudflare API Token
    /// - Parameter account: R2 账户对象
    /// - Returns: Cloudflare API Token，如果不存在则返回 nil
    func retrieveCloudflareAPIToken(for account: R2Account) -> String? {
        return try? retrieve(service: R2Account.cloudflareAPITokenServiceName,
                            account: account.keychainAccountIdentifier)
    }

    /// 为 R2Account 更新或存储 Cloudflare API Token
    /// - Parameters:
    ///   - apiToken: 新的 Cloudflare API Token
    ///   - account: R2 账户对象
    /// - Throws: KeychainError
    func updateCloudflareAPIToken(_ apiToken: String, for account: R2Account) throws {
        do {
            try update(apiToken,
                      service: R2Account.cloudflareAPITokenServiceName,
                      account: account.keychainAccountIdentifier)
        } catch KeychainError.itemNotFound {
            // 如果项目不存在，则创建新的
            try store(apiToken,
                     service: R2Account.cloudflareAPITokenServiceName,
                     account: account.keychainAccountIdentifier)
        }
    }

    /// 为 R2Account 删除 Cloudflare API Token
    /// - Parameter account: R2 账户对象
    /// - Throws: KeychainError
    func deleteCloudflareAPIToken(for account: R2Account) throws {
        try delete(service: R2Account.cloudflareAPITokenServiceName,
                  account: account.keychainAccountIdentifier)
    }

    /// 检查 R2Account 是否已存储 Cloudflare API Token
    /// - Parameter account: R2 账户对象
    /// - Returns: 如果已存储返回 true，否则返回 false
    func hasCloudflareAPIToken(for account: R2Account) -> Bool {
        return exists(service: R2Account.cloudflareAPITokenServiceName,
                     account: account.keychainAccountIdentifier)
    }
} 
