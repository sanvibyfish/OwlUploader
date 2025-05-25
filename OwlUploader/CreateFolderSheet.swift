//
//  CreateFolderSheet.swift
//  OwlUploader
//
//  创建文件夹弹窗组件
//  用于替代 Alert 方式，提供更好的 macOS 兼容性和用户体验
//

import SwiftUI

struct CreateFolderSheet: View {
    
    // MARK: - Bindings
    
    /// 是否显示弹窗
    @Binding var isPresented: Bool
    
    /// 文件夹名称输入
    @State private var folderName: String = ""
    
    /// 输入焦点状态
    @FocusState private var isTextFieldFocused: Bool
    
    /// 是否正在创建
    @State private var isCreating: Bool = false
    
    /// 创建回调
    let onCreateFolder: (String) -> Void
    
    // MARK: - Computed Properties
    
    /// 文件夹名称是否有效
    private var isValidFolderName: Bool {
        let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        
        // 检查是否包含非法字符
        // S3/R2 存储桶对象键的命名规则：
        // - 不能包含: \ / : * ? " < > |
        // - 连字符 - 是允许的 ✅
        // - 下划线 _ 是允许的 ✅
        // - 点 . 是允许的 ✅（但不建议作为开头或结尾）
        let illegalCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let hasIllegalChars = trimmedName.rangeOfCharacter(from: illegalCharacters) != nil
        
        // 添加调试信息
        if hasIllegalChars {
            print("🐛 文件夹名称 '\(trimmedName)' 包含非法字符")
            for char in trimmedName {
                if let scalar = String(char).unicodeScalars.first, illegalCharacters.contains(scalar) {
                    print("  非法字符: '\(char)' (Unicode: \\(scalar.value))")
                }
            }
        }
        
        return !hasIllegalChars
    }
    
    /// 创建按钮是否可用
    private var canCreate: Bool {
        return isValidFolderName && !isCreating
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("创建新文件夹")
                .font(.title2)
                .fontWeight(.semibold)
            
            // 输入区域
            VStack(alignment: .leading, spacing: 8) {
                Text("文件夹名称")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("请输入文件夹名称", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if canCreate {
                            createFolder()
                        }
                    }
                
                // 输入提示和验证信息
                VStack(alignment: .leading, spacing: 4) {
                    Text("文件夹名称不能包含以下字符：\\ / : * ? \" < > |")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !folderName.isEmpty && !isValidFolderName {
                        Text("❌ 文件夹名称包含无效字符")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if !folderName.isEmpty && isValidFolderName {
                        Text("✅ 文件夹名称有效")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // 按钮区域
            HStack(spacing: 12) {
                // 取消按钮
                Button("取消") {
                    dismissSheet()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)
                
                Spacer()
                
                // 创建按钮
                Button("创建文件夹") {
                    createFolder()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate)
                
                if isCreating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onAppear {
            // 弹窗出现时自动聚焦到输入框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    // MARK: - Methods
    
    /// 创建文件夹
    private func createFolder() {
        guard canCreate else { return }
        
        let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        isCreating = true
        
        // 调用创建回调
        onCreateFolder(trimmedName)
        
        // 立即关闭弹窗，创建是异步的
        dismissSheet()
    }
    
    /// 关闭弹窗
    private func dismissSheet() {
        folderName = ""
        isCreating = false
        isPresented = false
    }
}

// MARK: - 预览

#Preview {
    CreateFolderSheet(
        isPresented: .constant(true),
        onCreateFolder: { folderName in
            print("创建文件夹: \(folderName)")
        }
    )
    .frame(width: 500, height: 300)
} 