import SwiftUI

// MARK: - View Extensions

extension View {
    /// Applies a card-like appearance to the view
    func cardStyle(
        backgroundColor: Color = Color(nsColor: .controlBackgroundColor),
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 0
    ) -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .shadow(radius: shadowRadius)
            )
    }

    /// Conditionally applies a modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies a help tooltip
    func help(_ text: String) -> some View {
        self.help(Text(text))
    }
}

// MARK: - Color Extensions

extension Color {
    /// App-specific semantic colors
    static let proxyEnabled = Color.green
    static let proxyDisabled = Color.gray
    static let proxyError = Color.red
    static let proxyConnecting = Color.yellow

    /// Status code colors
    static func httpStatusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300:
            return .green
        case 300..<400:
            return .blue
        case 400..<500:
            return .orange
        case 500..<600:
            return .red
        default:
            return .gray
        }
    }

    /// Method colors
    static func httpMethodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .GET:
            return .blue
        case .POST:
            return .green
        case .PUT:
            return .orange
        case .DELETE:
            return .red
        case .PATCH:
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - TextField Styles

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Button Styles

struct ProminentButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Custom Modifiers

struct LoadingModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
            }
        }
    }
}

extension View {
    func loading(_ isLoading: Bool) -> some View {
        modifier(LoadingModifier(isLoading: isLoading))
    }
}

// MARK: - Shake Animation

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
                y: 0
            )
        )
    }
}

extension View {
    func shake(times: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(times)))
    }
}

// MARK: - Placeholder Modifier

struct PlaceholderModifier<Placeholder: View>: ViewModifier {
    let show: Bool
    let placeholder: Placeholder

    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            if show {
                placeholder
                    .foregroundColor(.secondary)
            }
            content
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when show: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        modifier(PlaceholderModifier(show: show, placeholder: placeholder()))
    }
}

// MARK: - Number Formatters

extension Int64 {
    func formatAsBytes() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: self)
    }
}

extension Int {
    func formatAsNumber() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension TimeInterval {
    func formatAsLatency() -> String {
        String(format: "%.0f ms", self * 1000)
    }
}

// MARK: - Date Formatters

extension Date {
    func formatAsRelativeTime() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    func formatAsTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: self)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)?
    var actionLabel: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Loading View

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Error")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let retry = retry {
                Button(action: retry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Divider with Label

struct LabeledDivider: View {
    let label: String

    var body: some View {
        HStack {
            VStack {
                Divider()
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)

            VStack {
                Divider()
            }
        }
    }
}

// MARK: - Badge View

struct BadgeView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

// MARK: - Previews

#Preview("Empty State") {
    EmptyStateView(
        icon: "network.slash",
        title: "No Data",
        subtitle: "There is no data to display at this time",
        action: {},
        actionLabel: "Refresh"
    )
    .frame(width: 400, height: 300)
}

#Preview("Loading") {
    LoadingView(message: "Loading data...")
        .frame(width: 400, height: 300)
}

#Preview("Error") {
    ErrorView(
        error: "Failed to connect to the server. Please check your internet connection.",
        retry: {}
    )
    .frame(width: 400, height: 300)
}

#Preview("Badges") {
    HStack(spacing: 8) {
        BadgeView(text: "GET", color: .blue)
        BadgeView(text: "200", color: .green)
        BadgeView(text: "POST", color: .orange)
        BadgeView(text: "404", color: .red)
    }
    .padding()
}
