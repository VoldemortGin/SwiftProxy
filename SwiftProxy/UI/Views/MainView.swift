import SwiftUI

/// Main application view with tab navigation
/// Coordinates all major app sections
struct MainView: View {
    // MARK: - Properties

    @StateObject private var viewModel: MainViewModel
    @State private var selectedTab: Tab = .proxy

    // MARK: - Initialization

    init(viewModel: MainViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            // Sidebar
            sidebarView
        } detail: {
            // Content
            contentView
        }
        .navigationTitle("SwiftProxy")
        .toolbar {
            toolbarContent
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Subviews

    private var sidebarView: some View {
        List(selection: $selectedTab) {
            Section("Proxy") {
                ForEach(Tab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.icon)
                    }
                }
            }

            Section("Status") {
                HStack {
                    StatusIndicator(
                        status: proxyConnectionStatus,
                        showLabel: false
                    )

                    Text(viewModel.isProxyEnabled ? "Active" : "Inactive")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let config = viewModel.currentConfiguration {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(config.name)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(config.address)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Statistics") {
                statisticsSection
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .proxy:
            ProxyConfigView(viewModel: viewModel)
        case .connections:
            ConnectionListView(viewModel: viewModel)
        case .statistics:
            StatisticsView(viewModel: viewModel)
        case .settings:
            SettingsView(viewModel: viewModel)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button(action: { Task { await viewModel.toggleProxy() } }) {
                Image(systemName: viewModel.isProxyEnabled ? "stop.circle.fill" : "play.circle.fill")
                Text(viewModel.isProxyEnabled ? "Disable" : "Enable")
            }
            .disabled(viewModel.currentConfiguration == nil && !viewModel.isProxyEnabled)

            Divider()

            Button(action: { Task { await viewModel.loadConfigurations() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
    }

    private var statisticsSection: some View {
        Group {
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("Requests")
                    .font(.caption)
                Spacer()
                Text("\(viewModel.statistics.totalRequests)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("Downloaded")
                    .font(.caption)
                Spacer()
                Text(formatBytes(viewModel.statistics.totalBytesIn))
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            HStack {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("Uploaded")
                    .font(.caption)
                Spacer()
                Text(formatBytes(viewModel.statistics.totalBytesOut))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
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

    // MARK: - Helper Methods

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Tab Definition

enum Tab: String, CaseIterable, Identifiable {
    case proxy
    case connections
    case statistics
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .proxy:
            return "Proxy"
        case .connections:
            return "Connections"
        case .statistics:
            return "Statistics"
        case .settings:
            return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .proxy:
            return "network"
        case .connections:
            return "list.bullet"
        case .statistics:
            return "chart.bar"
        case .settings:
            return "gear"
        }
    }
}

// MARK: - Previews

#Preview("Main View") {
    MainView(viewModel: .preview)
        .frame(width: 900, height: 600)
}

#Preview("Dark Mode") {
    MainView(viewModel: .preview)
        .frame(width: 900, height: 600)
        .preferredColorScheme(.dark)
}
