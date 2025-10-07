import SwiftUI

/// A prominent toggle control for enabling/disabling the proxy
/// Features smooth animations and visual feedback
struct ProxyToggle: View {
    // MARK: - Properties

    @Binding var isEnabled: Bool
    let configuration: ProxyConfiguration?
    let onToggle: () -> Void

    @State private var isProcessing = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Main toggle button
            Button(action: handleToggle) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: isEnabled ? [Color.green.opacity(0.8), Color.green] : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: isEnabled ? .green.opacity(0.3) : .clear, radius: 8, y: 4)

                    // Content
                    VStack(spacing: 12) {
                        // Icon
                        Image(systemName: isEnabled ? "lock.shield.fill" : "lock.shield")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                            .symbolEffect(.bounce, value: isEnabled)

                        // Status text
                        Text(isEnabled ? "Proxy Enabled" : "Proxy Disabled")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        // Configuration name
                        if let config = configuration {
                            Text(config.name)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.vertical, 24)

                    // Processing overlay
                    if isProcessing {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.3))

                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(height: 180)
            .disabled(isProcessing || configuration == nil)

            // Configuration details
            if let config = configuration {
                configurationInfo(config)
            } else {
                noConfigurationView
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEnabled)
        .animation(.easeInOut, value: isProcessing)
    }

    // MARK: - Subviews

    private func configurationInfo(_ config: ProxyConfiguration) -> some View {
        HStack(spacing: 12) {
            Image(systemName: config.type.systemImageName)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(config.address)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(config.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if config.requiresAuth {
                Image(systemName: "key.fill")
                    .foregroundColor(.secondary)
                    .help("Authentication required")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var noConfigurationView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text("No proxy configuration selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }

    // MARK: - Methods

    private func handleToggle() {
        guard !isProcessing else { return }

        isProcessing = true

        Task {
            onToggle()

            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second

            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

// MARK: - Previews

#Preview("Enabled") {
    ProxyToggle(
        isEnabled: .constant(true),
        configuration: ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "127.0.0.1",
            port: 8080,
            requiresAuth: true
        ),
        onToggle: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("Disabled") {
    ProxyToggle(
        isEnabled: .constant(false),
        configuration: ProxyConfiguration(
            name: "Test Proxy",
            type: .socks5,
            host: "proxy.example.com",
            port: 1080
        ),
        onToggle: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("No Configuration") {
    ProxyToggle(
        isEnabled: .constant(false),
        configuration: nil,
        onToggle: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("Dark Mode") {
    ProxyToggle(
        isEnabled: .constant(true),
        configuration: ProxyConfiguration(
            name: "Secure Proxy",
            type: .https,
            host: "secure.proxy.com",
            port: 8443
        ),
        onToggle: {}
    )
    .padding()
    .frame(width: 400)
    .preferredColorScheme(.dark)
}
