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
            // MARK: - Accounts
            Section {
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
            } header: {
                Text(L.Sidebar.Section.accounts.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddAccountDialog = true }) {
                    Image(systemName: "plus")
                }
                .help(L.Sidebar.Action.addAccount)
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
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedAccounts.contains(account.id) {
                expandedAccounts.remove(account.id)
            } else {
                expandedAccounts.insert(account.id)
            }
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
                
                // 1. Optimistically update UI
                await MainActor.run {
                    selectedView = .files
                    r2Service.selectBucket(bucket)
                }
                
                // 2. Then perform the actual verification/connection
                let _ = try await r2Service.selectBucketDirectly(bucket.name)
                
                await MainActor.run {
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
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(buckets) { bucket in
                    let isSelected = bucket.name == selectedBucketName
                    Button(action: { onSelectBucket(bucket) }) {
                        HStack {
                            Image(systemName: "cylinder.split.1x2")
                                .font(.system(size: 16))
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                            Text(bucket.name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        } label: {
            Label {
                Text(account.displayName.isEmpty ? account.accessKeyID : account.displayName)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isConnected ? AppColors.success : .secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onToggle()
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

                if let error = testError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .disabled(isTesting)

            Divider()

            // 底部按钮栏 - macOS 标准布局
            HStack {
                if isTesting {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(L.Account.Add.testingConnection)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(L.Common.Button.cancel) {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L.Common.Button.add) {
                    addAccount()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid || isTesting)
            }
            .padding()
        }
        .frame(width: 450, height: 520)
    }

    private var isFormValid: Bool {
        !accountID.trimmingCharacters(in: .whitespaces).isEmpty &&
        !accessKeyID.trimmingCharacters(in: .whitespaces).isEmpty &&
        !secretAccessKey.trimmingCharacters(in: .whitespaces).isEmpty
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
