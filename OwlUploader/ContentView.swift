//
//  ContentView.swift
//  OwlUploader
//
//  Created by Sanvi Lu on 2025/5/25.
//

import SwiftUI

struct ContentView: View {
    /// 当前显示的主视图
    @State private var selectedView: MainViewSelection? = nil

    /// R2 服务实例
    @StateObject private var r2Service = R2Service.shared

    /// R2 账户管理器实例
    @StateObject private var accountManager = R2AccountManager.shared

    /// 消息管理器实例
    @StateObject private var messageManager = MessageManager()

    /// 选择状态管理器
    @StateObject private var selectionManager = SelectionManager()

    /// 视图模式管理器
    @StateObject private var viewModeManager = ViewModeManager()

    /// 断开连接确认对话框
    @State private var showDisconnectConfirmation: Bool = false
    
    /// 显示设置页面
    @State private var showSettings: Bool = false
    
    /// 主视图选择枚举
    enum MainViewSelection: Hashable {
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
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            Group {
                switch selectedView {
                case .buckets:
                    BucketListView(r2Service: r2Service)
                case .files:
                    FileListView(
                        r2Service: r2Service,
                        selectionManager: selectionManager,
                        viewModeManager: viewModeManager,
                        isActive: selectedView == .files
                    )
                    .id("files-\(r2Service.selectedBucket?.name ?? "")")
                case .none:
                    WelcomeView(r2Service: r2Service)
                }
            }
            .frame(minWidth: 600, minHeight: 400)
        }
        .environmentObject(r2Service)
        .environmentObject(accountManager)
        .environmentObject(messageManager)
        .focusedValue(\.settingsActions, SettingsActions(openSettings: { showSettings = true }))
        .sheet(isPresented: $showSettings) {
            AccountSettingsView()
                .frame(width: 600, height: 500)
        }
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
        .alert(L.Alert.Disconnect.title, isPresented: $showDisconnectConfirmation) {
            Button(L.Common.Button.cancel, role: .cancel) { }
            Button(L.Sidebar.Action.disconnect, role: .destructive) {
                disconnectFromR2Service()
            }
        } message: {
            Text(L.Alert.Disconnect.description)
        }
    }
    
    // MARK: - Private Methods
    
    /// 执行初始设置和状态检测
    private func performInitialSetup() {
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else {
            return
        }
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
            if selectedView == nil {
                selectedView = .buckets
            }
        } else {
            // 连接断开，导航到欢迎页面
            selectedView = nil
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
        messageManager.showSuccess(L.Message.Success.disconnected, description: L.Message.Success.disconnectedDescription)
        
        // 导航回欢迎页面
        selectedView = nil
    }
}

/// 欢迎页面视图
struct WelcomeView: View {
    /// R2 服务实例
    let r2Service: R2Service
    
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(spacing: 30) {
            // 应用图标和标题
            VStack(spacing: 16) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text(L.Welcome.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L.Welcome.subtitle)
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // 功能介绍
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "folder", title: L.Welcome.Feature.fileManagementTitle, description: L.Welcome.Feature.fileManagementDesc)
                FeatureRow(icon: "square.and.arrow.up", title: L.Welcome.Feature.uploadTitle, description: L.Welcome.Feature.uploadDesc)
                FeatureRow(icon: "folder.badge.plus", title: L.Welcome.Feature.folderTitle, description: L.Welcome.Feature.folderDesc)
                FeatureRow(icon: "lock.shield", title: L.Welcome.Feature.securityTitle, description: L.Welcome.Feature.securityDesc)
            }
            .padding(.horizontal, 40)
            
            // 快速开始提示
            VStack(spacing: 12) {
                Text(L.Welcome.getStarted)
                    .font(.headline)
                
                // 当前状态指示
                currentStatusView
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
        .navigationTitle(L.Welcome.navigationTitle)
    }
    
    /// 当前状态指示视图
    @ViewBuilder
    private var currentStatusView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(r2Service.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(r2Service.isConnected ? L.Common.Status.connectedToR2 : L.Common.Status.notConnected)
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
                Text(L.Welcome.Status.configurePrompt)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else if r2Service.selectedBucket == nil {
                Text(L.Welcome.Status.selectBucketPrompt)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 8) {
                    Text(L.Welcome.Status.currentBucket(r2Service.selectedBucket!.name))
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(L.Welcome.Status.readyToManage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
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
    WelcomeView(r2Service: R2Service.preview)
        .environmentObject(R2Service.preview)
}
