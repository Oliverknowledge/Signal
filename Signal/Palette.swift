import SwiftUI

public enum Palette {
    // Primary brand color for CTAs, active states, progress
    public static let primary: Color = Theme.Colors.primaryAccent

    // Neutrals
    public static let background: Color = Theme.Colors.primaryBackground
    public static let card: Color = Theme.Colors.contentSurface
    public static let textPrimary: Color = Theme.Colors.textPrimary
    public static let textSecondary: Color = Theme.Colors.textSecondary

    // Single subtle accent for success/confirmation/progress highlights
    public static let accentSuccess: Color = Theme.Colors.success

    public static let evaluationLow: Color = Theme.Colors.evaluationLow
}
