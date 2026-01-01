import SwiftUI

/// Standardized typography styles for the application.
/// Follows Apple's Human Interface Guidelines for hierarchy.
enum AppTypography {
    
    // MARK: - Headers
    
    /// Large page titles (e.g. "My Files")
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    
    /// Section headers (e.g. "Buckets", "Recent")
    static let title2 = Font.system(.title2, design: .default).weight(.semibold)
    
    /// Subsection headers
    static let headline = Font.system(.headline, design: .default).weight(.medium)
    
    // MARK: - Body
    
    /// Standard body text
    static let body = Font.system(.body, design: .default)
    
    /// Secondary/Description text
    static let callout = Font.system(.callout, design: .default)
    
    /// Small captions (metadata, timestamps)
    static let caption = Font.system(.caption, design: .default)
    
    // MARK: - Monospace
    
    /// For technical data like Hashes, IDs, or file sizes
    static let monospacedDigit = Font.system(.body, design: .monospaced)
}

extension View {
    /// Applies the standard large title style
    func styleLargeTitle() -> some View {
        self.font(AppTypography.largeTitle).foregroundColor(AppColors.textPrimary)
    }
    
    /// Applies the standard section header style
    func styleSectionHeader() -> some View {
        self.font(AppTypography.title2).foregroundColor(AppColors.textPrimary)
    }
    
    /// Applies standard body style
    func styleBody() -> some View {
        self.font(AppTypography.body).foregroundColor(AppColors.textPrimary)
    }
    
    /// Applies secondary text style
    func styleSecondary() -> some View {
        self.font(AppTypography.callout).foregroundColor(AppColors.textSecondary)
    }
}
