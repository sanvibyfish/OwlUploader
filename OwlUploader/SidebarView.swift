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
    @State private var accountBuckets: [UUID: [BucketItem]] = [:]
    
    // Disconnect Action
    @State private var showDisconnectConfirmation: Bool = false
    @State private var accountToDisconnect: R2Account?
    
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
                if accountManager.accounts.isEmpty {
                    emptyAccountsView
                } else {
                    ForEach(accountManager.accounts) { account in
                        AccountRow(
                            account: account,
                            isExpanded: expandedAccounts.contains(account.id),
                            loading: loadingBuckets.contains(account.id),
                            buckets: accountBuckets[account.id] ?? [],
                            isConnected: isAccountConnected(account),
                            selectedBucketName: r2Service.selectedBucket?.name,
                            onToggle: { toggleExpansion(for: account) },
                            onSelectBucket: { bucket in selectBucket(bucket, for: account) },
                            onRefresh: { loadBucketsForAccount(account, forceRefresh: true) },
                            onDisconnect: { confirmDisconnect(account) }
                        )
                    }
                }
            }
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
    
    private var emptyAccountsView: some View {
        Button {
            selectedView = .settings
        } label: {
            Label("Add Account", systemImage: "plus.circle")
                .foregroundColor(AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Logic
    
    private func toggleExpansion(for account: R2Account) {
        if expandedAccounts.contains(account.id) {
            expandedAccounts.remove(account.id)
        } else {
            expandedAccounts.insert(account.id)
            loadBucketsForAccount(account)
        }
    }
    
    private func isAccountConnected(_ account: R2Account) -> Bool {
        return accountManager.currentAccount?.id == account.id && r2Service.isConnected
    }
    
    private func loadBucketsForAccount(_ account: R2Account, forceRefresh: Bool = false) {
        if !forceRefresh, accountBuckets[account.id] != nil { return }
        
        // Mock loading/logic as per original file (R2 listBuckets limitation workaround)
        if let defaultBucket = account.defaultBucketName, !defaultBucket.isEmpty {
            let bucket = BucketItem(name: defaultBucket, creationDate: nil, owner: nil, region: "auto")
            accountBuckets[account.id] = [bucket]
        } else {
            accountBuckets[account.id] = []
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
        accountBuckets.removeValue(forKey: account.id)
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
            } else if buckets.isEmpty {
                Text("No buckets found")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.leading)
            } else {
                ForEach(buckets) { bucket in
                    BucketRowItem(
                        bucket: bucket,
                        isSelected: bucket.name == selectedBucketName,
                        action: { onSelectBucket(bucket) }
                    )
                }
            }
        } label: {
            HStack {
                Image(systemName: "cloud.fill")
                    .foregroundColor(isConnected ? AppColors.success : AppColors.textSecondary)
                Text(account.accessKeyID)
                    .font(AppTypography.body)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Button("Refresh", action: onRefresh)
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
        .buttonStyle(.plain) // Important for List
        .listRowBackground(isSelected ? AppColors.primary.opacity(0.1) : nil)
    }
}
