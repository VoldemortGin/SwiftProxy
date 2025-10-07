import SwiftUI

/// A visual indicator showing the current proxy connection status
/// Displays a colored dot with animation and status text
struct StatusIndicator: View {
    // MARK: - Properties

    let status: ProxyConnectionStatus
    let showLabel: Bool

    // MARK: - Animation State

    @State private var isAnimating = false

    // MARK: - Initialization

    init(status: ProxyConnectionStatus, showLabel: Bool = true) {
        self.status = status
        self.showLabel = showLabel
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator dot
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 2)
                        .scaleEffect(isAnimating ? 1.5 : 1.0)
                        .opacity(isAnimating ? 0 : 1)
                )
                .shadow(color: statusColor.opacity(0.5), radius: 4)

            if showLabel {
                Text(statusText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: status) { _, _ in
            startAnimation()
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error:
            return "Error"
        }
    }

    // MARK: - Methods

    private func startAnimation() {
        guard status == .connecting else {
            isAnimating = false
            return
        }

        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
            isAnimating = true
        }
    }
}

// MARK: - Supporting Types

enum ProxyConnectionStatus {
    case connected
    case connecting
    case disconnected
    case error
}

// MARK: - Previews

#Preview("All States") {
    VStack(spacing: 20) {
        StatusIndicator(status: .connected)
        StatusIndicator(status: .connecting)
        StatusIndicator(status: .disconnected)
        StatusIndicator(status: .error)

        Divider()

        Text("Without Labels")
            .font(.caption)
            .foregroundColor(.secondary)

        HStack(spacing: 16) {
            StatusIndicator(status: .connected, showLabel: false)
            StatusIndicator(status: .connecting, showLabel: false)
            StatusIndicator(status: .disconnected, showLabel: false)
            StatusIndicator(status: .error, showLabel: false)
        }
    }
    .padding()
    .frame(width: 300)
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        StatusIndicator(status: .connected)
        StatusIndicator(status: .connecting)
        StatusIndicator(status: .disconnected)
        StatusIndicator(status: .error)
    }
    .padding()
    .preferredColorScheme(.dark)
}
