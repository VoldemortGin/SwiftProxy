import SwiftUI
import OSLog
import SwiftProxyCore

// Note: This is a simplified prototype version - @main is disabled in favor of SwiftProxyApp
// @main
struct SimpleSwiftProxyApp: App {
    @StateObject private var viewModel = SimpleProxyViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About SwiftProxy") {
                    viewModel.showAbout = true
                }
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: SimpleProxyViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()

            Divider()

            // Main Content
            HSplitView {
                // Sidebar
                SidebarView()
                    .frame(minWidth: 200, maxWidth: 300)

                // Detail View
                DetailView()
                    .frame(minWidth: 500)
            }
        }
        .sheet(isPresented: $viewModel.showAbout) {
            AboutView()
        }
    }
}

struct HeaderView: View {
    @EnvironmentObject var viewModel: SimpleProxyViewModel

    var body: some View {
        HStack {
            Image(systemName: "network")
                .font(.title)
                .foregroundColor(.blue)

            Text("SwiftProxy")
                .font(.title)
                .fontWeight(.bold)

            Spacer()

            // Status Indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isProxyEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(viewModel.isProxyEnabled ? "Active" : "Inactive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Proxy Toggle
            Toggle("", isOn: $viewModel.isProxyEnabled)
                .toggleStyle(SwitchToggleStyle())
                .onChange(of: viewModel.isProxyEnabled) { newValue in
                    viewModel.toggleProxy(newValue)
                }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct SidebarView: View {
    @EnvironmentObject var viewModel: SimpleProxyViewModel
    @State private var selectedSection = "Dashboard"

    var body: some View {
        List {
            Section("Navigation") {
                SidebarItem(title: "Dashboard", icon: "chart.bar", isSelected: selectedSection == "Dashboard") {
                    selectedSection = "Dashboard"
                    viewModel.selectedView = .dashboard
                }

                SidebarItem(title: "Connections", icon: "network", isSelected: selectedSection == "Connections") {
                    selectedSection = "Connections"
                    viewModel.selectedView = .connections
                }

                SidebarItem(title: "Configuration", icon: "gearshape", isSelected: selectedSection == "Configuration") {
                    selectedSection = "Configuration"
                    viewModel.selectedView = .configuration
                }

                SidebarItem(title: "Statistics", icon: "chart.line.uptrend.xyaxis", isSelected: selectedSection == "Statistics") {
                    selectedSection = "Statistics"
                    viewModel.selectedView = .statistics
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DetailView: View {
    @EnvironmentObject var viewModel: SimpleProxyViewModel

    var body: some View {
        Group {
            switch viewModel.selectedView {
            case .dashboard:
                DashboardView()
            case .connections:
                ConnectionsView()
            case .configuration:
                SimpleConfigurationView()
            case .statistics:
                SimpleStatisticsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DashboardView: View {
    @EnvironmentObject var viewModel: SimpleProxyViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Dashboard")
                    .font(.largeTitle)
                    .padding(.bottom)

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    StatCard(title: "Total Connections", value: "\(viewModel.totalConnections)", icon: "network", color: .blue)
                    StatCard(title: "Data Transferred", value: viewModel.formattedDataTransferred, icon: "arrow.up.arrow.down", color: .green)
                    StatCard(title: "Active Rules", value: "\(viewModel.activeRules)", icon: "checklist", color: .orange)
                    StatCard(title: "Uptime", value: viewModel.uptime, icon: "clock", color: .purple)
                }

                // Recent Activity
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Activity")
                            .font(.headline)

                        ForEach(viewModel.recentActivities, id: \.self) { activity in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.green)
                                Text(activity)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                    .padding(8)
                }
            }
            .padding()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(8)
        }
    }
}

struct ConnectionsView: View {
    @EnvironmentObject var viewModel: SimpleProxyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Active Connections")
                    .font(.largeTitle)
                Spacer()
                Text("\(viewModel.connections.count) connections")
                    .foregroundColor(.secondary)
            }
            .padding()

            // Connections Table
            Table(viewModel.connections) {
                TableColumn("Process") { connection in
                    Text(connection.process)
                }
                TableColumn("Host") { connection in
                    Text(connection.host)
                        .font(.system(.body, design: .monospaced))
                }
                TableColumn("Port") { connection in
                    Text("\(connection.port)")
                }
                TableColumn("Status") { connection in
                    HStack {
                        Circle()
                            .fill(connection.isActive ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(connection.status)
                            .font(.caption)
                    }
                }
                TableColumn("Data") { connection in
                    Text(connection.dataTransferred)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct SimpleConfigurationView: View {
    @EnvironmentObject var viewModel: SimpleProxyViewModel
    @State private var proxyPort = "8888"
    @State private var selectedProtocol = "HTTP"
    @State private var enableAuth = false
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        Form {
            Text("Proxy Configuration")
                .font(.largeTitle)
                .padding(.bottom)

            Section("Basic Settings") {
                HStack {
                    Text("Proxy Port:")
                    TextField("Port", text: $proxyPort)
                        .frame(width: 100)
                }

                Picker("Protocol:", selection: $selectedProtocol) {
                    Text("HTTP").tag("HTTP")
                    Text("SOCKS5").tag("SOCKS5")
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section("Authentication") {
                Toggle("Enable Authentication", isOn: $enableAuth)

                if enableAuth {
                    HStack {
                        Text("Username:")
                        TextField("Username", text: $username)
                    }

                    HStack {
                        Text("Password:")
                        SecureField("Password", text: $password)
                    }
                }
            }

            Section("Rules") {
                Text("Proxy Rules")
                    .font(.headline)

                List {
                    ForEach(viewModel.rules, id: \.self) { rule in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(rule)
                            Spacer()
                        }
                    }
                }
                .frame(height: 150)
            }

            HStack {
                Button("Save Configuration") {
                    viewModel.saveConfiguration(port: proxyPort, protocol: selectedProtocol)
                }
                .buttonStyle(.borderedProminent)

                Button("Reset") {
                    proxyPort = "8888"
                    selectedProtocol = "HTTP"
                    enableAuth = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: 600)
    }
}

struct SimpleStatisticsView: View {
    @EnvironmentObject var viewModel: SimpleProxyViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Statistics")
                    .font(.largeTitle)

                // Mock Chart
                GroupBox("Traffic Over Time") {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 200)

                        VStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 50))
                                .foregroundColor(.blue.opacity(0.5))
                            Text("Chart visualization would appear here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Statistics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    StatBox(label: "Total Requests", value: "12,543")
                    StatBox(label: "Blocked", value: "234")
                    StatBox(label: "Success Rate", value: "98.2%")
                    StatBox(label: "Avg Response", value: "45ms")
                    StatBox(label: "Peak Traffic", value: "2.3 MB/s")
                    StatBox(label: "Total Data", value: "1.2 GB")
                }
            }
            .padding()
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("SwiftProxy")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Text("A powerful network proxy application for macOS")
                .multilineTextAlignment(.center)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(width: 400)
    }
}

// Simple View Model
class SimpleProxyViewModel: ObservableObject {
    @Published var isProxyEnabled = false
    @Published var selectedView = ViewType.dashboard
    @Published var showAbout = false
    @Published var totalConnections = 42
    @Published var activeRules = 5
    @Published var connections: [ConnectionInfo] = []
    @Published var rules = ["Block ads", "Allow local network", "HTTPS only", "Block tracking"]
    @Published var recentActivities = [
        "Proxy started on port 8888",
        "Connection from Chrome established",
        "Blocked tracking request to analytics.com",
        "New rule added: Block ads",
        "Connection closed: Safari"
    ]

    var formattedDataTransferred: String {
        "256 MB"
    }

    var uptime: String {
        "2h 34m"
    }

    init() {
        // Generate mock connections
        connections = [
            ConnectionInfo(process: "Chrome", host: "google.com", port: 443, status: "Connected", isActive: true, dataTransferred: "12.5 MB"),
            ConnectionInfo(process: "Safari", host: "apple.com", port: 443, status: "Connected", isActive: true, dataTransferred: "5.2 MB"),
            ConnectionInfo(process: "Slack", host: "slack.com", port: 443, status: "Connected", isActive: true, dataTransferred: "8.7 MB"),
            ConnectionInfo(process: "Terminal", host: "github.com", port: 22, status: "Idle", isActive: false, dataTransferred: "1.1 MB"),
        ]
    }

    func toggleProxy(_ enabled: Bool) {
        // Mock proxy toggle
        if enabled {
            os_log(.info, log: Logger.proxyLog, "Proxy enabled on port 8888")
        } else {
            os_log(.info, log: Logger.proxyLog, "Proxy disabled")
        }
    }

    func saveConfiguration(port: String, protocol: String) {
        os_log(.info, log: Logger.storageLog, "Configuration saved: Port %@, Protocol %@", port, `protocol`)
    }

    enum ViewType {
        case dashboard
        case connections
        case configuration
        case statistics
    }
}

struct ConnectionInfo: Identifiable {
    let id = UUID()
    let process: String
    let host: String
    let port: Int
    let status: String
    let isActive: Bool
    let dataTransferred: String
}