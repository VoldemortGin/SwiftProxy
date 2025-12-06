import SwiftUI

/// App-wide theme configuration
/// Provides semantic colors and styles that adapt to light/dark mode
public struct AppTheme {
    // MARK: - Colors

    /// Primary brand colors
    public struct Colors {
        // MARK: - Brand Colors
        public static let primary = Color.accentColor
        public static let secondary = Color.gray

        // MARK: - Status Colors
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let info = Color.blue

        // MARK: - Background Colors
        public static let background = Color(nsColor: .windowBackgroundColor)
        public static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
        public static let tertiaryBackground = Color(nsColor: .textBackgroundColor)

        // MARK: - Text Colors
        public static let primaryText = Color.primary
        public static let secondaryText = Color.secondary
        public static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
        public static let placeholderText = Color(nsColor: .placeholderTextColor)

        // MARK: - Border Colors
        public static let border = Color(nsColor: .separatorColor)
        public static let divider = Color(nsColor: .separatorColor)

        // MARK: - Special Colors
        public static let link = Color.blue
        public static let selection = Color.accentColor.opacity(0.2)
        public static let hover = Color.accentColor.opacity(0.1)

        // MARK: - Proxy Status Colors
        public static let proxyEnabled = Color.green
        public static let proxyDisabled = Color.gray
        public static let proxyConnecting = Color.orange
        public static let proxyError = Color.red

        // MARK: - Chart Colors
        public static let chartPrimary = Color.blue
        public static let chartSecondary = Color.green
        public static let chartTertiary = Color.orange
        public static let chartQuaternary = Color.purple
        public static let chartGradient = LinearGradient(
            colors: [chartPrimary.opacity(0.5), chartPrimary.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Typography

    public struct Typography {
        public static let largeTitle = Font.largeTitle.weight(.bold)
        public static let title = Font.title.weight(.semibold)
        public static let title2 = Font.title2.weight(.semibold)
        public static let title3 = Font.title3.weight(.medium)
        public static let headline = Font.headline
        public static let body = Font.body
        public static let callout = Font.callout
        public static let subheadline = Font.subheadline
        public static let footnote = Font.footnote
        public static let caption = Font.caption
        public static let caption2 = Font.caption2

        // MARK: - Custom Fonts
        public static let monospacedBody = Font.body.monospaced()
        public static let monospacedCaption = Font.caption.monospaced()
    }

    // MARK: - Spacing

    public struct Spacing {
        public static let xxxSmall: CGFloat = 2
        public static let xxSmall: CGFloat = 4
        public static let xSmall: CGFloat = 8
        public static let small: CGFloat = 12
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 20
        public static let xLarge: CGFloat = 24
        public static let xxLarge: CGFloat = 32
        public static let xxxLarge: CGFloat = 40
    }

    // MARK: - Corner Radius

    public struct CornerRadius {
        public static let small: CGFloat = 4
        public static let medium: CGFloat = 8
        public static let large: CGFloat = 12
        public static let xLarge: CGFloat = 16
        public static let circle: CGFloat = 999
    }

    // MARK: - Shadow

    public struct ShadowStyle {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat

        public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }

        public static let small = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 2,
            x: 0,
            y: 1
        )

        public static let medium = ShadowStyle(
            color: Color.black.opacity(0.15),
            radius: 4,
            x: 0,
            y: 2
        )

        public static let large = ShadowStyle(
            color: Color.black.opacity(0.2),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    // MARK: - Animation

    public struct Animation {
        public static let fast = SwiftUI.Animation.easeInOut(duration: 0.2)
        public static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        public static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        public static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        public static let springBouncy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.6)
    }

    // MARK: - Layout

    public struct Layout {
        public static let minTouchTarget: CGFloat = 44
        public static let maxFormWidth: CGFloat = 500
        public static let sidebarMinWidth: CGFloat = 220
        public static let sidebarMaxWidth: CGFloat = 300
        public static let toolbarHeight: CGFloat = 52
        public static let statusBarHeight: CGFloat = 32
    }
}

// MARK: - View Modifiers

public extension View {
    /// Apply card style with shadow and background
    func cardStyle() -> some View {
        self
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }

    /// Apply primary button style
    func primaryButtonStyle() -> some View {
        self
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }

    /// Apply secondary button style
    func secondaryButtonStyle() -> some View {
        self
            .buttonStyle(.bordered)
            .controlSize(.large)
    }

    /// Apply hover effect
    func hoverEffect() -> some View {
        self
            .background(AppTheme.Colors.hover)
            .cornerRadius(AppTheme.CornerRadius.small)
    }

    /// Apply glass morphism effect
    func glassMorphism() -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(AppTheme.CornerRadius.large)
            .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
    }

    /// Apply section style
    func sectionStyle() -> some View {
        self
            .padding(AppTheme.Spacing.medium)
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.CornerRadius.medium)
    }

    /// Apply accessibility minimum touch target size
    func accessibleTapTarget() -> some View {
        self.frame(minWidth: AppTheme.Layout.minTouchTarget, minHeight: AppTheme.Layout.minTouchTarget)
    }
}

// MARK: - Shadow Helper

public extension View {
    func shadow(_ shadowStyle: AppTheme.ShadowStyle) -> some View {
        self.shadow(color: shadowStyle.color, radius: shadowStyle.radius, x: shadowStyle.x, y: shadowStyle.y)
    }
}
