//
//  ContentView.swift
//  OwlUploader
//
//  Created by Sanvi Lu on 2025/5/25.
//

import SwiftUI

struct ContentView: View {
    /// 当前显示的主视图
    @State private var selectedView: MainViewSelection? = .welcome
    
    /// R2 服务实例
    @StateObject private var r2Service = R2Service.shared
    
    /// R2 账户管理器实例
    @StateObject private var accountManager = R2AccountManager.shared
    
    /// 消息管理器实例
    @StateObject private var messageManager = MessageManager()
    
    /// 断开连接确认对话框
    @State private var showDisconnectConfirmation: Bool = false
    
    /// 主视图选择枚举
    enum MainViewSelection: Hashable {
        case welcome
        case settings
        case buckets
        case files
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedView: $selectedView,
                r2Service: r2Service,
                accountManager: accountManager
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            Group {
                switch selectedView {
                case .welcome:
                    WelcomeView(selectedView: $selectedView, r2Service: r2Service)
                case .settings:
                    AccountSettingsView()
                case .buckets:
                    BucketListView(r2Service: r2Service)
                case .files:
                    FileListView(r2Service: r2Service)
                case .none:
                    WelcomeView(selectedView: $selectedView, r2Service: r2Service)
                }
            }
            .frame(minWidth: 600, minHeight: 400)
        }
        .environmentObject(r2Service)
        .environmentObject(accountManager)
        .environmentObject(messageManager)
        .overlay(alignment: .topTrailing) {
            MessageBannerContainer(messageManager: messageManager)
                .padding()
                .frame(maxWidth: 400)
        }
        .onAppear {
            performInitialSetup()
        }
        .onChange(of: r2Service.isConnected) { isConnected in
            handleConnectionStateChange(isConnected)
        }
        .onChange(of: r2Service.selectedBucket) { bucket in
            handleBucketSelectionChange(bucket)
        }
        .alert("断开连接", isPresented: $showDisconnectConfirmation) {
            Button("取消", role: .cancel) { }
            Button("断开连接", role: .destructive) {
                disconnectFromR2Service()
            }
        } message: {
            Text("确定要断开与 R2 服务的连接吗？\n\n断开后将清除当前会话状态，包括选中的存储桶和文件列表。")
        }
    }
    
    // MARK: - Private Methods
    
    /// 执行初始设置和状态检测
    private func performInitialSetup() {
        // 触发 R2Service 的自动加载和连接
        Task {
            await r2Service.loadAccountAndInitialize()
        }
    }
    
    /// 处理连接状态变化
    private func handleConnectionStateChange(_ isConnected: Bool) {
        print("📱 ContentView: 连接状态变化 isConnected = \(isConnected)")
        print("📱 ContentView: r2Service 实例地址: \(Unmanaged.passUnretained(r2Service).toOpaque())")
        
        // 强制触发 UI 更新
        DispatchQueue.main.async {
            self.r2Service.objectWillChange.send()
        }
        
        if isConnected {
            // 连接成功，如果当前在欢迎页面，自动导航到存储桶选择
            if selectedView == .welcome {
                selectedView = .buckets
            }
        } else {
            // 连接断开，如果当前不在账户设置页面，导航到欢迎页面
            if selectedView != .settings {
                selectedView = .welcome
            }
        }
    }
    
    /// 处理存储桶选择状态变化
    private func handleBucketSelectionChange(_ bucket: BucketItem?) {
        if bucket != nil {
            // 选择了存储桶，如果当前在存储桶页面，自动导航到文件管理
            if selectedView == .buckets {
                selectedView = .files
            }
        }
    }
    
    /// 断开 R2 服务连接
    private func disconnectFromR2Service() {
        // 调用 R2Service 的断开连接方法
        r2Service.disconnect()
        
        // 显示成功消息
        messageManager.showSuccess("断开连接成功", description: "已成功断开与 R2 服务的连接，可以重新配置账户")
        
        // 导航回欢迎页面
        selectedView = .welcome
    }
}

/// 欢迎页面视图
struct WelcomeView: View {
    /// 当前选中的视图绑定
    @Binding var selectedView: ContentView.MainViewSelection?
    
    /// R2 服务实例
    let r2Service: R2Service
    var body: some View {
        VStack(spacing: 30) {
            // 应用图标和标题
            VStack(spacing: 16) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("OwlUploader")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("专业的 R2 文件管理工具")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // 功能介绍
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "folder", title: "文件管理", description: "浏览和管理 R2 存储桶中的文件")
                FeatureRow(icon: "square.and.arrow.up", title: "文件上传", description: "快速上传本地文件到 R2 存储")
                FeatureRow(icon: "folder.badge.plus", title: "创建文件夹", description: "在 R2 中创建和组织文件夹")
                FeatureRow(icon: "lock.shield", title: "安全连接", description: "使用 Keychain 安全存储账户凭证")
            }
            .padding(.horizontal, 40)
            
            // 快速开始提示
            VStack(spacing: 12) {
                Text("开始使用")
                    .font(.headline)
                
                // 当前状态指示
                currentStatusView
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
        .navigationTitle("欢迎")
    }
    
    /// 当前状态指示视图
    @ViewBuilder
    private var currentStatusView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(r2Service.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(r2Service.isConnected ? "已连接到 R2" : "未连接")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 调试信息
                Text("(\(r2Service.isConnected ? "T" : "F"))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .onAppear {
                print("🏠 欢迎页面: r2Service.isConnected = \(r2Service.isConnected)")
                print("🏠 欢迎页面: r2Service 实例地址: \(Unmanaged.passUnretained(r2Service).toOpaque())")
            }
            
            if !r2Service.isConnected {
                VStack(spacing: 12) {
                    Text("请配置您的 R2 账户以开始使用")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("配置账户") {
                        selectedView = .settings
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if r2Service.selectedBucket == nil {
                VStack(spacing: 12) {
                    Text("账户已连接，请选择要操作的存储桶")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("选择存储桶") {
                        selectedView = .buckets
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 12) {
                    Text("当前选择的存储桶：\(r2Service.selectedBucket!.name)")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text("您已准备好开始管理文件了！")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("开始管理文件") {
                        selectedView = .files
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // 始终显示重新配置选项
            VStack(spacing: 8) {
                Divider()
                    .padding(.horizontal, 20)
                
                Button("重新配置账户") {
                    selectedView = .settings
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
            }
        }
    }
}

/// 功能特性行视图
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}

#Preview("WelcomeView") {
    WelcomeView(selectedView: .constant(.welcome), r2Service: R2Service.preview)
        .environmentObject(R2Service.preview)
}

