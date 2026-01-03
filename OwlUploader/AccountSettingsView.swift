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

    /// 语言管理器
    @StateObject private var languageManager = LanguageManager.shared

    /// 删除确认
    @State private var accountToDelete: R2Account?
    @State private var showDeleteConfirmation: Bool = false

    /// 添加账户
    @State private var showAddAccountSheet: Bool = false

    /// 编辑账户
    @State private var accountToEdit: R2Account?

    /// 语言重启提示
    @State private var showRestartAlert: Bool = false
    @State private var previousLanguage: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 页面标题
                VStack(spacing: 8) {
                    Text(L.Account.Settings.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(L.Account.Settings.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // 账户管理
                accountsSection

                // 上传设置
                uploadSettingsSection

                // 移动设置
                moveSettingsSection

                // 主题设置
                themeSection

                // 语言设置
                languageSection

                // 关于
                aboutSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 40)
        }
        .navigationTitle(L.Account.Settings.title)
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
        .sheet(item: $accountToEdit) { account in
            EditAccountSheet(
                account: account,
                accountManager: accountManager,
                r2Service: r2Service,
                messageManager: messageManager,
                onDismiss: {
                    accountToEdit = nil
                }
            )
        }
        .alert(L.Account.Delete.title, isPresented: $showDeleteConfirmation) {
            Button(L.Common.Button.cancel, role: .cancel) {
                accountToDelete = nil
            }
            Button(L.Common.Button.delete, role: .destructive) {
                if let account = accountToDelete {
                    deleteAccount(account)
                }
            }
        } message: {
            if let account = accountToDelete {
                Text(L.Account.Delete.confirmation(account.displayName))
            }
        }
        .alert(L.Settings.Restart.title, isPresented: $showRestartAlert) {
            Button(L.Settings.Restart.restartNow) {
                restartApp()
            }
            Button(L.Settings.Restart.later, role: .cancel) { }
        } message: {
            Text(L.Settings.Restart.message)
        }
        .onAppear {
            previousLanguage = languageManager.selectedLanguage
        }
        .onChange(of: languageManager.selectedLanguage) { oldValue, newValue in
            if oldValue != newValue && !oldValue.isEmpty {
                showRestartAlert = true
            }
            previousLanguage = newValue
        }
    }

    // MARK: - 账户管理区域

    private var accountsSection: some View {
        SettingsCard(title: L.Account.Settings.sectionTitle, icon: "person.crop.circle") {
            if accountManager.accounts.isEmpty {
                // 无账户状态
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text(L.Account.Settings.noAccounts)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        showAddAccountSheet = true
                    } label: {
                        Label(L.Sidebar.Action.addAccount, systemImage: "plus")
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
                            onEdit: {
                                accountToEdit = account
                            },
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
                    Label(L.Sidebar.Action.addAccount, systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundColor(AppColors.primary)
                .padding(.top, 12)
            }
        }
    }

    // MARK: - 上传设置区域

    /// 并发上传数设置值
    @State private var concurrentUploads: Double = Double(UploadQueueManager.getMaxConcurrentUploads())

    private var uploadSettingsSection: some View {
        SettingsCard(title: L.Settings.Upload.title, icon: "arrow.up.circle") {
            VStack(alignment: .leading, spacing: 16) {
                // 并发上传数设置
                HStack {
                    Text(L.Settings.Upload.concurrentUploads)
                        .font(.body)

                    Spacer()

                    TextField("1-10", value: $concurrentUploads, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: concurrentUploads) { _, newValue in
                            let clamped = min(max(1.0, newValue), 50.0)
                            if clamped != newValue {
                                concurrentUploads = clamped
                            }
                            UploadQueueManager.setMaxConcurrentUploads(Int(clamped))
                        }
                }

                Text(L.Settings.Upload.concurrentHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            concurrentUploads = Double(UploadQueueManager.getMaxConcurrentUploads())
        }
    }

    // MARK: - 移动设置区域

    /// 并发移动数设置值
    @State private var concurrentMoves: Double = Double(MoveQueueManager.getMaxConcurrentMoves())

    private var moveSettingsSection: some View {
        SettingsCard(title: L.Settings.Move.title, icon: "arrow.right.circle") {
            VStack(alignment: .leading, spacing: 16) {
                // 并发移动数设置
                HStack {
                    Text(L.Settings.Move.concurrentMoves)
                        .font(.body)

                    Spacer()

                    TextField("1-10", value: $concurrentMoves, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: concurrentMoves) { _, newValue in
                            let clamped = min(max(1.0, newValue), 10.0)
                            if clamped != newValue {
                                concurrentMoves = clamped
                            }
                            MoveQueueManager.setMaxConcurrentMoves(Int(clamped))
                        }
                }

                Text(L.Settings.Move.concurrentHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            concurrentMoves = Double(MoveQueueManager.getMaxConcurrentMoves())
        }
    }

    // MARK: - 主题设置区域

    @StateObject private var themeManager = ThemeManager.shared

    private var themeSection: some View {
        SettingsCard(title: L.Settings.Theme.title, icon: "paintbrush") {
            VStack(alignment: .leading, spacing: 12) {
                Picker(L.Settings.Theme.selectTheme, selection: $themeManager.selectedTheme) {
                    ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                        Label(theme.displayName, systemImage: theme.icon)
                            .tag(theme.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 语言设置区域

    private var languageSection: some View {
        SettingsCard(title: L.Settings.language, icon: "globe") {
            VStack(alignment: .leading, spacing: 12) {
                Picker(L.Settings.selectLanguage, selection: $languageManager.selectedLanguage) {
                    ForEach(languageManager.availableLanguages, id: \.code) { lang in
                        Text(lang.nativeName).tag(lang.code)
                    }
                }
                .pickerStyle(.menu)

                Text(L.Settings.languageHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 关于区域

    private var aboutSection: some View {
        SettingsCard(title: L.About.title, icon: "info.circle") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.Welcome.title)
                        .font(.headline)
                    Text(L.About.version("1.0.0"))
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
            messageManager.showSuccess(L.Message.Success.accountDeleted, description: L.Message.Success.accountDeletedDescription(account.displayName))
        } catch {
            messageManager.showError(L.Message.Error.deleteFailed, description: error.localizedDescription)
        }

        accountToDelete = nil
    }

    /// 重启应用
    private func restartApp() {
        // 使用 NSApp 重启应用
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        NSApp.terminate(nil)
    }
}

// MARK: - 账户行视图

struct AccountRowView: View {
    let account: R2Account
    let isConnected: Bool
    let onEdit: () -> Void
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
                        Text(L.Account.Status.bucketsCount(account.bucketNames.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !account.publicDomains.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(L.Account.Status.domainsCount(account.publicDomains.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // 连接状态标签
            if isConnected {
                Text(L.Common.Status.connected)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }

            // 操作按钮（hover时显示）
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .help(L.Help.editAccount)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(AppColors.destructive)
                    }
                    .buttonStyle(.plain)
                    .help(L.Help.deleteAccount)
                }
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

// MARK: - 编辑账户表单

struct EditAccountSheet: View {
    let account: R2Account
    @ObservedObject var accountManager: R2AccountManager
    @ObservedObject var r2Service: R2Service
    var messageManager: MessageManager
    let onDismiss: () -> Void

    @State private var displayName: String = ""
    @State private var accountID: String = ""
    @State private var accessKeyID: String = ""
    @State private var secretAccessKey: String = ""
    @State private var endpointURL: String = ""
    @State private var publicDomains: [String] = []
    @State private var newDomain: String = ""
    @State private var defaultDomainIndex: Int = 0
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    private var isFormValid: Bool {
        !accountID.trimmingCharacters(in: .whitespaces).isEmpty &&
        !accessKeyID.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(L.Common.Button.cancel) { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text(L.Account.Edit.title)
                    .font(.headline)
                Spacer()
                Button(L.Common.Button.save) { saveAccount() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaving || !isFormValid)
            }
            .padding()

            Divider()

            // Content
            Form {
                Section(L.Account.Add.accountInfo) {
                    TextField(L.Account.Field.accountID, text: $accountID)
                        .textContentType(.username)
                        .textFieldStyle(.roundedBorder)

                    TextField(L.Account.Field.accessKeyID, text: $accessKeyID)
                        .textContentType(.username)
                        .textFieldStyle(.roundedBorder)

                    SecureField(L.Account.Field.secretAccessKeyHint, text: $secretAccessKey)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)

                    TextField(L.Account.Field.displayName, text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }

                Section(L.Account.Add.endpoint) {
                    TextField(L.Account.Field.endpointURL, text: $endpointURL)
                        .textContentType(.URL)
                        .textFieldStyle(.roundedBorder)
                    Text(L.Account.Field.endpointHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(L.Account.Add.publicDomains) {
                    // 重要提示：缩略图功能说明
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.Account.Domain.featureHint)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(L.Account.Domain.configGuide)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    // 已添加的域名列表
                    if publicDomains.isEmpty {
                        Text(L.Account.Domain.empty)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(Array(publicDomains.enumerated()), id: \.offset) { index, domain in
                            HStack(spacing: 12) {
                                // 默认标记
                                Button {
                                    withAnimation { defaultDomainIndex = index }
                                } label: {
                                    Image(systemName: defaultDomainIndex == index ? "star.fill" : "star")
                                        .foregroundColor(defaultDomainIndex == index ? .yellow : .gray)
                                }
                                .buttonStyle(.borderless)
                                .help(defaultDomainIndex == index ? L.Account.Domain.isDefault : L.Account.Domain.setDefault)

                                Text(domain)
                                    .font(.system(.body, design: .monospaced))

                                Spacer()

                                // 删除按钮
                                Button {
                                    withAnimation { removeDomain(at: index) }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                                .help(L.Account.Domain.remove)
                            }
                        }
                    }

                    // 添加新域名
                    HStack(spacing: 8) {
                        TextField(L.Account.Domain.placeholder, text: $newDomain)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addDomain() }

                        Button(L.Common.Button.add) {
                            addDomain()
                        }
                        .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    }

                    Text(L.Account.Domain.defaultHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .disabled(isSaving)

            if isSaving {
                ProgressView(L.Account.Edit.saving)
                    .padding()
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            accountID = account.accountID
            accessKeyID = account.accessKeyID
            displayName = account.displayName
            endpointURL = account.endpointURL
            publicDomains = account.publicDomains
            defaultDomainIndex = account.defaultPublicDomainIndex
        }
    }

    private func addDomain() {
        let trimmed = newDomain.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !publicDomains.contains(trimmed) else { return }
        withAnimation {
            publicDomains.append(trimmed)
            if publicDomains.count == 1 {
                defaultDomainIndex = 0
            }
        }
        newDomain = ""
    }

    private func removeDomain(at index: Int) {
        publicDomains.remove(at: index)
        if defaultDomainIndex >= publicDomains.count {
            defaultDomainIndex = max(0, publicDomains.count - 1)
        }
    }

    private func saveAccount() {
        withAnimation(AppAnimations.standard) {
            isSaving = true
            saveError = nil
        }

        let trimmedAccountID = accountID.trimmingCharacters(in: .whitespaces)
        let trimmedAccessKeyID = accessKeyID.trimmingCharacters(in: .whitespaces)
        let trimmedSecretKey = secretAccessKey.trimmingCharacters(in: .whitespaces)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedEndpoint = endpointURL.trimmingCharacters(in: .whitespaces)

        let updatedAccount = account.updated(
            accountID: trimmedAccountID,
            accessKeyID: trimmedAccessKeyID,
            endpointURL: trimmedEndpoint.isEmpty ? nil : trimmedEndpoint,
            displayName: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName,
            publicDomains: publicDomains,
            defaultPublicDomainIndex: defaultDomainIndex
        )

        // 使用 Task 避免 Keychain 操作阻塞主线程
        Task {
            do {
                // 如果提供了新的 Secret Key，则更新
                if !trimmedSecretKey.isEmpty {
                    try accountManager.updateAccount(updatedAccount, secretAccessKey: trimmedSecretKey)
                } else {
                    try accountManager.updateAccount(updatedAccount)
                }

                // 如果是当前连接的账户，需要重新初始化
                if accountManager.currentAccount?.id == account.id {
                    if !trimmedSecretKey.isEmpty {
                        try? await r2Service.initialize(with: updatedAccount, secretAccessKey: trimmedSecretKey)
                    }
                }

                await MainActor.run {
                    withAnimation(AppAnimations.standard) {
                        isSaving = false
                    }
                    messageManager.showSuccess(L.Message.Success.accountSaved, description: L.Message.Success.accountSavedDescription(updatedAccount.displayName))
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    withAnimation(AppAnimations.standard) {
                        isSaving = false
                        saveError = error.localizedDescription
                    }
                }
            }
        }
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
