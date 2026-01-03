import SwiftUI

/// Sidebar View - Refactored for Native Design
struct SidebarView: View {
    @Binding var selectedView: ContentView.MainViewSelection?
    @ObservedObject var r2Service: R2Service
    @ObservedObject var accountManager: R2AccountManager
    @EnvironmentObject var messageManager: MessageManager
    
    // UI State
    @State private var expandedAccounts: Set<UUID> = []
    @State private var loadingBuckets: Set<UUID> = []

    // Disconnect Action
    @State private var showDisconnectConfirmation: Bool = false
    @State private var accountToDisconnect: R2Account?

    // Add Bucket Dialog
    @State private var showAddBucketDialog: Bool = false
    @State private var accountForNewBucket: R2Account?
    @State private var newBucketName: String = ""
    @State private var isValidatingBucket: Bool = false

    // Add Account Dialog
    @State private var showAddAccountDialog: Bool = false

    var body: some View {
        List(selection: $selectedView) {
            // MARK: - General
            Section(L.Sidebar.Section.general) {
                NavigationLink(value: ContentView.MainViewSelection.welcome) {
                    Label(L.Sidebar.Item.home, systemImage: "house")
                }

                NavigationLink(value: ContentView.MainViewSelection.settings) {
                    Label(L.Sidebar.Item.settings, systemImage: "gear")
                }
            }
            .collapsible(false)

            // MARK: - Accounts
            Section(L.Sidebar.Section.accounts) {
                ForEach(accountManager.accounts) { account in
                    AccountRow(
                        account: account,
                        isExpanded: expandedAccounts.contains(account.id),
                        loading: loadingBuckets.contains(account.id),
                        buckets: getBucketsForAccount(account),
                        isConnected: isAccountConnected(account),
                        selectedBucketName: r2Service.selectedBucket?.name,
                        onToggle: { toggleExpansion(for: account) },
                        onSelectBucket: { bucket in selectBucket(bucket, for: account) },
                        onAddBucket: { showAddBucketSheet(for: account) },
                        onRefresh: { /* buckets come from account.bucketNames */ },
                        onDisconnect: { confirmDisconnect(account) }
                    )
                }

                // 添加账户按钮 - 始终显示在底部
                Button {
                    showAddAccountDialog = true
                } label: {
                    Label(L.Sidebar.Action.addAccount, systemImage: "plus.circle")
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showAddBucketDialog) {
            addBucketSheet
        }
        .sheet(isPresented: $showAddAccountDialog) {
            AddAccountSheet(
                accountManager: accountManager,
                r2Service: r2Service,
                messageManager: messageManager,
                onDismiss: { showAddAccountDialog = false }
            )
        }
        .listStyle(.sidebar)
        .confirmationDialog(
            L.Alert.Disconnect.title,
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button(L.Sidebar.Action.disconnect, role: .destructive) {
                if let account = accountToDisconnect {
                    disconnectAccount(account)
                }
            }
            Button(L.Common.Button.cancel, role: .cancel) {}
        } message: {
            if let account = accountToDisconnect {
                Text(L.Alert.Disconnect.message(account.accessKeyID))
            }
        }
    }
    
    // MARK: - Views

    private var addBucketSheet: some View {
        VStack(spacing: 16) {
            Text(L.Bucket.Add.title)
                .font(.headline)

            TextField(L.Bucket.Add.namePlaceholder, text: $newBucketName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack(spacing: 12) {
                Button(L.Common.Button.cancel) {
                    closeAddBucketSheet()
                }
                .keyboardShortcut(.cancelAction)

                Button(L.Common.Button.add) {
                    addBucketToAccount()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newBucketName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidatingBucket)
            }

            if isValidatingBucket {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(24)
        .frame(minWidth: 300)
    }

    // MARK: - Logic

    private func toggleExpansion(for account: R2Account) {
        if expandedAccounts.contains(account.id) {
            expandedAccounts.remove(account.id)
        } else {
            expandedAccounts.insert(account.id)
        }
    }

    private func isAccountConnected(_ account: R2Account) -> Bool {
        return accountManager.currentAccount?.id == account.id && r2Service.isConnected
    }

    /// 从账户的 bucketNames 获取 BucketItem 列表
    private func getBucketsForAccount(_ account: R2Account) -> [BucketItem] {
        return account.bucketNames.map { name in
            BucketItem(name: name, creationDate: nil, owner: nil, region: "auto")
        }
    }

    private func showAddBucketSheet(for account: R2Account) {
        accountForNewBucket = account
        newBucketName = ""
        showAddBucketDialog = true
    }

    private func closeAddBucketSheet() {
        showAddBucketDialog = false
        accountForNewBucket = nil
        newBucketName = ""
        isValidatingBucket = false
    }

    private func addBucketToAccount() {
        guard let account = accountForNewBucket else { return }
        let bucketName = newBucketName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bucketName.isEmpty else { return }

        isValidatingBucket = true

        Task {
            do {
                // 验证存储桶是否可访问
                if accountManager.currentAccount?.id != account.id {
                    let credentials = try accountManager.getCompleteCredentials(for: account)
                    try await r2Service.initialize(with: credentials.account, secretAccessKey: credentials.secretAccessKey)
                    accountManager.setCurrentAccount(account)
                }

                // 尝试访问存储桶
                let _ = try await r2Service.selectBucketDirectly(bucketName)

                // 添加到账户
                try accountManager.addBucket(to: account, bucketName: bucketName)

                await MainActor.run {
                    closeAddBucketSheet()
                    messageManager.showSuccess(L.Message.Success.bucketAdded, description: L.Message.Success.bucketAddedDescription(bucketName))
                }
            } catch {
                await MainActor.run {
                    isValidatingBucket = false
                    messageManager.showError(L.Message.Error.connectionFailed, description: error.localizedDescription)
                }
            }
        }
    }
    
    private func selectBucket(_ bucket: BucketItem, for account: R2Account) {
        Task {
            do {
                if accountManager.currentAccount?.id != account.id {
                    let credentials = try accountManager.getCompleteCredentials(for: account)
                    try await r2Service.initialize(with: credentials.account, secretAccessKey: credentials.secretAccessKey)
                    accountManager.setCurrentAccount(account)
                }
                
                let _ = try await r2Service.selectBucketDirectly(bucket.name)
                
                await MainActor.run {
                    selectedView = .files
                    messageManager.showSuccess(L.Message.Success.connected, description: L.Message.Success.connectedDescription(bucket.name))
                }
            } catch {
                await MainActor.run {
                    messageManager.showError(L.Message.Error.connectionFailed, description: error.localizedDescription)
                }
            }
        }
    }
    
    private func confirmDisconnect(_ account: R2Account) {
        accountToDisconnect = account
        showDisconnectConfirmation = true
    }
    
    private func disconnectAccount(_ account: R2Account) {
        if accountManager.currentAccount?.id == account.id {
            r2Service.disconnect()
        }
        expandedAccounts.remove(account.id)
        messageManager.showSuccess(L.Message.Success.disconnected, description: L.Message.Info.accountDisconnected)
    }
}

// MARK: - Subcomponents

struct AccountRow: View {
    let account: R2Account
    let isExpanded: Bool
    let loading: Bool
    let buckets: [BucketItem]
    let isConnected: Bool
    let selectedBucketName: String?
    let onToggle: () -> Void
    let onSelectBucket: (BucketItem) -> Void
    let onAddBucket: () -> Void
    let onRefresh: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { _ in onToggle() }
            )
        ) {
            if loading {
                ProgressView().scaleEffect(0.5)
            } else {
                // 显示所有存储桶
                ForEach(buckets) { bucket in
                    BucketRowItem(
                        bucket: bucket,
                        isSelected: bucket.name == selectedBucketName,
                        action: { onSelectBucket(bucket) }
                    )
                }

                // 添加存储桶按钮 - 始终显示
                Button {
                    onAddBucket()
                } label: {
                    Label(L.Sidebar.Action.addBucket, systemImage: "plus")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
        } label: {
            HStack {
                Image(systemName: "cloud.fill")
                    .foregroundColor(isConnected ? AppColors.success : AppColors.textSecondary)
                Text(account.displayName.isEmpty ? account.accessKeyID : account.displayName)
                    .font(AppTypography.body)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Button {
                onAddBucket()
            } label: {
                Label(L.Sidebar.Action.addBucket, systemImage: "plus")
            }
            Divider()
            Button(L.Sidebar.Action.disconnect, role: .destructive, action: onDisconnect)
        }
    }
}

struct BucketRowItem: View {
    let bucket: BucketItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "cylinder.split.1x2.fill" : "cylinder.split.1x2")
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                Text(bucket.name)
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textPrimary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? AppColors.primary.opacity(0.1) : nil)
    }
}

// MARK: - Add Account Sheet

struct AddAccountSheet: View {
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
    @State private var isTesting: Bool = false
    @State private var testError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(L.Common.Button.cancel) { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text(L.Account.Add.title)
                    .font(.headline)
                Spacer()
                Button(L.Common.Button.add) { addAccount() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid || isTesting)
            }
            .padding()

            Divider()

            // Form
            ScrollView {
                Form {
                    Section(L.Account.Add.accountInfo) {
                        TextField(L.Account.Field.displayName, text: $displayName)
                        TextField(L.Account.Field.accountID, text: $accountID)
                            .textContentType(.username)
                    }

                    Section(L.Account.Add.credentials) {
                        TextField(L.Account.Field.accessKeyID, text: $accessKeyID)
                            .textContentType(.username)
                        SecureField(L.Account.Field.secretAccessKey, text: $secretAccessKey)
                            .textContentType(.password)
                    }

                    Section(L.Account.Add.endpoint) {
                        TextField(L.Account.Field.endpointURL, text: $endpointURL)
                            .textContentType(.URL)
                        Text(L.Account.Field.endpointHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section(L.Account.Add.publicDomains) {
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
                            .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        Text(L.Account.Domain.defaultHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let error = testError {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                .formStyle(.grouped)
                .disabled(isTesting)
            }

            if isTesting {
                ProgressView(L.Account.Add.testingConnection)
                    .padding()
            }
        }
        .frame(width: 500, height: 600)
    }

    private var isFormValid: Bool {
        !accountID.trimmingCharacters(in: .whitespaces).isEmpty &&
        !accessKeyID.trimmingCharacters(in: .whitespaces).isEmpty &&
        !secretAccessKey.trimmingCharacters(in: .whitespaces).isEmpty
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
        // 调整默认索引
        if defaultDomainIndex >= publicDomains.count {
            defaultDomainIndex = max(0, publicDomains.count - 1)
        }
    }

    private func addAccount() {
        withAnimation(AppAnimations.standard) {
            isTesting = true
            testError = nil
        }

        let trimmedAccountID = accountID.trimmingCharacters(in: .whitespaces)
        let trimmedAccessKeyID = accessKeyID.trimmingCharacters(in: .whitespaces)
        let trimmedSecretKey = secretAccessKey.trimmingCharacters(in: .whitespaces)
        let trimmedEndpoint = endpointURL.trimmingCharacters(in: .whitespaces)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)

        let account = R2Account(
            accountID: trimmedAccountID,
            accessKeyID: trimmedAccessKeyID,
            endpointURL: trimmedEndpoint.isEmpty ? nil : trimmedEndpoint,
            displayName: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName,
            bucketNames: [],
            publicDomains: publicDomains,
            defaultPublicDomainIndex: defaultDomainIndex
        )

        Task {
            do {
                // Test connection
                let testService = R2Service()
                try await testService.initialize(with: account, secretAccessKey: trimmedSecretKey)
                let success = try await testService.testConnection()

                if success {
                    // Save account
                    try accountManager.saveAccount(account, secretAccessKey: trimmedSecretKey)

                    // Initialize main service
                    try await r2Service.initialize(with: account, secretAccessKey: trimmedSecretKey)
                    accountManager.setCurrentAccount(account)

                    await MainActor.run {
                        withAnimation(AppAnimations.standard) {
                            isTesting = false
                        }
                        messageManager.showSuccess(L.Message.Success.accountAdded, description: L.Message.Success.accountAddedDescription(account.displayName))
                        onDismiss()
                    }
                } else {
                    await MainActor.run {
                        withAnimation(AppAnimations.standard) {
                            isTesting = false
                            testError = L.Message.Error.connectionTestFailed
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(AppAnimations.standard) {
                        isTesting = false
                        testError = error.localizedDescription
                    }
                }
            }
        }
    }
}
