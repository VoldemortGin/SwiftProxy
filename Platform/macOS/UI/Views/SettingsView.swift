import SwiftUI
import SwiftProxyCore
import UniformTypeIdentifiers

/// Application settings and preferences view
/// Manages proxy rules, app preferences, and system configuration
struct SettingsView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedSection: SettingsSection = .general
    @AppStorage("autoStartProxy") private var autoStartProxy = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("logLevel") private var logLevel = "info"
    @AppStorage("maxLogEntries") private var maxLogEntries = 1000

    // MARK: - Body
    var body: some View {
        HSplitView {
            // Sidebar
            settingsSidebar
                .frame(minWidth: 180, maxWidth: 220)

            // Content
            settingsContent
                .frame(minWidth: 400)
        }
    }

    // MARK: - Subviews
    private var settingsSidebar: some View {
        List(selection: $selectedSection) {
            ForEach(SettingsSection.allCases) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.icon)
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch selectedSection {
                case .general:
                    generalSettings
                case .proxy:
                    proxySettings
                case .rules:
                    rulesSettings
                case .network:
                    networkSettings
                case .advanced:
                    advancedSettings
                case .about:
                    aboutSettings
                }
            }
            .padding()
        }
    }

    // MARK: - Settings Sections
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("General", "Customize app behavior and preferences")

            settingsGroup {
                Toggle("Launch at login", isOn: .constant(false))
                    .help("Automatically start SwiftProxy when you log in")

                Toggle("Start proxy automatically", isOn: $autoStartProxy)
                    .help("Enable proxy when the app launches")

                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                    .help("Display SwiftProxy icon in the menu bar")

                Toggle("Enable notifications", isOn: $enableNotifications)
                    .help("Show notifications for important events")
            }

            settingsGroup(title: "Appearance") {
                Picker("Theme", selection: .constant("auto")) {
                    Text("Auto").tag("auto")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var proxySettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Proxy", "Configure proxy behavior and features")

            settingsGroup(title: "Connection") {
                HStack {
                    Text("Connection timeout")
                    Spacer()
                    TextField("", value: .constant(30), format: .number)
                        .frame(width: 60)
                    Text("seconds")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Retry attempts")
                    Spacer()
                    TextField("", value: .constant(3), format: .number)
                        .frame(width: 60)
                }

                Toggle("Auto-reconnect on failure", isOn: .constant(true))
            }

            settingsGroup(title: "DNS") {
                Toggle("Use proxy for DNS requests", isOn: .constant(false))
                    .help("Route DNS queries through the proxy server")

                Toggle("Enable DNS over HTTPS (DoH)", isOn: .constant(false))

                HStack {
                    Text("DNS server")
                    Spacer()
                    TextField("8.8.8.8", text: .constant("8.8.8.8"))
                        .frame(width: 150)
                }
            }
        }
    }

    private var rulesSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Rules", "Manage proxy routing rules")

            HStack {
                Text("No rules configured")
                    .foregroundColor(.secondary)

                Spacer()

                Button("Import Rules") {
                    importRules()
                }

                Button("Add Rule") {
                    // TODO: Show rule editor
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            settingsGroup(title: "Rule Matching") {
                Picker("Default action", selection: .constant("direct")) {
                    Text("Direct").tag("direct")
                    Text("Proxy").tag("proxy")
                    Text("Reject").tag("reject")
                }

                Toggle("Case-sensitive matching", isOn: .constant(false))
                Toggle("Enable wildcard patterns", isOn: .constant(true))
            }
        }
    }

    private var networkSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Network", "Network monitoring and traffic settings")

            settingsGroup(title: "Traffic Capture") {
                Toggle("Capture HTTP traffic", isOn: .constant(true))

                Toggle("Capture HTTPS traffic", isOn: .constant(false))
                    .help("Requires SSL certificate installation")

                Toggle("Capture WebSocket traffic", isOn: .constant(true))

                HStack {
                    Text("Maximum captured requests")
                    Spacer()
                    TextField("", value: .constant(1000), format: .number)
                        .frame(width: 80)
                }
            }

            settingsGroup(title: "Bandwidth") {
                Toggle("Enable bandwidth limiting", isOn: .constant(false))

                HStack {
                    Text("Download limit")
                    Spacer()
                    TextField("", value: .constant(0), format: .number)
                        .frame(width: 80)
                    Text("KB/s")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Upload limit")
                    Spacer()
                    TextField("", value: .constant(0), format: .number)
                        .frame(width: 80)
                    Text("KB/s")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Advanced", "Advanced configuration options")

            settingsGroup(title: "Logging") {
                Picker("Log level", selection: $logLevel) {
                    Text("Debug").tag("debug")
                    Text("Info").tag("info")
                    Text("Warning").tag("warning")
                    Text("Error").tag("error")
                }

                HStack {
                    Text("Maximum log entries")
                    Spacer()
                    TextField("", value: $maxLogEntries, format: .number)
                        .frame(width: 80)
                }

                HStack {
                    Button("View Logs") {
                        openLogs()
                    }

                    Button("Clear Logs") {
                        clearLogs()
                    }
                }
            }

            settingsGroup(title: "Data Management") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cache Size")
                            .font(.subheadline)
                        Text("~24 MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Clear Cache") {
                        clearCache()
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Statistics")
                            .font(.subheadline)
                        Text("\(viewModel.statistics.totalRequests) requests")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Reset Statistics") {
                        resetStatistics()
                    }
                }
            }

            settingsGroup(title: "System") {
                Button("Reset All Settings") {
                    resetAllSettings()
                }
                .foregroundColor(.red)
            }
        }
    }

    private var aboutSettings: some View {
        VStack(alignment: .center, spacing: 20) {
            // App icon
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .padding(.top, 40)

            // App name and version
            VStack(spacing: 8) {
                Text("SwiftProxy")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version 1.0.0 (Build 1)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.horizontal, 40)

            // Description
            Text("A powerful and intuitive macOS proxy manager built with SwiftUI")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Links
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com")!) {
                    Label("GitHub Repository", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com")!) {
                    Label("Documentation", systemImage: "book")
                }

                Link(destination: URL(string: "https://github.com")!) {
                    Label("Report an Issue", systemImage: "exclamationmark.bubble")
                }
            }

            Spacer()

            // Copyright
            Text("© 2024 SwiftProxy. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Views
    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func settingsGroup<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    // MARK: - Methods
    private func importRules() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .text]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // TODO: Import rules from file
                print("Import from \(url)")
            }
        }
    }

    private func openLogs() {
        // TODO: Open logs directory
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: NSHomeDirectory())
    }

    private func clearLogs() {
        let alert = NSAlert()
        alert.messageText = "Clear Logs"
        alert.informativeText = "Are you sure you want to clear all log entries?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // TODO: Clear logs
            print("Logs cleared")
        }
    }

    private func clearCache() {
        // TODO: Clear cache
        print("Cache cleared")
    }

    private func resetStatistics() {
        viewModel.clearRequests()
    }

    private func resetAllSettings() {
        let alert = NSAlert()
        alert.messageText = "Reset All Settings"
        alert.informativeText = "This will reset all settings to their default values. This action cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // TODO: Reset all settings
            autoStartProxy = false
            showMenuBarIcon = true
            enableNotifications = true
            logLevel = "info"
            maxLogEntries = 1000
        }
    }
}

// MARK: - Settings Section
enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case proxy
    case rules
    case network
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .proxy: return "Proxy"
        case .rules: return "Rules"
        case .network: return "Network"
        case .advanced: return "Advanced"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .proxy: return "network"
        case .rules: return "list.bullet.rectangle"
        case .network: return "antenna.radiowaves.left.and.right"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Previews
#Preview("General Settings") {
    SettingsView(viewModel: .preview)
        .frame(width: 800, height: 600)
}

#Preview("About") {
    SettingsView(viewModel: {
        let vm = MainViewModel.preview
        return vm
    }())
    .frame(width: 800, height: 600)
}

#Preview("Dark Mode") {
    SettingsView(viewModel: .preview)
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
}
