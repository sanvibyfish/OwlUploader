//
//  AccountSettingsView.swift
//  OwlUploader
//
//  Created by Sanvi Lu on 2025/5/25.
//

import SwiftUI

/// 账户配置设置视图
/// 提供 R2 账户凭证的输入、验证和测试功能
struct AccountSettingsView: View {
    // MARK: - State Properties
    
    /// 表单输入状态
    @State private var accountID: String = ""
    @State private var accessKeyID: String = ""
    @State private var secretAccessKey: String = ""
    @State private var endpointURL: String = ""
    @State private var defaultBucketName: String = ""
    @State private var publicDomain: String = ""
    
    /// UI 状态管理
    @State private var isSaving: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: ConnectionTestResult = .none
    
    /// 账户管理器
    @StateObject private var accountManager = R2AccountManager.shared
    
    /// 消息管理器
    @EnvironmentObject var messageManager: MessageManager
    
    /// R2 服务实例
    @EnvironmentObject var r2Service: R2Service
    
    /// 断开连接确认对话框
    @State private var showDisconnectConfirmation: Bool = false
    
    // MARK: - 连接测试结果枚举
    
    enum ConnectionTestResult {
        case none
        case success
        case failure(String)
        
        var color: Color {
            switch self {
            case .none:
                return .secondary
            case .success:
                return .green
            case .failure:
                return .red
            }
        }
        
        var icon: String {
            switch self {
            case .none:
                return "circle"
            case .success:
                return "checkmark.circle.fill"
            case .failure:
                return "xmark.circle.fill"
            }
        }
        
        var message: String {
            switch self {
            case .none:
                return "未测试"
            case .success:
                return "连接成功"
            case .failure(let error):
                return "连接失败: \(error)"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 页面标题和描述
                VStack(spacing: 8) {
                    Text("R2 账户配置")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("配置您的 Cloudflare R2 账户信息以开始使用")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // 账户信息卡片
                VStack(spacing: 0) {
                    // 卡片标题
                    HStack {
                        Label("账户信息", systemImage: "person.crop.circle")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    VStack(spacing: 16) {
                        // Account ID
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Account ID")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            
                            TextField("请输入 Cloudflare Account ID", text: $accountID)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .onChange(of: accountID) { _ in
                                    resetTestResult()
                                }
                        }
                        
                        // Access Key ID
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Access Key ID")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            
                            TextField("请输入 Access Key ID", text: $accessKeyID)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .onChange(of: accessKeyID) { _ in
                                    resetTestResult()
                                }
                        }
                        
                        // Secret Access Key
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Secret Access Key")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            
                            SecureField("请输入 Secret Access Key", text: $secretAccessKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .onChange(of: secretAccessKey) { _ in
                                    resetTestResult()
                                }
                        }
                        
                        // Endpoint URL
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Endpoint URL")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            
                            TextField("例如: https://your-account.r2.cloudflarestorage.com", text: $endpointURL)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .onChange(of: endpointURL) { _ in
                                    resetTestResult()
                                }
                        }
                        
                        // 默认存储桶名称
                        VStack(alignment: .leading, spacing: 6) {
                            Text("默认存储桶名称")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextField("请输入存储桶名称（可选）", text: $defaultBucketName)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .onChange(of: defaultBucketName) { _ in
                                    resetTestResult()
                                }
                            
                            Text("如果您的 API Token 没有 listBuckets 权限，请在此输入要访问的存储桶名称")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                        
                        // 公共域名
                        VStack(alignment: .leading, spacing: 6) {
                            Text("公共域名")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextField("例如: cdn.example.com", text: $publicDomain)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .onChange(of: publicDomain) { _ in
                                    resetTestResult()
                                }
                            
                            Text("配置自定义域名后，文件链接将使用此域名而非默认的 Cloudflare 域名")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                
                // 连接状态卡片
                VStack(spacing: 0) {
                    // 卡片标题
                    HStack {
                        Label("连接状态", systemImage: "network")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    VStack(spacing: 16) {
                        // 当前连接状态
                        HStack(spacing: 12) {
                            Image(systemName: r2Service.isConnected ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundColor(r2Service.isConnected ? .green : .secondary)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r2Service.isConnected ? "已连接到 R2 服务" : "未连接")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(r2Service.isConnected ? .green : .secondary)
                                
                                if r2Service.isConnected {
                                    Text("连接正常，可以进行文件操作")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // 断开连接操作区域（优化布局，更美观）
                        if r2Service.isConnected {
                            Divider()
                                .padding(.top, 12)
                            
                            VStack(spacing: 12) {
                                // 操作说明
                                Text("如需重新配置账户或切换服务，可以断开当前连接")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                // 断开连接按钮
                                Button(action: {
                                    showDisconnectConfirmation = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "power")
                                            .font(.caption)
                                        Text("断开连接")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.red)
                                    )
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding(.top, 8)
                        }
                        
                        if !r2Service.isConnected {
                            Divider()
                            
                            // 连接测试区域
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: testResult.icon)
                                        .foregroundColor(testResult.color)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("连接测试")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text(testResult.message)
                                            .font(.caption)
                                            .foregroundColor(testResult.color)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("测试连接") {
                                        testConnection()
                                    }
                                    .disabled(!isFormValid || isTesting)
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                                
                                if isTesting {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("正在测试连接...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                
                // 帮助信息卡片
                VStack(spacing: 0) {
                    HStack {
                        Label("配置指南", systemImage: "questionmark.circle")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HelpItem(
                            icon: "person.badge.key",
                            title: "Account ID",
                            description: "在 Cloudflare 控制台的右侧边栏可以找到"
                        )
                        
                        HelpItem(
                            icon: "key",
                            title: "Access Key",
                            description: "在 R2 管理页面创建 API 令牌"
                        )
                        
                        HelpItem(
                            icon: "link",
                            title: "Endpoint URL",
                            description: "通常格式为 https://<account-id>.r2.cloudflarestorage.com"
                        )
                        
                        HelpItem(
                            icon: "folder",
                            title: "默认存储桶",
                            description: "如果 API Token 权限受限，请指定要访问的存储桶名称"
                        )
                        
                        HelpItem(
                            icon: "globe",
                            title: "公共域名",
                            description: "配置自定义域名用于生成文件的公共访问链接"
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                
                // 操作按钮区域
                HStack(spacing: 12) {
                    Button("重置") {
                        resetForm()
                    }
                    .disabled(isSaving)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Spacer()
                    
                    Button("保存配置") {
                        saveAccount()
                    }
                    .disabled(!isFormValid || isSaving)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: 800)
        .navigationTitle("账户设置")
        .onAppear {
            loadExistingAccount()
        }
        .alert("断开连接", isPresented: $showDisconnectConfirmation) {
            Button("取消", role: .cancel) { }
            Button("断开连接", role: .destructive) {
                disconnectFromR2Service()
            }
        } message: {
            Text("确定要断开与 R2 服务的连接吗？\n\n断开后将清除当前会话状态，需要重新连接才能使用文件管理功能。")
        }
    }
    
    // MARK: - Computed Properties
    
    /// 表单验证：检查所有必填字段是否已填写
    private var isFormValid: Bool {
        !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !accessKeyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !endpointURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidURL(endpointURL)
    }
    
    // MARK: - Methods
    
    /// 验证 URL 格式
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return url.scheme?.lowercased() == "https" && url.host != nil
    }
    
    /// 重置测试结果
    private func resetTestResult() {
        testResult = .none
    }
    
    /// 测试连接
    private func testConnection() {
        guard isFormValid else { return }
        
        isTesting = true
        testResult = .none
        
        Task {
            do {
                // 创建临时账户对象进行测试
                let trimmedBucketName = defaultBucketName.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedPublicDomain = publicDomain.trimmingCharacters(in: .whitespacesAndNewlines)
                let testAccount = R2Account(
                    accountID: accountID.trimmingCharacters(in: .whitespacesAndNewlines),
                    accessKeyID: accessKeyID.trimmingCharacters(in: .whitespacesAndNewlines),
                    endpointURL: endpointURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    defaultBucketName: trimmedBucketName.isEmpty ? nil : trimmedBucketName,
                    publicDomain: trimmedPublicDomain.isEmpty ? nil : trimmedPublicDomain
                )
                
                let testSecretKey = secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 创建临时 R2Service 实例进行测试
                let testService = R2Service()
                try await testService.initialize(with: testAccount, secretAccessKey: testSecretKey)
                
                // 执行连接测试
                let success = try await testService.testConnection()
                
                await MainActor.run {
                    isTesting = false
                    if success {
                        testResult = .success
                        messageManager.showSuccess("连接测试成功", description: "R2 账户配置有效，可以正常连接")
                        
                        // 测试成功后自动保存账户配置
                        saveAccountAfterSuccessfulTest()
                    } else {
                        testResult = .failure("连接测试失败")
                        messageManager.showError("连接测试失败", description: "无法连接到 R2 服务，请检查配置信息")
                    }
                }
                
            } catch let error as R2ServiceError {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(error.localizedDescription)
                    messageManager.showError(error)
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    let errorMessage = "连接测试失败：\(error.localizedDescription)"
                    testResult = .failure(errorMessage)
                    messageManager.showError("连接测试失败", description: error.localizedDescription)
                }
            }
        }
    }
    
    /// 测试成功后自动保存账户配置并连接
    private func saveAccountAfterSuccessfulTest() {
        guard isFormValid else { return }
        
        let trimmedBucketName = defaultBucketName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPublicDomain = publicDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = R2Account(
            accountID: accountID.trimmingCharacters(in: .whitespacesAndNewlines),
            accessKeyID: accessKeyID.trimmingCharacters(in: .whitespacesAndNewlines),
            endpointURL: endpointURL.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultBucketName: trimmedBucketName.isEmpty ? nil : trimmedBucketName,
            publicDomain: trimmedPublicDomain.isEmpty ? nil : trimmedPublicDomain
        )
        
        do {
            // 保存账户配置
            try accountManager.saveAccount(account, secretAccessKey: secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines))
            
            // 触发 R2Service 连接
            Task {
                                 do {
                     // 直接使用当前输入的凭证进行连接
                     try await r2Service.initialize(with: account, secretAccessKey: secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines))
                     
                     await MainActor.run {
                         print("🎯 连接成功，当前 r2Service.isConnected = \(r2Service.isConnected)")
                         print("🎯 r2Service 实例地址: \(Unmanaged.passUnretained(r2Service).toOpaque())")
                         
                         // 强制触发状态更新通知
                         r2Service.objectWillChange.send()
                         
                         messageManager.showSuccess("连接成功", description: "已成功连接到 R2 服务，可以选择存储桶了")
                         
                         // 延迟一下再检查状态
                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                             print("🔄 延迟检查: r2Service.isConnected = \(r2Service.isConnected)")
                         }
                     }
                 } catch {
                     await MainActor.run {
                         print("❌ 连接失败: \(error.localizedDescription)")
                         messageManager.showError("连接失败", description: "保存成功但连接失败：\(error.localizedDescription)")
                     }
                 }
            }
            
        } catch {
            messageManager.showError("保存失败", description: "保存账户配置时发生错误：\(error.localizedDescription)")
        }
    }
    
    /// 保存账户配置
    private func saveAccount() {
        guard isFormValid else {
            messageManager.showError("表单验证失败", description: "请检查所有必填字段是否正确填写")
            return
        }
        
        isSaving = true
        
        let trimmedBucketName = defaultBucketName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPublicDomain = publicDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = R2Account(
            accountID: accountID.trimmingCharacters(in: .whitespacesAndNewlines),
            accessKeyID: accessKeyID.trimmingCharacters(in: .whitespacesAndNewlines),
            endpointURL: endpointURL.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultBucketName: trimmedBucketName.isEmpty ? nil : trimmedBucketName,
            publicDomain: trimmedPublicDomain.isEmpty ? nil : trimmedPublicDomain
        )
        
        do {
            try accountManager.saveAccount(account, secretAccessKey: secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines))
            messageManager.showSuccess("保存成功", description: "账户配置已成功保存")
            // 重置测试结果，因为配置已更改
            testResult = .none
        } catch {
            messageManager.showError("保存失败", description: "保存账户配置时发生错误：\(error.localizedDescription)")
        }
        
        isSaving = false
    }
    
    /// 重置表单
    private func resetForm() {
        accountID = ""
        accessKeyID = ""
        secretAccessKey = ""
        endpointURL = ""
        defaultBucketName = ""
        publicDomain = ""
        testResult = .none
    }
    
    /// 加载现有账户配置
    private func loadExistingAccount() {
        if let account = accountManager.currentAccount {
            accountID = account.accountID
            accessKeyID = account.accessKeyID
            endpointURL = account.endpointURL
            defaultBucketName = account.defaultBucketName ?? ""
            publicDomain = account.publicDomain ?? ""
            
            // 安全地从 Keychain 加载 SECRET_ACCESS_KEY，提升用户体验
            do {
                let credentials = try accountManager.getCompleteCredentials(for: account)
                secretAccessKey = credentials.secretAccessKey
                print("✅ 成功从 Keychain 加载 SECRET_ACCESS_KEY")
            } catch {
                print("⚠️  从 Keychain 加载 SECRET_ACCESS_KEY 失败: \(error.localizedDescription)")
                // 加载失败时不影响其他字段，secretAccessKey 保持为空
                secretAccessKey = ""
            }
        }
    }
    
    /// 断开 R2 服务连接
    private func disconnectFromR2Service() {
        // 调用 R2Service 的断开连接方法
        r2Service.disconnect()
        
        // 重置测试结果
        testResult = .none
        
        // 显示成功消息
        messageManager.showSuccess("断开连接成功", description: "已成功断开与 R2 服务的连接")
    }
    

}

// MARK: - Helper Views

/// 帮助信息项组件
struct HelpItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    AccountSettingsView()
        .environmentObject(MessageManager())
} 