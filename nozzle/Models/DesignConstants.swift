import SwiftUI

/// Design constants following Liquid Glass standards
struct DesignConstants {
    // MARK: Corner Radius
    /// Standard corner radius used throughout the app (following Liquid Glass standard)
    static let cornerRadius: CGFloat = 15.0
    
    /// Corner radius for tabs and selection items (Liquid Glass grid standard)
    static let tabCornerRadius: CGFloat = 8.0
    
    /// Small corner radius for minor UI elements
    static let smallCornerRadius: CGFloat = 8.0
    
    /// Badge corner radius for prominent elements
    static let badgeCornerRadius: CGFloat = 24.0
    
    // MARK: Opacity Values
    /// Selected tab opacity (with accent color)
    static let selectedTabOpacity: Double = 0.15
    
    /// Unselected tab opacity (white overlay, Spotlight-style - very subtle)
    static let unselectedTabOpacity: Double = 0.06
    
    // MARK: Padding and Spacing
    /// Standard padding used throughout the app
    static let standardPadding: CGFloat = 14.0
    
    /// Leading content inset for consistent alignment
    static let leadingContentInset: CGFloat = 26.0
    
    /// Safe area padding
    static let safeAreaPadding: CGFloat = 30.0
    
    // MARK: Typography
    /// Title padding values
    static let titleTopPadding: CGFloat = 8.0
    static let titleBottomPadding: CGFloat = -4.0
    
    // MARK: Material Style
    #if os(macOS)
    /// Background material style for macOS
    static let backgroundMaterial = WindowBackgroundShapeStyle.windowBackground
    #else
    /// Background material style for iOS
    static let backgroundMaterial = Material.ultraThickMaterial
    #endif
}