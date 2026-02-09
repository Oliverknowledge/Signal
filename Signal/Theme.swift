import SwiftUI

struct Theme {
    // MARK: - Colors
    struct Colors {
        // Backgrounds
        static let primaryBackground = Color(hex: "FFFFFF") // White
        static let secondaryBackground = Color(hex: "F2F6FF") // Light blue surface
        static let contentSurface = Color(hex: "FAFCFF") // White-ish card surface
        
        // Accents
        static let primaryAccent = Color(hex: "0D85FF") // Blue accent
        static let success = Color(hex: "22c55e") // Green 500
        static let mastery = Color(hex: "14b8a6") // Teal
        
        // Evaluation States
        static let evaluationHigh = primaryAccent // Blue
        static let evaluationMedium = Color(hex: "60A5FA") // Blue 400
        static let evaluationLow = Color(hex: "93C5FD") // Blue 300
        
        // Text
        static let textPrimary = Color(hex: "0F172A") // Slate 900
        static let textSecondary = Color(hex: "475569") // Slate 700
        static let textOnLight = Color(hex: "0f172a") // Slate 900
        static let textMuted = Color(hex: "64748B") // Slate 500
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold)
        static let title1 = Font.system(size: 28, weight: .bold)
        static let title2 = Font.system(size: 22, weight: .semibold)
        static let title3 = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let callout = Font.system(size: 16, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Reusable Components
struct SignalCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.contentSurface)
            .cornerRadius(Theme.CornerRadius.md)
    }
}

struct SignalButton: View {
    let title: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
        case ghost
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(backgroundColor)
                .cornerRadius(Theme.CornerRadius.md)
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Theme.Colors.primaryAccent
        case .secondary:
            return Theme.Colors.secondaryBackground
        case .ghost:
            return Color.clear
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return Theme.Colors.textPrimary
        case .ghost:
            return Theme.Colors.primaryAccent
        }
    }
}

struct ScoreCircle: View {
    let score: Double
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.secondaryBackground, lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: score)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(score * 100))%")
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .frame(width: size, height: size)
    }
    
    private var scoreColor: Color {
        if score >= 0.8 {
            return Theme.Colors.success
        } else if score >= 0.6 {
            return Theme.Colors.evaluationMedium
        } else {
            return Theme.Colors.evaluationLow
        }
    }
}

