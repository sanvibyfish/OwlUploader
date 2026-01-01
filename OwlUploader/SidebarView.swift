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
            Section("General") {
                NavigationLink(value: ContentView.MainViewSelection.welcome) {
                    Label("Home", systemImage: "house")
                }

                NavigationLink(value: ContentView.MainViewSelection.settings) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .collapsible(false)

            // MARK: - Accounts
            Section("Accounts") {
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
                    Label("Add Account...", systemImage: "plus.circle")
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
            "Disconnect Account",
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                if let account = accountToDisconnect {
                    disconnectAccount(account)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let account = accountToDisconnect {
                Text("Are you sure you want to disconnect '\(account.accessKeyID)'?")
            }
        }
    }
    
    // MARK: - Views

    private var addBucketSheet: some View {
        VStack(spacing: 16) {
            Text("Add Bucket")
                .font(.headline)

            TextField("Bucket Name", text: $newBucketName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack(spacing: 12) {
                Button("Cancel") {
                    closeAddBucketSheet()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
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
                    messageManager.showSuccess("Bucket Added", description: "'\(bucketName)' added successfully")
                }
            } catch {
                await MainActor.run {
                    isValidatingBucket = false
                    messageManager.showError("Failed to Add Bucket", description: error.localizedDescription)
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
                    messageManager.showSuccess("Connected", description: "Connected to '\(bucket.name)'")
                }
            } catch {
                await MainActor.run {
                    messageManager.showError("Connection Failed", description: error.localizedDescription)
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
        messageManager.showSuccess("Disconnected", description: "Account disconnected")
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
                    Label("Add Bucket...", systemImage: "plus")
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
                Label("Add Bucket...", systemImage: "plus")
            }
            Divider()
            Button("Disconnect", role: .destructive, action: onDisconnect)
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
    @State private var isTesting: Bool = false
    @State private var testError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text("Add Account")
                    .font(.headline)
                Spacer()
                Button("Add") { addAccount() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid || isTesting)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Account Info") {
                    TextField("Display Name", text: $displayName)
                    TextField("Account ID", text: $accountID)
                        .textContentType(.username)
                }

                Section("Credentials") {
                    TextField("Access Key ID", text: $accessKeyID)
                        .textContentType(.username)
                    SecureField("Secret Access Key", text: $secretAccessKey)
                        .textContentType(.password)
                }

                Section("Endpoint") {
                    TextField("Endpoint URL", text: $endpointURL)
                        .textContentType(.URL)
                    Text("Leave empty to use default: https://{accountID}.r2.cloudflarestorage.com")
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

            if isTesting {
                ProgressView("Testing connection...")
                    .padding()
            }
        }
        .frame(width: 450, height: 480)
    }

    private var isFormValid: Bool {
        !accountID.trimmingCharacters(in: .whitespaces).isEmpty &&
        !accessKeyID.trimmingCharacters(in: .whitespaces).isEmpty &&
        !secretAccessKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func addAccount() {
        isTesting = true
        testError = nil

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
            bucketNames: []
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
                        messageManager.showSuccess("Account Added", description: "'\(account.displayName)' connected successfully")
                        onDismiss()
                    }
                } else {
                    await MainActor.run {
                        isTesting = false
                        testError = "Connection test failed"
                    }
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testError = error.localizedDescription
                }
            }
        }
    }
}
