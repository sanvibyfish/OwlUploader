//
//  R2AccountManager.swift
//  OwlUploader
//
//  Created on 2025-05-25.
//

import Foundation
import SwiftUI

/// R2 账户管理器
/// 负责管理 R2 账户的存储、加载、更新和删除操作
@MainActor
class R2AccountManager: ObservableObject {
    
    // MARK: - 发布的属性
    
    /// 当前已保存的所有账户
    @Published var accounts: [R2Account] = []
    
    /// 当前选中的账户
    @Published var currentAccount: R2Account?
    
    /// 是否正在加载
    @Published var isLoading: Bool = false
    
    /// 错误信息
    @Published var errorMessage: String?
    
    // MARK: - 私有属性
    
    private let keychainService = KeychainService.shared
    private let userDefaults = UserDefaults.standard
    
    // MARK: - 单例
    
    /// 共享实例
    static let shared = R2AccountManager()
    
    private init() {
        loadAccounts()
    }
    
    // MARK: - 公共方法
    
    /// 加载所有已保存的账户
    func loadAccounts() {
        isLoading = true
        errorMessage = nil
        
        do {
            // 从 UserDefaults 加载账户基础信息
            if let data = userDefaults.data(forKey: R2Account.userDefaultsKey) {
                let loadedAccounts = try JSONDecoder().decode([R2Account].self, from: data)
                
                // 验证每个账户在 Keychain 中是否有对应的 Secret Access Key
                let validAccounts = loadedAccounts.filter { account in
                    keychainService.hasSecretAccessKey(for: account)
                }
                
                self.accounts = validAccounts
                
                // 如果有无效账户（Keychain 中找不到对应 Secret Key），清理它们
                if validAccounts.count != loadedAccounts.count {
                    try saveAccountsToUserDefaults()
                }
            } else {
                self.accounts = []
            }
            
            // 加载当前选中的账户
            loadCurrentAccount()
            
        } catch {
            self.errorMessage = "加载账户配置失败: \(error.localizedDescription)"
            self.accounts = []
        }
        
        isLoading = false
    }
    
    /// 保存新的账户配置
    /// - Parameters:
    ///   - account: 账户基础信息
    ///   - secretAccessKey: Secret Access Key
    /// - Throws: 保存过程中的错误
    func saveAccount(_ account: R2Account, secretAccessKey: String) throws {
        // 验证账户配置
        guard account.isValid() else {
            throw AccountManagerError.invalidAccount
        }
        
        guard !secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccountManagerError.invalidSecretKey
        }
        
        // 检查是否已存在相同的账户
        if let existingIndex = accounts.firstIndex(where: { $0.accountID == account.accountID && $0.accessKeyID == account.accessKeyID }) {
            // 更新现有账户
            var updatedAccount = account
            updatedAccount = updatedAccount.updated()
            accounts[existingIndex] = updatedAccount
            
            // 更新 Keychain 中的 Secret Key
            try keychainService.updateSecretAccessKey(secretAccessKey, for: updatedAccount)
        } else {
            // 添加新账户
            accounts.append(account)
            
            // 存储 Secret Key 到 Keychain
            try keychainService.storeSecretAccessKey(secretAccessKey, for: account)
        }
        
        // 保存到 UserDefaults
        try saveAccountsToUserDefaults()
        
        // 如果这是第一个账户，设为当前账户
        if currentAccount == nil {
            setCurrentAccount(account)
        }
    }
    
    /// 删除账户
    /// - Parameter account: 要删除的账户
    /// - Throws: 删除过程中的错误
    func deleteAccount(_ account: R2Account) throws {
        // 从数组中移除
        accounts.removeAll { $0.id == account.id }
        
        // 从 Keychain 中删除 Secret Key
        try? keychainService.deleteSecretAccessKey(for: account)
        
        // 保存到 UserDefaults
        try saveAccountsToUserDefaults()
        
        // 如果删除的是当前账户，清空当前账户
        if currentAccount?.id == account.id {
            setCurrentAccount(nil)
        }
    }
    
    /// 获取账户的完整凭证信息（包括 Secret Access Key）
    /// - Parameter account: 账户对象
    /// - Returns: 包含 Secret Access Key 的完整凭证
    /// - Throws: 获取过程中的错误
    func getCompleteCredentials(for account: R2Account) throws -> CompleteR2Credentials {
        let secretAccessKey = try keychainService.retrieveSecretAccessKey(for: account)
        return CompleteR2Credentials(
            account: account,
            secretAccessKey: secretAccessKey
        )
    }
    
    /// 设置当前选中的账户
    /// - Parameter account: 要设为当前的账户，传入 nil 表示清空选择
    func setCurrentAccount(_ account: R2Account?) {
        currentAccount = account
        
        // 保存当前账户 ID 到 UserDefaults
        if let account = account {
            userDefaults.set(account.id.uuidString, forKey: "current_account_id")
        } else {
            userDefaults.removeObject(forKey: "current_account_id")
        }
    }
    
    /// 验证账户连接是否有效（基础验证）
    /// - Parameter account: 要验证的账户
    /// - Returns: 是否有效
    func validateAccount(_ account: R2Account) -> Bool {
        return account.isValid() && keychainService.hasSecretAccessKey(for: account)
    }

    // MARK: - 存储桶管理

    /// 为账户添加存储桶
    /// - Parameters:
    ///   - account: 目标账户
    ///   - bucketName: 存储桶名称
    /// - Throws: 保存过程中的错误
    func addBucket(to account: R2Account, bucketName: String) throws {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            throw AccountManagerError.accountNotFound
        }

        let trimmedName = bucketName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // 检查是否已存在
        guard !accounts[index].bucketNames.contains(trimmedName) else { return }

        // 添加存储桶
        accounts[index] = accounts[index].addingBucket(trimmedName)

        // 同步更新 currentAccount
        if currentAccount?.id == account.id {
            currentAccount = accounts[index]
        }

        // 保存到 UserDefaults
        try saveAccountsToUserDefaults()
    }

    /// 从账户移除存储桶
    /// - Parameters:
    ///   - account: 目标账户
    ///   - bucketName: 存储桶名称
    /// - Throws: 保存过程中的错误
    func removeBucket(from account: R2Account, bucketName: String) throws {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            throw AccountManagerError.accountNotFound
        }

        // 移除存储桶
        accounts[index] = accounts[index].removingBucket(bucketName)

        // 同步更新 currentAccount
        if currentAccount?.id == account.id {
            currentAccount = accounts[index]
        }

        // 保存到 UserDefaults
        try saveAccountsToUserDefaults()
    }

    /// 更新账户信息
    /// - Parameter account: 更新后的账户
    /// - Throws: 保存过程中的错误
    func updateAccount(_ account: R2Account) throws {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            throw AccountManagerError.accountNotFound
        }

        accounts[index] = account

        // 同步更新 currentAccount
        if currentAccount?.id == account.id {
            currentAccount = account
        }

        // 保存到 UserDefaults
        try saveAccountsToUserDefaults()
    }

    // MARK: - 私有方法
    
    /// 加载当前选中的账户
    private func loadCurrentAccount() {
        guard let currentAccountIdString = userDefaults.string(forKey: "current_account_id"),
              let currentAccountId = UUID(uuidString: currentAccountIdString) else {
            currentAccount = accounts.first
            return
        }
        
        currentAccount = accounts.first { $0.id == currentAccountId } ?? accounts.first
    }
    
    /// 保存账户列表到 UserDefaults
    private func saveAccountsToUserDefaults() throws {
        let data = try JSONEncoder().encode(accounts)
        userDefaults.set(data, forKey: R2Account.userDefaultsKey)
    }
}

// MARK: - 错误类型

extension R2AccountManager {
    
    /// 账户管理器错误
    enum AccountManagerError: Error, LocalizedError {
        case invalidAccount
        case invalidSecretKey
        case accountNotFound
        case saveFailure
        
        var errorDescription: String? {
            switch self {
            case .invalidAccount:
                return "账户配置无效"
            case .invalidSecretKey:
                return "Secret Access Key 无效"
            case .accountNotFound:
                return "未找到指定账户"
            case .saveFailure:
                return "保存账户配置失败"
            }
        }
    }
}

// MARK: - 辅助数据结构

/// 完整的 R2 凭证信息（包含 Secret Access Key）
struct CompleteR2Credentials {
    let account: R2Account
    let secretAccessKey: String
    
    /// 验证凭证是否完整有效
    var isValid: Bool {
        return account.isValid() && !secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
} 