import SwiftUI

/// A centralized definition of semantic colors for the app.
/// Uses native macOS colors (NSColor) to ensure perfect integration with system appearance and dark mode.
enum AppColors {
    
    // MARK: - Backgrounds
    
    /// Standard window background (usually slightly off-white or dark gray)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    
    /// Background for content areas (lists, text views)
    static let contentBackground = Color(nsColor: .controlBackgroundColor)
    
    /// Secondary background for sidebars or grouped content
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor).opacity(0.5) // Or visual effect view
    
    // MARK: - Text
    
    /// Primary text color (high contrast)
    static let textPrimary = Color(nsColor: .labelColor)
    
    /// Secondary text color (medium contrast)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    
    /// Tertiary text color (low contrast, for placeholders/disabled)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    
    // MARK: - Accents & Status
    
    /// Primary brand color (System Blue for native feel)
    static let primary = Color(nsColor: .systemBlue)
    
    /// Destructive action color
    static let destructive = Color(nsColor: .systemRed)

    /// Error state (alias for destructive)
    static let error = Color(nsColor: .systemRed)

    /// Success state
    static let success = Color(nsColor: .systemGreen)
    
    /// Warning state
    static let warning = Color(nsColor: .systemOrange)
    
    /// Info state
    static let info = Color(nsColor: .systemBlue)
    
    // MARK: - UI Elements
    
    /// Separator lines
    static let separator = Color(nsColor: .separatorColor)
    
    /// Border color for inputs/cards
    static let border = Color(nsColor: .gridColor)
}

// Extension to easily use these in standard SwiftUI modifiers
extension Color {
    static let appWindowBackground = AppColors.windowBackground
    static let appContentBackground = AppColors.contentBackground
    static let appTextPrimary = AppColors.textPrimary
    static let appTextSecondary = AppColors.textSecondary
    static let appPrimary = AppColors.primary
}
