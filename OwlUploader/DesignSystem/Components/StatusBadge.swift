import SwiftUI

struct StatusBadge: View {
    
    enum Variant {
        case success
        case warning
        case error
        case info
        case custom(Color)
        
        var color: Color {
            switch self {
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .error: return AppColors.destructive
            case .info: return AppColors.primary
            case .custom(let color): return color
            }
        }
    }
    
    let text: String
    let variant: Variant
    
    var body: some View {
        Text(text)
            .font(AppTypography.caption.weight(.medium))
            .foregroundColor(variant.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                variant.color.opacity(0.12)
            )
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(variant.color.opacity(0.3), lineWidth: 1)
            )
    }
}
