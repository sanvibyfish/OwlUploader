//
//  DiagnosticsView.swift
//  OwlUploader
//
//  Created by Assistant on 2025/5/25.
//

import SwiftUI

/// 诊断视图
/// 用于检查上传功能的各项前置条件和提供故障排除建议
struct DiagnosticsView: View {
    /// R2 服务实例
    @ObservedObject var r2Service: R2Service
    
    /// 环境：弹窗关闭
    @Environment(\.dismiss) private var dismiss
    
    /// 诊断结果状态
    @State private var diagnosticsResult: (isReady: Bool, issues: [String], suggestions: [String])? = nil
    
    /// 是否正在运行诊断
    @State private var isRunningDiagnostics: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题区域
            VStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.purple)
                
                Text("上传功能诊断")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("检查上传功能的各项配置和状态")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 诊断内容区域
            if isRunningDiagnostics {
                // 运行中状态
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在检查各项配置...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let result = diagnosticsResult {
                // 显示诊断结果
                diagnosticsResultView(result)
            } else {
                // 初始状态
                initialStateView
            }
            
            Spacer(minLength: 20)
            
            // 底部按钮
            HStack {
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("开始诊断") {
                    runDiagnostics()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunningDiagnostics)
            }
        }
        .padding(20)
        .frame(minWidth: 800, idealWidth: 900, maxWidth: 1200, minHeight: 650, idealHeight: 750, maxHeight: 1000)
        .navigationTitle("系统诊断")
    }
    
    /// 初始状态视图
    private var initialStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("点击\"开始诊断\"检查上传功能状态")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("诊断将检查以下项目：")
                .font(.headline)
                .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 8) {
                DiagnosticCheckItem(title: "账户连接状态", icon: "wifi")
                DiagnosticCheckItem(title: "存储桶选择状态", icon: "externaldrive")
                DiagnosticCheckItem(title: "账户配置信息", icon: "person.badge.key")
                DiagnosticCheckItem(title: "端点 URL 格式", icon: "link")
                DiagnosticCheckItem(title: "客户端初始化", icon: "gear")
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 诊断结果视图
    /// - Parameter result: 诊断结果
    private func diagnosticsResultView(_ result: (isReady: Bool, issues: [String], suggestions: [String])) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 总体状态
                HStack {
                    Image(systemName: result.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(result.isReady ? .green : .orange)
                    
                    Text(result.isReady ? "上传功能就绪" : "发现问题需要解决")
                        .font(.headline)
                        .foregroundColor(result.isReady ? .green : .orange)
                }
                
                if !result.isReady {
                    Divider()
                    
                    // 发现的问题
                    VStack(alignment: .leading, spacing: 12) {
                        Text("发现的问题：")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(Array(result.issues.enumerated()), id: \.offset) { index, issue in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                                    .padding(.top, 2)
                                
                                Text(issue)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    Divider()
                    
                    // 解决建议
                    VStack(alignment: .leading, spacing: 12) {
                        Text("解决建议：")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(Array(result.suggestions.enumerated()), id: \.offset) { index, suggestion in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 14))
                                    .padding(.top, 2)
                                
                                Text(suggestion)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                } else {
                    // 成功状态的详细信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text("✅ 所有检查项目均通过")
                            .font(.body)
                            .foregroundColor(.green)
                        
                        Text("您可以正常使用文件上传功能")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
    }
    
    /// 运行诊断
    private func runDiagnostics() {
        isRunningDiagnostics = true
        diagnosticsResult = nil
        
        // 模拟延迟，让用户看到加载状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            diagnosticsResult = r2Service.diagnoseUploadIssues()
            isRunningDiagnostics = false
        }
    }
}

/// 诊断检查项目组件
private struct DiagnosticCheckItem: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预览

#Preview {
    DiagnosticsView(r2Service: R2Service.preview)
} 
