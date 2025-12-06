import SwiftUI
import SwiftProxyCore

/// Quick status popover shown from menu bar
/// Displays proxy status, current configuration, and quick actions
struct QuickStatusPopover: View {
    // MARK: - Properties

    @ObservedObject var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            headerSection

            Divider()

            // Current configuration
            if let config = viewModel.currentConfiguration {
                configurationSection(config)
                Divider()
            }

            // Statistics
            statisticsSection

            Divider()

            // Quick actions
            actionsSection
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 12) {
            // Status indicator
            StatusIndicator(status: proxyConnectionStatus, showLabel: false)
                .scaleEffect(1.2)

            VStack(alignment: .leading, spacing: 2) {
                Text("SwiftProxy")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(16)
    }

    // MARK: - Configuration Section

    private func configurationSection(_ config: ProxyConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: config.type.systemImageName)
                    .foregroundColor(.accentColor)
                Text(config.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Type:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(config.type.displayName)
                        .font(.caption)
                }

                HStack {
                    Text("Address:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(config.address)
                        .font(.caption)
                        .fontDesign(.monospaced)
                }

                if config.requiresAuth {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Authenticated")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(spacing: 8) {
            HStack {
                statisticItem(
                    icon: "arrow.up.arrow.down",
                    label: "Requests",
                    value: "\(viewModel.statistics.totalRequests)",
                    color: .blue
                )

                Divider()

                statisticItem(
                    icon: "arrow.down.circle",
                    label: "Downloaded",
                    value: formatBytes(viewModel.statistics.totalBytesIn),
                    color: .green
                )
            }

            Divider()

            HStack {
                statisticItem(
                    icon: "arrow.up.circle",
                    label: "Uploaded",
                    value: formatBytes(viewModel.statistics.totalBytesOut),
                    color: .orange
                )

                Divider()

                statisticItem(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Avg Speed",
                    value: formatSpeed(avgSpeed),
                    color: .purple
                )
            }
        }
        .padding(16)
    }

    private func statisticItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            Text(value)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 8) {
            // Toggle proxy button
            Button(action: {
                Task {
                    await viewModel.toggleProxy()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.isProxyEnabled ? "stop.circle.fill" : "play.circle.fill")
                        .foregroundColor(viewModel.isProxyEnabled ? .red : .green)
                    Text(viewModel.isProxyEnabled ? "Disable Proxy" : "Enable Proxy")
                        .fontWeight(.medium)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentConfiguration == nil && !viewModel.isProxyEnabled)

            Divider()

            // Secondary actions
            HStack(spacing: 8) {
                // Open main window
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.title == "SwiftProxy" }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "app.fill")
                        Text("Open")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // Open settings
                Button(action: {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    // MARK: - Computed Properties

    private var proxyConnectionStatus: ProxyConnectionStatus {
        switch viewModel.proxyStatus {
        case .enabled:
            return .connected
        case .enabling, .disabling:
            return .connecting
        case .disabled:
            return .disconnected
        case .error:
            return .error
        }
    }

    private var statusText: String {
        switch viewModel.proxyStatus {
        case .enabled:
            return "Proxy Active"
        case .enabling:
            return "Starting..."
        case .disabling:
            return "Stopping..."
        case .disabled:
            return "Proxy Inactive"
        case .error:
            return "Error"
        }
    }

    private var avgSpeed: Double {
        let totalBytes = viewModel.statistics.totalBytesIn + viewModel.statistics.totalBytesOut
        guard viewModel.statistics.totalRequests > 0 else { return 0 }
        return Double(totalBytes) / Double(viewModel.statistics.totalRequests)
    }

    // MARK: - Helper Methods

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }

    private func formatSpeed(_ bytesPerRequest: Double) -> String {
        if bytesPerRequest < 1024 {
            return String(format: "%.0f B", bytesPerRequest)
        } else if bytesPerRequest < 1024 * 1024 {
            return String(format: "%.1f KB", bytesPerRequest / 1024)
        } else {
            return String(format: "%.1f MB", bytesPerRequest / (1024 * 1024))
        }
    }
}

// MARK: - Previews

#Preview("Active") {
    let viewModel = MainViewModel.preview
    viewModel.isProxyEnabled = true
    viewModel.currentConfiguration = .presets[0]
    return QuickStatusPopover(viewModel: viewModel)
        .frame(width: 320, height: 400)
}

#Preview("Inactive") {
    let viewModel = MainViewModel.preview
    return QuickStatusPopover(viewModel: viewModel)
        .frame(width: 320, height: 300)
}
