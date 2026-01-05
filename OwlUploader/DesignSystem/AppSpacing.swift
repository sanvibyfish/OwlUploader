import Foundation

/// Layout spacing constants based on an 8pt grid system.
enum AppSpacing {
    
    /// 4pt
    static let tiny: CGFloat = 4
    
    /// 8pt - The standard unit
    static let small: CGFloat = 8
    
    /// 12pt
    static let medium: CGFloat = 12
    
    /// 16pt - Standard padding
    static let large: CGFloat = 16
    
    /// 24pt
    static let xLarge: CGFloat = 24
    
    /// 32pt
    static let xxLarge: CGFloat = 32
    
    // MARK: - Specific Use Cases
    
    /// Standard padding for list items
    static let listRowPadding: CGFloat = 8
    
    /// Standard padding for window/view edges
    static let pagePadding: CGFloat = 20
    
    /// Spacing between related items in a stack
    static let stackSpacing: CGFloat = 12
}
