//
//  AccountSettingsView.swift
//  OwlUploader
//
//  设置页面 - 账户管理
//

import SwiftUI

/// 设置视图
struct AccountSettingsView: View {
    /// 账户管理器
    @EnvironmentObject var accountManager: R2AccountManager

    /// R2服务
    @EnvironmentObject var r2Service: R2Service

    /// 消息管理器
    @EnvironmentObject var messageManager: MessageManager

    /// 删除确认
    @State private var accountToDelete: R2Account?
    @State private var showDeleteConfirmation: Bool = false

    /// 添加账户
    @State private var showAddAccountSheet: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 页面标题
                VStack(spacing: 8) {
                    Text("设置")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("管理您的 R2 账户")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // 账户管理
                accountsSection

                // 关于
                aboutSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 40)
        }
        .navigationTitle("设置")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.windowBackground)
        .sheet(isPresented: $showAddAccountSheet) {
            AddAccountSheet(
                accountManager: accountManager,
                r2Service: r2Service,
                messageManager: messageManager,
                onDismiss: { showAddAccountSheet = false }
            )
        }
        .alert("删除账户", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {
                accountToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let account = accountToDelete {
                    deleteAccount(account)
                }
            }
        } message: {
            if let account = accountToDelete {
                Text("确定要删除账户 '\(account.displayName)' 吗？\n\n这将移除所有相关的凭证信息。")
            }
        }
    }

    // MARK: - 账户管理区域

    private var accountsSection: some View {
        SettingsCard(title: "账户", icon: "person.crop.circle") {
            if accountManager.accounts.isEmpty {
                // 无账户状态
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text("暂无账户")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        showAddAccountSheet = true
                    } label: {
                        Label("添加账户", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                // 账户列表
                VStack(spacing: 0) {
                    ForEach(accountManager.accounts) { account in
                        AccountRowView(
                            account: account,
                            isConnected: accountManager.currentAccount?.id == account.id && r2Service.isConnected,
                            onDelete: {
                                accountToDelete = account
                                showDeleteConfirmation = true
                            }
                        )

                        if account.id != accountManager.accounts.last?.id {
                            Divider()
                        }
                    }
                }

                Divider()
                    .padding(.top, 8)

                // 添加账户按钮
                Button {
                    showAddAccountSheet = true
                } label: {
                    Label("添加账户", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundColor(AppColors.primary)
                .padding(.top, 12)
            }
        }
    }

    // MARK: - 关于区域

    private var aboutSection: some View {
        SettingsCard(title: "关于", icon: "info.circle") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OwlUploader")
                        .font(.headline)
                    Text("版本 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 私有方法

    private func deleteAccount(_ account: R2Account) {
        // 如果是当前连接的账户，先断开
        if accountManager.currentAccount?.id == account.id {
            r2Service.disconnect()
        }

        // 删除账户
        do {
            try accountManager.deleteAccount(account)
            messageManager.showSuccess("账户已删除", description: "'\(account.displayName)' 已从列表中移除")
        } catch {
            messageManager.showError("删除失败", description: error.localizedDescription)
        }

        accountToDelete = nil
    }
}

// MARK: - 账户行视图

struct AccountRowView: View {
    let account: R2Account
    let isConnected: Bool
    let onDelete: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 状态指示器
            Circle()
                .fill(isConnected ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)

            // 账户信息
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: 8) {
                    Text(account.accessKeyID)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !account.bucketNames.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(account.bucketNames.count) 个存储桶")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // 连接状态标签
            if isConnected {
                Text("已连接")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }

            // 删除按钮（hover时显示）
            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(AppColors.destructive)
                }
                .buttonStyle(.plain)
                .help("删除账户")
                .transition(AppTransitions.hoverActions)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(AppAnimations.hover) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - 设置卡片组件

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.primary)
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // 卡片内容
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(AppColors.contentBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
    }
}

// MARK: - 预览

#Preview {
    AccountSettingsView()
        .environmentObject(MessageManager())
        .environmentObject(R2Service.shared)
        .environmentObject(R2AccountManager.shared)
        .frame(width: 600, height: 500)
}
