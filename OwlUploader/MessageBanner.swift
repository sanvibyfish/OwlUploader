import SwiftUI

/// 消息类型
enum MessageType {
    case success
    case error
    case warning
    case info
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
    
    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

/// 消息内容
struct Message: Identifiable, Equatable {
    let id = UUID()
    let type: MessageType
    let title: String
    let description: String?
    let duration: TimeInterval
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(type: MessageType, title: String, description: String? = nil, 
         duration: TimeInterval = 4.0, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.type = type
        self.title = title
        self.description = description
        self.duration = duration
        self.actionTitle = actionTitle
        self.action = action
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

/// 消息管理器
@MainActor
class MessageManager: ObservableObject {
    @Published var messages: [Message] = []
    
    /// 显示消息
    /// - Parameter message: 要显示的消息
    func show(_ message: Message) {
        withAnimation(.easeInOut(duration: 0.3)) {
            messages.append(message)
        }
        
        // 自动隐藏消息
        Task {
            try await Task.sleep(nanoseconds: UInt64(message.duration * 1_000_000_000))
            await hide(message)
        }
    }
    
    /// 隐藏消息
    /// - Parameter message: 要隐藏的消息
    func hide(_ message: Message) {
        withAnimation(.easeInOut(duration: 0.3)) {
            messages.removeAll { $0.id == message.id }
        }
    }
    
    /// 显示成功消息
    /// - Parameters:
    ///   - title: 标题
    ///   - description: 描述（可选）
    func showSuccess(_ title: String, description: String? = nil) {
        let message = Message(type: .success, title: title, description: description)
        show(message)
    }
    
    /// 显示错误消息
    /// - Parameters:
    ///   - title: 标题
    ///   - description: 描述（可选）
    ///   - actionTitle: 操作按钮标题（可选）
    ///   - action: 操作回调（可选）
    func showError(_ title: String, description: String? = nil, 
                   actionTitle: String? = nil, action: (() -> Void)? = nil) {
        let message = Message(
            type: .error,
            title: title,
            description: description,
            duration: 6.0, // 错误消息显示更长时间
            actionTitle: actionTitle,
            action: action
        )
        show(message)
    }
    
    /// 显示 R2Service 错误
    /// - Parameter error: R2ServiceError
    func showError(_ error: R2ServiceError) {
        let actionTitle = error.isRetryable ? "重试" : nil
        showError(
            error.localizedDescription,
            description: error.suggestedAction,
            actionTitle: actionTitle
        )
    }
    
    /// 显示警告消息
    /// - Parameters:
    ///   - title: 标题
    ///   - description: 描述（可选）
    func showWarning(_ title: String, description: String? = nil) {
        let message = Message(type: .warning, title: title, description: description)
        show(message)
    }
    
    /// 显示信息消息
    /// - Parameters:
    ///   - title: 标题
    ///   - description: 描述（可选）
    func showInfo(_ title: String, description: String? = nil) {
        let message = Message(type: .info, title: title, description: description)
        show(message)
    }
    
    /// 清除所有消息
    func clearAll() {
        withAnimation(.easeInOut(duration: 0.3)) {
            messages.removeAll()
        }
    }
}

/// 消息横幅视图
struct MessageBannerView: View {
    let message: Message
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: message.type.iconName)
                .font(.title3)
                .foregroundColor(.white)
            
            // 文本内容
            VStack(alignment: .leading, spacing: 4) {
                Text(message.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                if let description = message.description {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                if let actionTitle = message.actionTitle,
                   let action = message.action {
                    Button(actionTitle) {
                        action()
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2))
                    .cornerRadius(6)
                }
                
                // 关闭按钮
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .background(message.type.color)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

/// 消息横幅容器视图
struct MessageBannerContainer: View {
    @ObservedObject var messageManager: MessageManager
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(messageManager.messages) { message in
                MessageBannerView(message: message) {
                    messageManager.hide(message)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: messageManager.messages.count)
    }
}

// MARK: - 预览

#Preview("成功消息") {
    VStack {
        MessageBannerView(
            message: Message(
                type: .success,
                title: "上传成功",
                description: "文件 'document.pdf' 已成功上传到存储桶"
            )
        ) { }
        .padding()
        
        Spacer()
    }
}

#Preview("错误消息") {
    VStack {
        MessageBannerView(
            message: Message(
                type: .error,
                title: "上传失败",
                description: "网络连接错误，请检查网络连接并重试",
                actionTitle: "重试"
            ) { }
        ) { }
        .padding()
        
        Spacer()
    }
}

#Preview("消息管理器") {
    @StateObject var messageManager = MessageManager()
    
    return VStack {
        MessageBannerContainer(messageManager: messageManager)
            .padding()
        
        Spacer()
        
        VStack(spacing: 16) {
            Button("显示成功消息") {
                messageManager.showSuccess("操作成功", description: "文件已成功上传")
            }
            
            Button("显示错误消息") {
                messageManager.showError("操作失败", description: "网络连接错误", actionTitle: "重试") {
                    print("重试操作")
                }
            }
            
            Button("显示警告消息") {
                messageManager.showWarning("注意", description: "存储空间即将用完")
            }
            
            Button("清除所有消息") {
                messageManager.clearAll()
            }
        }
        .padding()
    }
} 