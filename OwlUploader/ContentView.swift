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
                    WelcomeView(
                        r2Service: r2Service,
                        onNavigateToBuckets: { selectedView = .buckets },
                        onNavigateToFiles: { selectedView = .files }
                    )
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

#Preview {
    ContentView()
}
