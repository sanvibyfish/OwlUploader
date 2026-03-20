//
//  AddAccountSheet.swift
//  OwlUploader
//
//  添加账户表单 — 支持多云供应商（R2 / OSS）
//

import SwiftUI

struct AddAccountSheet: View {
    @ObservedObject var accountManager: R2AccountManager
    @ObservedObject var r2Service: R2Service
    var messageManager: MessageManager
    let onDismiss: () -> Void

    // 供应商选择
    @State private var selectedProvider: CloudProvider = .r2

    // 通用字段
    @State private var displayName: String = ""
    @State private var accessKeyID: String = ""
    @State private var secretAccessKey: String = ""
    @State private var endpointURL: String = ""
    @State private var publicDomains: [String] = []
    @State private var newDomain: String = ""
    @State private var defaultDomainIndex: Int = 0

    // R2 特有字段
    @State private var accountID: String = ""

    // OSS 特有字段
    @State private var selectedOSSRegion: OSSRegion = OSSRegion.allRegions.first!

    @State private var isTesting: Bool = false
    @State private var testError: String?
    @State private var testTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // 供应商选择
                Section {
                    Picker(L.Account.Field.provider, selection: $selectedProvider) {
                        ForEach(CloudProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField(L.Account.Field.displayName, text: $displayName)
                } header: {
                    Text(L.Account.Add.accountInfo)
                }

                // R2 特有：Account ID
                if selectedProvider == .r2 {
                    Section {
                        TextField(L.Account.Field.accountID, text: $accountID)
                            .textContentType(.username)
                    } header: {
                        Text(L.Account.Add.cloudflareAccountSection)
                    }
                }

                // OSS 特有：Region 选择
                if selectedProvider == .oss {
                    Section {
                        Picker(L.Account.Field.ossRegion, selection: $selectedOSSRegion) {
                            ForEach(OSSRegion.allRegions) { region in
                                Text("\(region.displayName) (\(region.id))").tag(region)
                            }
                        }
                    } header: {
                        Text(L.Account.Add.regionInfo)
                    }
                }

                // 凭证（通用）
                Section {
                    TextField(L.Account.Field.accessKeyID, text: $accessKeyID)
                    SecureField(L.Account.Field.secretAccessKey, text: $secretAccessKey)
                } header: {
                    Text(L.Account.Add.credentials)
                }

                // 端点（通用，可选覆盖）
                Section {
                    TextField(L.Account.Field.endpointURL, text: $endpointURL, prompt: Text(endpointPlaceholder))
                        .textContentType(.URL)
                } header: {
                    Text(L.Account.Add.endpoint)
                } footer: {
                    Text(endpointHint)
                }

                // 公共域名（通用）
                publicDomainsSection

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
                    testTask?.cancel()
                    testTask = nil
                    onDismiss()
                }
                    .keyboardShortcut(.cancelAction)

                Button(L.Common.Button.add) { addAccount() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid || isTesting)
            }
            .padding()
        }
        .frame(width: 450, height: 560)
    }

    // MARK: - Subviews

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

    // MARK: - Computed

    private var endpointPlaceholder: String {
        switch selectedProvider {
        case .r2:
            return "https://<account-id>.r2.cloudflarestorage.com"
        case .oss:
            return "https://oss-\(selectedOSSRegion.id).aliyuncs.com"
        }
    }

    private var endpointHint: String {
        switch selectedProvider {
        case .r2:
            return L.Account.Field.endpointHint
        case .oss:
            return L.Account.Field.ossEndpointHint
        }
    }

    private var isFormValid: Bool {
        let hasAccessKey = !accessKeyID.trimmingCharacters(in: .whitespaces).isEmpty
        let hasSecretKey = !secretAccessKey.trimmingCharacters(in: .whitespaces).isEmpty

        switch selectedProvider {
        case .r2:
            return !accountID.trimmingCharacters(in: .whitespaces).isEmpty && hasAccessKey && hasSecretKey
        case .oss:
            return hasAccessKey && hasSecretKey
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

    private func addAccount() {
        withAnimation(AppAnimations.standard) {
            isTesting = true
            testError = nil
        }

        let pendingDomain = newDomain.trimmingCharacters(in: .whitespaces)
        if !pendingDomain.isEmpty, !publicDomains.contains(pendingDomain) {
            publicDomains.append(pendingDomain)
            if publicDomains.count == 1 { defaultDomainIndex = 0 }
            newDomain = ""
        }

        let trimmedAccessKeyID = accessKeyID.trimmingCharacters(in: .whitespaces)
        let trimmedSecretKey = secretAccessKey.trimmingCharacters(in: .whitespaces)
        let trimmedEndpoint = endpointURL.trimmingCharacters(in: .whitespaces)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)

        let account: R2Account
        switch selectedProvider {
        case .r2:
            let trimmedAccountID = accountID.trimmingCharacters(in: .whitespaces)
            account = R2Account(
                provider: .r2,
                accountID: trimmedAccountID,
                accessKeyID: trimmedAccessKeyID,
                endpointURL: trimmedEndpoint.isEmpty ? nil : trimmedEndpoint,
                displayName: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName,
                publicDomains: publicDomains,
                defaultPublicDomainIndex: defaultDomainIndex
            )
        case .oss:
            account = R2Account(
                provider: .oss,
                accessKeyID: trimmedAccessKeyID,
                endpointURL: trimmedEndpoint.isEmpty ? nil : trimmedEndpoint,
                displayName: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName,
                ossRegion: selectedOSSRegion.id,
                publicDomains: publicDomains,
                defaultPublicDomainIndex: defaultDomainIndex
            )
        }

        testTask = Task {
            do {
                let testService = R2Service()
                try await testService.initialize(with: account, secretAccessKey: trimmedSecretKey)
                try Task.checkCancellation()
                let success = try await testService.testConnection()

                if Task.isCancelled { return }

                if success {
                    try accountManager.saveAccount(account, secretAccessKey: trimmedSecretKey)
                    try await r2Service.initialize(with: account, secretAccessKey: trimmedSecretKey)
                    accountManager.setCurrentAccount(account)

                    await MainActor.run {
                        withAnimation(AppAnimations.standard) { isTesting = false }
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
            } catch is CancellationError {
                // 用户取消，不做额外处理
            } catch {
                if Task.isCancelled { return }
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
