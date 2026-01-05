//
//  AccountSettingsView.swift
//  OwlUploader
//
//  设置页面 - macOS 原生 TabView 风格
//

import SwiftUI

// MARK: - 设置视图

struct AccountSettingsView: View {
    @EnvironmentObject var accountManager: R2AccountManager
    @EnvironmentObject var r2Service: R2Service
    @EnvironmentObject var messageManager: MessageManager

    @State private var accountToDelete: R2Account?
    @State private var showDeleteConfirmation: Bool = false
    @State private var showAddAccountSheet: Bool = false
    @State private var accountToEdit: R2Account?
    @State private var showRestartAlert: Bool = false

    var body: some View {
        TabView {
            // 账户标签页
            AccountsTabView(
                accountManager: accountManager,
                r2Service: r2Service,
                showAddAccountSheet: $showAddAccountSheet,
                accountToEdit: $accountToEdit,
                accountToDelete: $accountToDelete,
                showDeleteConfirmation: $showDeleteConfirmation
            )
            .tabItem {
                Label(L.Account.Settings.sectionTitle, systemImage: "person.crop.circle")
            }

            // 通用设置标签页
            GeneralTabView(showRestartAlert: $showRestartAlert)
                .tabItem {
                    Label(L.Settings.General.title, systemImage: "gearshape")
                }

            // 关于标签页
            AboutTabView()
                .tabItem {
                    Label(L.About.title, systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
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
                onDismiss: { accountToEdit = nil }
            )
        }
        .alert(L.Account.Delete.title, isPresented: $showDeleteConfirmation) {
            Button(L.Common.Button.cancel, role: .cancel) { accountToDelete = nil }
            Button(L.Common.Button.delete, role: .destructive) {
                if let account = accountToDelete { deleteAccount(account) }
            }
        } message: {
            if let account = accountToDelete {
                Text(L.Account.Delete.confirmation(account.displayName))
            }
        }
        .alert(L.Settings.Restart.title, isPresented: $showRestartAlert) {
            Button(L.Settings.Restart.restartNow) { restartApp() }
            Button(L.Settings.Restart.later, role: .cancel) { }
        } message: {
            Text(L.Settings.Restart.message)
        }
    }

    private func deleteAccount(_ account: R2Account) {
        if accountManager.currentAccount?.id == account.id {
            r2Service.disconnect()
        }
        do {
            try accountManager.deleteAccount(account)
            messageManager.showSuccess(
                L.Message.Success.accountDeleted,
                description: L.Message.Success.accountDeletedDescription(account.displayName)
            )
        } catch {
            messageManager.showError(L.Message.Error.deleteFailed, description: error.localizedDescription)
        }
        accountToDelete = nil
    }

    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        NSApp.terminate(nil)
    }
}

// MARK: - 账户标签页

struct AccountsTabView: View {
    @ObservedObject var accountManager: R2AccountManager
    @ObservedObject var r2Service: R2Service
    @Binding var showAddAccountSheet: Bool
    @Binding var accountToEdit: R2Account?
    @Binding var accountToDelete: R2Account?
    @Binding var showDeleteConfirmation: Bool

    var body: some View {
        Form {
            Section {
                ForEach(accountManager.accounts) { account in
                    HStack {
                        // 账户信息
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName)
                            Text(account.accessKeyID)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // 连接状态
                        if accountManager.currentAccount?.id == account.id && r2Service.isConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }

                        // 编辑按钮
                        Button {
                            accountToEdit = account
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)

                        // 删除按钮
                        Button {
                            accountToDelete = account
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }

                // 添加账户按钮
                Button {
                    showAddAccountSheet = true
                } label: {
                    Label(L.Sidebar.Action.addAccount, systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 通用设置标签页

struct GeneralTabView: View {
    @Binding var showRestartAlert: Bool

    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var concurrentUploads: Double = Double(UploadQueueManager.getMaxConcurrentUploads())
    @State private var concurrentMoves: Double = Double(MoveQueueManager.getMaxConcurrentMoves())
    @State private var conflictResolution: ConflictResolution = MoveQueueManager.getConflictResolution()
    @State private var renamePattern: RenamePattern = MoveQueueManager.getRenamePattern()
    @State private var customPatternString: String = MoveQueueManager.getCustomPatternString()
    @State private var previousLanguage: String = ""

    var body: some View {
        Form {
            // 外观设置
            Section {
                Picker(L.Settings.Theme.selectTheme, selection: $themeManager.selectedTheme) {
                    ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                        Label(theme.displayName, systemImage: theme.icon)
                            .tag(theme.rawValue)
                    }
                }

                Picker(L.Settings.selectLanguage, selection: $languageManager.selectedLanguage) {
                    ForEach(languageManager.availableLanguages, id: \.code) { lang in
                        Text(lang.nativeName).tag(lang.code)
                    }
                }
            } header: {
                Text(L.Settings.Theme.title)
            } footer: {
                Text(L.Settings.languageHint)
            }

            // 上传设置
            Section {
                Stepper(value: $concurrentUploads, in: 1...50, step: 1) {
                    HStack {
                        Text(L.Settings.Upload.concurrentUploads)
                        Spacer()
                        Text("\(Int(concurrentUploads))")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .onChange(of: concurrentUploads) { _, newValue in
                    UploadQueueManager.setMaxConcurrentUploads(Int(newValue))
                }
            } header: {
                Text(L.Settings.Upload.title)
            } footer: {
                Text(L.Settings.Upload.concurrentHint)
            }

            // 移动设置
            Section {
                Stepper(value: $concurrentMoves, in: 1...10, step: 1) {
                    HStack {
                        Text(L.Settings.Move.concurrentMoves)
                        Spacer()
                        Text("\(Int(concurrentMoves))")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .onChange(of: concurrentMoves) { _, newValue in
                    MoveQueueManager.setMaxConcurrentMoves(Int(newValue))
                }

                // 冲突解决策略
                Picker(L.Move.ConflictResolution.title, selection: $conflictResolution) {
                    Text(L.Move.ConflictResolution.skip).tag(ConflictResolution.skip)
                    Text(L.Move.ConflictResolution.rename).tag(ConflictResolution.rename)
                    Text(L.Move.ConflictResolution.replace).tag(ConflictResolution.replace)
                }
                .onChange(of: conflictResolution) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "moveConflictResolution")
                }

                // 重命名模式（仅在选择 rename 时显示）
                if conflictResolution == .rename {
                    Picker(L.Move.ConflictResolution.patternTitle, selection: $renamePattern) {
                        ForEach(RenamePattern.allCases) { pattern in
                            if pattern == .custom {
                                Text(pattern.displayName).tag(pattern)
                            } else {
                                Text(pattern.displayName).tag(pattern)
                            }
                        }
                    }
                    .onChange(of: renamePattern) { _, newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: "moveRenamePattern")
                    }

                    // 自定义模式输入（仅在选择 custom 时显示）
                    if renamePattern == .custom {
                        HStack {
                            TextField(L.Move.ConflictResolution.customPlaceholder, text: $customPatternString)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: customPatternString) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "moveCustomPattern")
                                }

                            // 预览
                            Text(renamePattern.preview(customPattern: customPatternString))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text(L.Settings.Move.title)
            } footer: {
                if conflictResolution == .rename && renamePattern == .custom {
                    Text(L.Move.ConflictResolution.patternHint)
                } else {
                    Text(L.Settings.Move.concurrentHint)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L.Settings.General.title)
        .onAppear {
            concurrentUploads = Double(UploadQueueManager.getMaxConcurrentUploads())
            concurrentMoves = Double(MoveQueueManager.getMaxConcurrentMoves())
            conflictResolution = MoveQueueManager.getConflictResolution()
            renamePattern = MoveQueueManager.getRenamePattern()
            customPatternString = MoveQueueManager.getCustomPatternString()
            previousLanguage = languageManager.selectedLanguage
        }
        .onChange(of: languageManager.selectedLanguage) { oldValue, newValue in
            if oldValue != newValue && !oldValue.isEmpty {
                showRestartAlert = true
            }
            previousLanguage = newValue
        }
    }
}

// MARK: - 关于标签页

struct AboutTabView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 应用图标
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }

            Spacer().frame(height: 16)

            Text(L.Welcome.title)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer().frame(height: 4)

            Text(L.About.version(appVersion))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer().frame(height: 24)

            Text(L.Welcome.subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Spacer()

            Text(L.About.copyright)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(L.About.title)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
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
            Form {
                Section {
                    TextField(L.Account.Field.displayName, text: $displayName)
                    TextField(L.Account.Field.accountID, text: $accountID)
                        .textContentType(.username)
                } header: {
                    Text(L.Account.Add.accountInfo)
                }

                Section {
                    TextField(L.Account.Field.accessKeyID, text: $accessKeyID)
                    SecureField(L.Account.Field.secretAccessKey, text: $secretAccessKey)
                } header: {
                    Text(L.Account.Add.credentials)
                }

                Section {
                    TextField(L.Account.Field.endpointURL, text: $endpointURL)
                        .textContentType(.URL)
                } header: {
                    Text(L.Account.Add.endpoint)
                } footer: {
                    Text(L.Account.Field.endpointHint)
                }

                Section {
                    ForEach(Array(publicDomains.enumerated()), id: \.offset) { index, domain in
                        HStack {
                            Text(domain)
                            Spacer()
                            if defaultDomainIndex == index {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                            Button {
                                publicDomains.remove(at: index)
                                if defaultDomainIndex >= publicDomains.count {
                                    defaultDomainIndex = max(0, publicDomains.count - 1)
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            defaultDomainIndex = index
                        }
                    }

                    HStack {
                        TextField(L.Account.Domain.placeholder, text: $newDomain)
                            .onSubmit { addDomain() }
                        Button {
                            addDomain()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text(L.Account.Add.publicDomains)
                } footer: {
                    Text(L.Account.Domain.hint)
                }

                if let error = saveError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .disabled(isSaving)

            Divider()

            // 底部按钮栏 - macOS 标准布局
            HStack {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(L.Account.Edit.saving)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(L.Common.Button.cancel) {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L.Common.Button.save) {
                    saveAccount()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid || isSaving)
            }
            .padding()
        }
        .frame(width: 450, height: 480)
        .onAppear {
            accountID = account.accountID
            accessKeyID = account.accessKeyID
            displayName = account.displayName
            endpointURL = account.endpointURL
            publicDomains = account.publicDomains
            defaultDomainIndex = account.defaultPublicDomainIndex

            // 从 Keychain 加载 Secret Access Key
            if let credentials = try? accountManager.getCompleteCredentials(for: account) {
                secretAccessKey = credentials.secretAccessKey
            }
        }
    }

    private func addDomain() {
        let trimmed = newDomain.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !publicDomains.contains(trimmed) else { return }
        publicDomains.append(trimmed)
        if publicDomains.count == 1 {
            defaultDomainIndex = 0
        }
        newDomain = ""
    }

    private func saveAccount() {
        withAnimation { isSaving = true; saveError = nil }

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

        Task {
            do {
                if !trimmedSecretKey.isEmpty {
                    try accountManager.updateAccount(updatedAccount, secretAccessKey: trimmedSecretKey)
                } else {
                    try accountManager.updateAccount(updatedAccount)
                }

                if accountManager.currentAccount?.id == account.id && !trimmedSecretKey.isEmpty {
                    try? await r2Service.initialize(with: updatedAccount, secretAccessKey: trimmedSecretKey)
                }

                await MainActor.run {
                    withAnimation { isSaving = false }
                    messageManager.showSuccess(
                        L.Message.Success.accountSaved,
                        description: L.Message.Success.accountSavedDescription(updatedAccount.displayName)
                    )
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    withAnimation { isSaving = false; saveError = error.localizedDescription }
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
}
