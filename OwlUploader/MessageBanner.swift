import SwiftUI

/// 消息类型
enum MessageType {
    case success
    case error
    case warning
    case info
    
    var color: Color {
        switch self {
        case .success: return AppColors.success
        case .error: return AppColors.error
        case .warning: return AppColors.warning
        case .info: return AppColors.info
        }
    }
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
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
    
    func show(_ message: Message) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            messages.append(message)
        }
        
        Task {
            try await Task.sleep(nanoseconds: UInt64(message.duration * 1_000_000_000))
            await hide(message)
        }
    }
    
    func hide(_ message: Message) {
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.removeAll { $0.id == message.id }
        }
    }
    
    func showSuccess(_ title: String, description: String? = nil) {
        show(Message(type: .success, title: title, description: description))
    }
    
    func showError(_ title: String, description: String? = nil, 
                   actionTitle: String? = nil, action: (() -> Void)? = nil) {
        show(Message(type: .error, title: title, description: description, 
                     duration: 6.0, actionTitle: actionTitle, action: action))
    }
    
    func showError(_ error: R2ServiceError) {
        let actionTitle = error.isRetryable ? "Retry" : nil
        showError(error.localizedDescription, description: error.suggestedAction, actionTitle: actionTitle)
    }
    
    func showWarning(_ title: String, description: String? = nil) {
        show(Message(type: .warning, title: title, description: description))
    }
    
    func showInfo(_ title: String, description: String? = nil) {
        show(Message(type: .info, title: title, description: description))
    }
    
    func clearAll() {
        withAnimation {
            messages.removeAll()
        }
    }
}

/// 消息横幅视图
struct MessageBannerView: View {
    let message: Message
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Image(systemName: message.type.iconName)
                .font(.title3)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                
                if let description = message.description {
                    Text(description)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if let actionTitle = message.actionTitle, let action = message.action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.2))
                .foregroundColor(.white)
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(message.type.color)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        // Add a clean border
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

/// 消息横幅容器
struct MessageBannerContainer: View {
    @ObservedObject var messageManager: MessageManager
    
    var body: some View {
        VStack(spacing: AppSpacing.small) {
            ForEach(messageManager.messages) { message in
                MessageBannerView(message: message) {
                    messageManager.hide(message)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, AppSpacing.medium)
        .animation(.spring(), value: messageManager.messages.count)
    }
}