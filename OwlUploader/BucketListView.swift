import SwiftUI

/// 存储桶选择视图
/// 允许用户手动输入存储桶名称进行连接，或显示已选择的存储桶状态
struct BucketListView: View {
    /// R2 服务实例
    @ObservedObject var r2Service: R2Service
    
    /// 消息管理器
    @EnvironmentObject var messageManager: MessageManager
    
    /// 账户管理器
    @EnvironmentObject var accountManager: R2AccountManager
    
    /// 存储桶名称输入
    @State private var bucketName: String = ""
    
    /// 是否正在连接
    @State private var isConnecting: Bool = false
    
    /// 是否需要手动输入（当默认存储桶连接失败或未配置时）
    @State private var needsManualInput: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部状态栏
            topStatusBar
            
            Divider()
            
            // 主内容区域
            mainContent
        }
        .navigationTitle(L.Bucket.Select.title)
        .onAppear {
            handleViewAppear()
        }
    }
    
    // MARK: - 子视图
    
    /// 顶部状态栏
    private var topStatusBar: some View {
        HStack {
            // 连接状态指示器
            HStack(spacing: 8) {
                Circle()
                    .fill(r2Service.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(r2Service.isConnected ? L.Common.Status.connected : L.Common.Status.notConnected)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 选中状态
            if let selectedBucket = r2Service.selectedBucket {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text(L.Bucket.Status.selected(selectedBucket.name))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    /// 主内容区域
    @ViewBuilder
    private var mainContent: some View {
        if !r2Service.isConnected {
            notConnectedView
        } else if let selectedBucket = r2Service.selectedBucket {
            bucketSelectedView(selectedBucket)
        } else if isConnecting {
            connectingView
        } else if needsManualInput {
            bucketInputView
        } else {
            // 尝试自动连接默认存储桶
            autoConnectView
        }
    }
    
    /// 未连接状态视图
    private var notConnectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(L.Files.State.notConnectedToR2)
                    .font(.headline)

                Text(L.Files.State.configureAccountPrompt)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 存储桶已选择状态视图
    private func bucketSelectedView(_ bucket: BucketItem) -> some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 成功图标和信息
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                
                Text(L.Bucket.Select.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L.Welcome.Status.currentBucket(bucket.name))
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            // 操作按钮
            VStack(spacing: 12) {
                Button(L.Bucket.Action.enterFiles) {
                    // 这里可以触发导航到文件管理页面
                    // 或者发送通知让父视图处理导航
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(L.Bucket.Action.switchBucket) {
                    clearAndShowInput()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
    }
    
    /// 正在连接视图
    private var connectingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(L.Bucket.Select.connecting)
                .font(.headline)
                .foregroundColor(.secondary)
            
            if let defaultBucket = accountManager.currentAccount?.defaultBucketName {
                Text(L.Bucket.Action.attemptingConnection(defaultBucket))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 自动连接视图（检查是否有默认存储桶配置）
    private var autoConnectView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(L.Common.Label.loading)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task {
                await attemptAutoConnect()
            }
        }
    }
    
    /// 存储桶输入视图
    private var bucketInputView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 标题和说明
            VStack(spacing: 16) {
                Image(systemName: "externaldrive")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text(L.Bucket.Select.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L.Bucket.Select.prompt)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 输入区域
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.Bucket.Select.nameLabel)
                        .font(.headline)

                    TextField(L.Bucket.Add.namePlaceholder, text: $bucketName)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .disabled(isConnecting)
                    
                    Text(L.Bucket.Select.nameHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: 400)
                
                // 连接按钮
                Button(action: {
                    connectToBucket()
                }) {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 4)
                        }
                        
                        Text(isConnecting ? L.Bucket.Select.connecting : L.Bucket.Select.connectButton)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(bucketName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
            }
            
            // 提示信息
            VStack(spacing: 12) {
                Divider()
                    .frame(maxWidth: 300)
                
                VStack(spacing: 8) {
                    Text(L.Bucket.Tips.title)
                        .font(.headline)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• " + L.Bucket.Tips.tip1)
                        Text("• " + L.Bucket.Tips.tip2)
                        Text("• " + L.Bucket.Tips.tip3)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 350, alignment: .leading)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - 私有方法
    
    /// 处理视图出现
    private func handleViewAppear() {
        // 如果已经有选中的存储桶，填入名称（以防用户想要修改）
        if let selectedBucket = r2Service.selectedBucket {
            bucketName = selectedBucket.name
        }
        // 如果有配置默认存储桶但还没有选中，填入默认值
        else if let defaultBucket = accountManager.currentAccount?.defaultBucketName,
                !defaultBucket.isEmpty {
            bucketName = defaultBucket
        }
    }
    
    /// 尝试自动连接默认存储桶
    private func attemptAutoConnect() async {
        // 如果已经有选中的存储桶，不需要自动连接
        if r2Service.selectedBucket != nil {
            return
        }
        
        // 检查是否配置了默认存储桶
        guard let defaultBucketName = accountManager.currentAccount?.defaultBucketName,
              !defaultBucketName.isEmpty else {
            // 没有配置默认存储桶，显示输入界面
            await MainActor.run {
                needsManualInput = true
            }
            return
        }
        
        // 有默认存储桶配置，尝试自动连接
        await MainActor.run {
            isConnecting = true
        }
        
        do {
            let bucket = try await r2Service.selectBucketDirectly(defaultBucketName)
            
            await MainActor.run {
                isConnecting = false
                messageManager.showSuccess(L.Message.Success.autoConnected, description: L.Message.Success.autoConnectedDescription(bucket.name))
            }
        } catch {
            await MainActor.run {
                isConnecting = false
                needsManualInput = true
                bucketName = defaultBucketName  // 预填充默认存储桶名称
                
                if let r2Error = error as? R2ServiceError {
                    messageManager.showError(r2Error)
                } else {
                    messageManager.showError(L.Message.Error.autoConnectionFailed, description: L.Message.Error.cannotConnectToBucket(defaultBucketName))
                }
            }
        }
    }
    
    /// 连接到存储桶
    private func connectToBucket() {
        let trimmedName = bucketName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            messageManager.showError(L.Message.Error.enterBucketName)
            return
        }
        
        isConnecting = true
        
        Task {
            do {
                let bucket = try await r2Service.selectBucketDirectly(trimmedName)
                
                await MainActor.run {
                    isConnecting = false
                    needsManualInput = false  // 成功后隐藏输入界面
                    messageManager.showSuccess(L.Message.Success.connected, description: L.Message.Success.connectedToBucket(bucket.name))
                }
            } catch let error as R2ServiceError {
                await MainActor.run {
                    isConnecting = false
                    messageManager.showError(error)
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    messageManager.showError(L.Message.Error.connectionFailed, description: error.localizedDescription)
                }
            }
        }
    }
    
    /// 清除当前选择并显示输入界面
    private func clearAndShowInput() {
        r2Service.clearSelectedBucket()
        needsManualInput = true
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        BucketListView(r2Service: R2Service.preview)
    }
    .environmentObject(MessageManager())
    .environmentObject(R2AccountManager.shared)
} 