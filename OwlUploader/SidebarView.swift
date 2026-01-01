//
//  SidebarView.swift
//  OwlUploader
//
//  新侧边栏组件 - 支持多账户和多存储桶显示
//

import SwiftUI

/// 侧边栏视图
/// 支持多账户展示和快速切换存储桶
struct SidebarView: View {
    /// 当前显示的主视图绑定
    @Binding var selectedView: ContentView.MainViewSelection?
    
    /// R2 服务实例
    @ObservedObject var r2Service: R2Service
    
    /// R2 账户管理器实例
    @ObservedObject var accountManager: R2AccountManager
    
    /// 消息管理器
    @EnvironmentObject var messageManager: MessageManager
    
    /// 展开的账户列表（通过账户 ID 追踪）
    @State private var expandedAccounts: Set<UUID> = []
    
    /// 正在加载存储桶的账户
    @State private var loadingBuckets: Set<UUID> = []
    
    /// 账户对应的存储桶列表缓存
    @State private var accountBuckets: [UUID: [BucketItem]] = [:]
    
    /// 断开连接确认对话框
    @State private var showDisconnectConfirmation: Bool = false
    
    /// 要断开的账户
    @State private var accountToDisconnect: R2Account?
    
    var body: some View {
        List(selection: $selectedView) {
            // 欢迎页面链接
            NavigationLink(value: ContentView.MainViewSelection.welcome) {
                Label("欢迎", systemImage: "house")
            }
            
            // 账户设置链接
            NavigationLink(value: ContentView.MainViewSelection.settings) {
                Label("账户设置", systemImage: "gear")
            }
            
            Divider()
            
            // 账户和存储桶列表
            if accountManager.accounts.isEmpty {
                emptyAccountsView
            } else {
                accountsListView
            }
            
            Spacer()
            
            // 底部连接状态
            connectionStatusView
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("OwlUploader")
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
        .confirmationDialog(
            "断开账户连接",
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("断开", role: .destructive) {
                if let account = accountToDisconnect {
                    disconnectAccount(account)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let account = accountToDisconnect {
                Text("确定要断开账户 '\(account.accessKeyID)' 的连接吗？")
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 空账户提示视图
    private var emptyAccountsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("未配置账户")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("添加账户") {
                selectedView = .settings
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    /// 账户列表视图
    private var accountsListView: some View {
        ForEach(accountManager.accounts) { account in
            accountSection(for: account)
        }
    }
    
    /// 单个账户分区
    @ViewBuilder
    private func accountSection(for account: R2Account) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedAccounts.contains(account.id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedAccounts.insert(account.id)
                        loadBucketsForAccount(account)
                    } else {
                        expandedAccounts.remove(account.id)
                    }
                }
            )
        ) {
            // 存储桶列表
            if loadingBuckets.contains(account.id) {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("加载中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 8)
            } else if let buckets = accountBuckets[account.id], !buckets.isEmpty {
                ForEach(buckets) { bucket in
                    bucketRow(bucket: bucket, account: account)
                }
            } else {
                // 无存储桶或需要手动输入
                VStack(alignment: .leading, spacing: 4) {
                    Text("输入存储桶名称连接")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let defaultBucket = account.defaultBucketName, !defaultBucket.isEmpty {
                        bucketRow(
                            bucket: BucketItem(name: defaultBucket, creationDate: nil, owner: nil, region: "auto"),
                            account: account
                        )
                    }
                }
                .padding(.leading, 8)
            }
        } label: {
            accountHeader(for: account)
        }
        .contextMenu {
            Button("刷新存储桶列表") {
                loadBucketsForAccount(account, forceRefresh: true)
            }
            Divider()
            Button("断开连接", role: .destructive) {
                accountToDisconnect = account
                showDisconnectConfirmation = true
            }
        }
    }
    
    /// 账户头部视图
    private func accountHeader(for account: R2Account) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "cloud")
                .foregroundColor(isAccountConnected(account) ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(account.accessKeyID.prefix(8) + "...")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let defaultBucket = account.defaultBucketName, !defaultBucket.isEmpty {
                    Text(defaultBucket)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    /// 存储桶行
    private func bucketRow(bucket: BucketItem, account: R2Account) -> some View {
        Button(action: {
            selectBucket(bucket, for: account)
        }) {
            HStack(spacing: 6) {
                Image(systemName: isSelectedBucket(bucket) ? "externaldrive.fill" : "externaldrive")
                    .foregroundColor(isSelectedBucket(bucket) ? .accentColor : .secondary)
                    .font(.caption)
                
                Text(bucket.name)
                    .font(.caption)
                    .foregroundColor(isSelectedBucket(bucket) ? .accentColor : .primary)
                    .lineLimit(1)
                
                Spacer()
                
                if isSelectedBucket(bucket) {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .padding(.leading, 8)
    }
    
    /// 连接状态视图
    private var connectionStatusView: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(r2Service.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(r2Service.isConnected ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let bucket = r2Service.selectedBucket {
                    Text(bucket.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    // MARK: - 辅助方法
    
    /// 检查账户是否已连接
    private func isAccountConnected(_ account: R2Account) -> Bool {
        return accountManager.currentAccount?.id == account.id && r2Service.isConnected
    }
    
    /// 检查是否为当前选中的存储桶
    private func isSelectedBucket(_ bucket: BucketItem) -> Bool {
        return r2Service.selectedBucket?.name == bucket.name
    }
    
    /// 加载账户的存储桶列表
    private func loadBucketsForAccount(_ account: R2Account, forceRefresh: Bool = false) {
        // 如果已有缓存且不是强制刷新，直接返回
        if !forceRefresh, accountBuckets[account.id] != nil {
            return
        }
        
        // R2 不支持 listBuckets，使用默认存储桶
        if let defaultBucket = account.defaultBucketName, !defaultBucket.isEmpty {
            let bucket = BucketItem(name: defaultBucket, creationDate: nil, owner: nil, region: "auto")
            accountBuckets[account.id] = [bucket]
        } else {
            accountBuckets[account.id] = []
        }
    }
    
    /// 选择存储桶
    private func selectBucket(_ bucket: BucketItem, for account: R2Account) {
        Task {
            do {
                // 如果不是当前账户，先切换账户
                if accountManager.currentAccount?.id != account.id {
                    let credentials = try accountManager.getCompleteCredentials(for: account)
                    try await r2Service.initialize(with: credentials.account, secretAccessKey: credentials.secretAccessKey)
                    accountManager.setCurrentAccount(account)
                }
                
                // 选择存储桶
                let _ = try await r2Service.selectBucketDirectly(bucket.name)
                
                // 导航到文件管理页面
                await MainActor.run {
                    selectedView = .files
                    messageManager.showSuccess("已连接", description: "成功连接到存储桶 '\(bucket.name)'")
                }
            } catch {
                await MainActor.run {
                    messageManager.showError("连接失败", description: error.localizedDescription)
                }
            }
        }
    }
    
    /// 断开账户连接
    private func disconnectAccount(_ account: R2Account) {
        if accountManager.currentAccount?.id == account.id {
            r2Service.disconnect()
        }
        expandedAccounts.remove(account.id)
        accountBuckets.removeValue(forKey: account.id)
        messageManager.showSuccess("已断开", description: "账户连接已断开")
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        SidebarView(
            selectedView: .constant(.welcome),
            r2Service: R2Service.preview,
            accountManager: R2AccountManager.shared
        )
        .environmentObject(MessageManager())
        
        Text("内容区域")
    }
}
