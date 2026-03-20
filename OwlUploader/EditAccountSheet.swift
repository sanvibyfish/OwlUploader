//
//  EditAccountSheet.swift
//  OwlUploader
//
//  编辑账户表单 — 按供应商显示不同字段
//

import SwiftUI

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
    @State private var autoPurgeCDNCache: Bool = false
    @State private var cloudflareZoneID: String = ""
    @State private var cloudflareAPIToken: String = ""
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var credentialLoadWarning: String?

    private var isFormValid: Bool {
        let hasAccessKey = !accessKeyID.trimmingCharacters(in: .whitespaces).isEmpty

        switch account.provider {
        case .r2:
            return !accountID.trimmingCharacters(in: .whitespaces).isEmpty && hasAccessKey
        case .oss:
            return hasAccessKey
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                providerInfoSection
                credentialsSection
                endpointSection
                publicDomainsSection

                // CDN 缓存设置（仅 R2 显示）
                if account.provider.supportsCDNPurge {
                    cdnSection
                }

                if let warning = credentialLoadWarning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
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
            bottomBar
        }
        .frame(width: 450, height: 560)
        .onAppear { loadAccountData() }
    }

    // MARK: - Subviews

    private var providerInfoSection: some View {
        Group {
            Section {
                HStack {
                    Image(systemName: account.provider.iconName)
                    Text(account.provider.displayName)
                        .foregroundColor(.secondary)
                }
                TextField(L.Account.Field.displayName, text: $displayName)
            } header: {
                Text(L.Account.Add.accountInfo)
            }

            if account.provider == .r2 {
                Section {
                    TextField(L.Account.Field.accountID, text: $accountID)
                        .textContentType(.username)
                } header: {
                    Text("Cloudflare Account")
                }
            }

            if account.provider == .oss, let regionID = account.ossRegion {
                Section {
                    HStack {
                        Text(L.Account.Field.ossRegion)
                        Spacer()
                        let regionLabel = OSSRegion.allRegions.first { $0.id == regionID }?.displayName ?? regionID
                        Text(regionLabel)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(L.Account.Add.regionInfo)
                }
            }
        }
    }

    private var credentialsSection: some View {
        Section {
            TextField(L.Account.Field.accessKeyID, text: $accessKeyID)
            SecureField(L.Account.Field.secretAccessKey, text: $secretAccessKey)
        } header: {
            Text(L.Account.Add.credentials)
        }
    }

    private var endpointSection: some View {
        Section {
            TextField(L.Account.Field.endpointURL, text: $endpointURL)
                .textContentType(.URL)
        } header: {
            Text(L.Account.Add.endpoint)
        } footer: {
            Text(L.Account.Field.endpointHint)
        }
    }

    private var publicDomainsSection: some View {
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
                .onTapGesture { defaultDomainIndex = index }
            }

            HStack {
                TextField("", text: $newDomain, prompt: Text(L.Account.Domain.placeholder))
                    .onSubmit { addDomain() }
                Button { addDomain() } label: {
                    Image(systemName: "plus")
                }
                .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text(L.Account.Add.publicDomains)
        } footer: {
            Text(L.Account.Domain.hint)
        }
    }

    private var cdnSection: some View {
        Section {
            Toggle(L.Account.CDN.autoPurge, isOn: $autoPurgeCDNCache)

            if autoPurgeCDNCache {
                TextField(L.Account.CDN.zoneID, text: $cloudflareZoneID)
                    .textContentType(.none)
                SecureField(L.Account.CDN.apiToken, text: $cloudflareAPIToken)
            }
        } header: {
            Text(L.Account.CDN.title)
        } footer: {
            Text(L.Account.CDN.hint)
        }
    }

    private var bottomBar: some View {
        HStack {
            if isSaving {
                ProgressView()
                    .scaleEffect(0.7)
                Text(L.Account.Edit.saving)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(L.Common.Button.cancel) { onDismiss() }
                .keyboardShortcut(.cancelAction)

            Button(L.Common.Button.save) { saveAccount() }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid || isSaving)
        }
        .padding()
    }

    // MARK: - Data Loading

    private func loadAccountData() {
        accountID = account.accountID
        accessKeyID = account.accessKeyID
        displayName = account.displayName
        endpointURL = account.endpointURL
        publicDomains = account.publicDomains
        defaultDomainIndex = account.defaultPublicDomainIndex

        autoPurgeCDNCache = account.autoPurgeCDNCache
        cloudflareZoneID = account.cloudflareZoneID ?? ""

        do {
            let credentials = try accountManager.getCompleteCredentials(for: account)
            secretAccessKey = credentials.secretAccessKey
        } catch {
            credentialLoadWarning = error.localizedDescription
        }

        if account.provider.supportsCDNPurge {
            if let token = KeychainService.shared.retrieveCloudflareAPIToken(for: account) {
                cloudflareAPIToken = token
            }
        }
    }

    // MARK: - Actions

    private func addDomain() {
        let trimmed = newDomain.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !publicDomains.contains(trimmed) else { return }
        publicDomains.append(trimmed)
        if publicDomains.count == 1 { defaultDomainIndex = 0 }
        newDomain = ""
    }

    private func saveAccount() {
        withAnimation { isSaving = true; saveError = nil }

        let pendingDomain = newDomain.trimmingCharacters(in: .whitespaces)
        if !pendingDomain.isEmpty, !publicDomains.contains(pendingDomain) {
            publicDomains.append(pendingDomain)
            if publicDomains.count == 1 { defaultDomainIndex = 0 }
            newDomain = ""
        }

        let trimmedAccountID = accountID.trimmingCharacters(in: .whitespaces)
        let trimmedAccessKeyID = accessKeyID.trimmingCharacters(in: .whitespaces)
        let trimmedSecretKey = secretAccessKey.trimmingCharacters(in: .whitespaces)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedEndpoint = endpointURL.trimmingCharacters(in: .whitespaces)
        let trimmedZoneID = cloudflareZoneID.trimmingCharacters(in: .whitespaces)
        let trimmedAPIToken = cloudflareAPIToken.trimmingCharacters(in: .whitespaces)

        let updatedAccount = account.updated(
            accountID: trimmedAccountID,
            accessKeyID: trimmedAccessKeyID,
            endpointURL: trimmedEndpoint.isEmpty ? nil : trimmedEndpoint,
            displayName: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName,
            publicDomains: publicDomains,
            defaultPublicDomainIndex: defaultDomainIndex,
            cloudflareZoneID: trimmedZoneID.isEmpty ? nil : trimmedZoneID,
            autoPurgeCDNCache: autoPurgeCDNCache
        )

        Task {
            do {
                if !trimmedSecretKey.isEmpty {
                    try accountManager.updateAccount(updatedAccount, secretAccessKey: trimmedSecretKey)
                } else {
                    try accountManager.updateAccount(updatedAccount)
                }

                if account.provider.supportsCDNPurge {
                    if !trimmedAPIToken.isEmpty {
                        try KeychainService.shared.updateCloudflareAPIToken(trimmedAPIToken, for: updatedAccount)
                    } else {
                        try KeychainService.shared.deleteCloudflareAPIToken(for: updatedAccount)
                    }
                }

                if accountManager.currentAccount?.id == account.id {
                    if !trimmedSecretKey.isEmpty {
                        try? await r2Service.initialize(with: updatedAccount, secretAccessKey: trimmedSecretKey)
                    } else {
                        r2Service.updateCurrentAccount(updatedAccount)
                    }
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
