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
        .navigationTitle("选择存储桶")
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
                
                Text(r2Service.isConnected ? "已连接" : "未连接")
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
                    
                    Text("已选择: \(selectedBucket.name)")
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
                Text("未连接到 R2 服务")
                    .font(.headline)
                
                Text("请先在账户设置中配置并连接您的 R2 账户")
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
                
                Text("存储桶已选择")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("当前存储桶：\(bucket.name)")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            // 操作按钮
            VStack(spacing: 12) {
                Button("进入文件管理") {
                    // 这里可以触发导航到文件管理页面
                    // 或者发送通知让父视图处理导航
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("更换存储桶") {
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
            
            Text("正在连接存储桶...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if let defaultBucket = accountManager.currentAccount?.defaultBucketName {
                Text("尝试连接到：\(defaultBucket)")
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
            
            Text("检查存储桶配置...")
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
                
                Text("选择存储桶")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("请输入您要访问的 R2 存储桶名称")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 输入区域
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("存储桶名称")
                        .font(.headline)
                    
                    TextField("my-bucket-name", text: $bucketName)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .disabled(isConnecting)
                    
                    Text("存储桶名称通常为小写字母、数字和连字符的组合")
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
                        
                        Text(isConnecting ? "连接中..." : "连接到存储桶")
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
                    Text("💡 小提示")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• 确保存储桶已在 Cloudflare R2 控制台中创建")
                        Text("• 确保您的 API Token 有访问该存储桶的权限")
                        Text("• 存储桶名称区分大小写")
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
                messageManager.showSuccess("自动连接成功", description: "已连接到配置的默认存储桶 '\(bucket.name)'")
            }
        } catch {
            await MainActor.run {
                isConnecting = false
                needsManualInput = true
                bucketName = defaultBucketName  // 预填充默认存储桶名称
                
                if let r2Error = error as? R2ServiceError {
                    messageManager.showError(r2Error)
                } else {
                    messageManager.showError("自动连接失败", description: "无法连接到默认存储桶 '\(defaultBucketName)'，请手动重试")
                }
            }
        }
    }
    
    /// 连接到存储桶
    private func connectToBucket() {
        let trimmedName = bucketName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            messageManager.showError("请输入存储桶名称")
            return
        }
        
        isConnecting = true
        
        Task {
            do {
                let bucket = try await r2Service.selectBucketDirectly(trimmedName)
                
                await MainActor.run {
                    isConnecting = false
                    needsManualInput = false  // 成功后隐藏输入界面
                    messageManager.showSuccess("连接成功", description: "已成功连接到存储桶 '\(bucket.name)'")
                }
            } catch let error as R2ServiceError {
                await MainActor.run {
                    isConnecting = false
                    messageManager.showError(error)
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    messageManager.showError("连接失败", description: error.localizedDescription)
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