import SwiftUI
import SwiftProxyCore
import UniformTypeIdentifiers
import AppKit

/// Application settings and preferences view
/// Manages proxy rules, app preferences, and system configuration
struct SettingsView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: MainViewModel
    @StateObject private var rulesViewModel: RulesViewModel
    @State private var selectedSection: SettingsSection = .general
    @AppStorage("autoStartProxy") private var autoStartProxy = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("logLevel") private var logLevel = "info"
    @AppStorage("maxLogEntries") private var maxLogEntries = 1000
    @State private var showingResetConfirmation = false
    @State private var showingClearLogsConfirmation = false
    @State private var showingClearCacheConfirmation = false

    // MARK: - Initialization
    init(viewModel: MainViewModel, ruleService: RuleServiceProtocol) {
        self.viewModel = viewModel
        _rulesViewModel = StateObject(wrappedValue: RulesViewModel(ruleService: ruleService))
    }

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
        .confirmationDialog(
            "Clear Logs",
            isPresented: $showingClearLogsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Logs", role: .destructive) {
                performClearLogs()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear all log files? This action cannot be undone.")
        }
        .confirmationDialog(
            "Clear Cache",
            isPresented: $showingClearCacheConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Cache", role: .destructive) {
                performClearCache()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear the cache? This will remove all cached data and may affect performance temporarily.")
        }
        .confirmationDialog(
            "Reset All Settings",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                performResetAllSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset ALL settings to their default values. This action cannot be undone. The app should be restarted after reset.")
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

            // Success/Error messages
            if let successMessage = rulesViewModel.successMessage {
                messageView(successMessage, type: .success)
            }

            if let errorMessage = rulesViewModel.errorMessage {
                messageView(errorMessage, type: .error)
            }

            // Rules list
            settingsGroup(title: "Active Rules (\(rulesViewModel.rules.count))") {
                if rulesViewModel.rules.isEmpty {
                    emptyRulesView
                } else {
                    rulesListView
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: { importRules() }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

                Button(action: { rulesViewModel.exportRules() }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Spacer()

                Button(action: { rulesViewModel.showNewRuleEditor() }) {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $rulesViewModel.showRuleEditor) {
            RuleEditorView(rule: rulesViewModel.editingRule) { rule in
                if rulesViewModel.editingRule != nil {
                    rulesViewModel.updateRule(rule)
                } else {
                    rulesViewModel.saveRule(rule)
                }
            }
        }
    }

    private var emptyRulesView: some View {
        HStack {
            Image(systemName: "list.bullet.rectangle")
                .font(.title)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("No rules configured")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Add rules to control proxy behavior")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private var rulesListView: some View {
        VStack(spacing: 8) {
            ForEach(rulesViewModel.rules.prefix(5)) { rule in
                ruleRowView(rule)
            }

            if rulesViewModel.rules.count > 5 {
                HStack {
                    Text("+ \(rulesViewModel.rules.count - 5) more rules")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
    }

    private func ruleRowView(_ rule: ProxyRule) -> some View {
        HStack(spacing: 12) {
            // Enabled toggle
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { _ in rulesViewModel.toggleRule(rule) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            // Rule info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(rule.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    actionBadge(rule.action)
                }

                Text("\(rule.matchType.rawValue): \(rule.pattern)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button(action: { rulesViewModel.showEditRuleEditor(for: rule) }) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Edit rule")

                Button(action: { rulesViewModel.duplicateRule(rule) }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Duplicate rule")

                Button(action: { rulesViewModel.deleteRule(rule) }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .help("Delete rule")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }

    private func actionBadge(_ action: RuleAction) -> some View {
        Text(action.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(actionColor(action).opacity(0.2))
            )
            .foregroundColor(actionColor(action))
    }

    private func actionColor(_ action: RuleAction) -> Color {
        switch action {
        case .direct:
            return .blue
        case .proxy:
            return .green
        case .reject:
            return .red
        default:
            return .gray
        }
    }

    private func messageView(_ message: String, type: MessageType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: type == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(type == .success ? .green : .orange)

            Text(message)
                .font(.subheadline)

            Spacer()

            Button(action: { rulesViewModel.clearMessages() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((type == .success ? Color.green : Color.orange).opacity(0.1))
        )
    }

    enum MessageType {
        case success
        case error
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
        panel.allowedContentTypes = [
            UTType.json,
            UTType.text,
            UTType(filenameExtension: "conf") ?? UTType.text,
            UTType(filenameExtension: "list") ?? UTType.text
        ]
        panel.allowsMultipleSelection = false
        panel.message = "Select a rule file to import"
        panel.prompt = "Import"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                rulesViewModel.importRules(from: url)
            }
        }
    }

    private func getLogsDirectory() -> URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        let logsDir = appSupport
            .appendingPathComponent("SwiftProxy", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: logsDir.path) {
            try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        }

        return logsDir
    }

    private func openLogs() {
        guard let logsDir = getLogsDirectory() else {
            showAlert(
                title: "Error",
                message: "Could not locate logs directory",
                style: .critical
            )
            return
        }

        // Create logs directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: logsDir.path) {
            do {
                try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
            } catch {
                showAlert(
                    title: "Error",
                    message: "Could not create logs directory: \(error.localizedDescription)",
                    style: .critical
                )
                return
            }
        }

        // Open in Finder
        NSWorkspace.shared.activateFileViewerSelecting([logsDir])
    }

    private func clearLogs() {
        showingClearLogsConfirmation = true
    }

    private func performClearLogs() {
        guard let logsDir = getLogsDirectory() else {
            showAlert(
                title: "Error",
                message: "Could not locate logs directory",
                style: .critical
            )
            return
        }

        do {
            let fileManager = FileManager.default
            let logFiles = try fileManager.contentsOfDirectory(
                at: logsDir,
                includingPropertiesForKeys: nil
            )

            var deletedCount = 0
            for file in logFiles where file.pathExtension == "log" {
                try fileManager.removeItem(at: file)
                deletedCount += 1
            }

            showAlert(
                title: "Success",
                message: "Cleared \(deletedCount) log file(s)",
                style: .informational
            )
        } catch {
            showAlert(
                title: "Error",
                message: "Failed to clear logs: \(error.localizedDescription)",
                style: .critical
            )
        }
    }

    private func clearCache() {
        showingClearCacheConfirmation = true
    }

    private func performClearCache() {
        // Clear temporary files and caches
        do {
            let fileManager = FileManager.default

            // Clear app cache directory
            if let cacheDir = try? fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ).appendingPathComponent("SwiftProxy", isDirectory: true) {

                if fileManager.fileExists(atPath: cacheDir.path) {
                    let cacheFiles = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
                    for file in cacheFiles {
                        try? fileManager.removeItem(at: file)
                    }
                }
            }

            // Clear in-memory caches
            viewModel.cleanupCaches()

            showAlert(
                title: "Success",
                message: "Cache cleared successfully",
                style: .informational
            )
        } catch {
            showAlert(
                title: "Error",
                message: "Failed to clear cache: \(error.localizedDescription)",
                style: .critical
            )
        }
    }

    private func resetStatistics() {
        viewModel.clearRequests()
    }

    private func resetAllSettings() {
        showingResetConfirmation = true
    }

    private func performResetAllSettings() {
        // Reset AppStorage values
        autoStartProxy = false
        showMenuBarIcon = true
        enableNotifications = true
        logLevel = "info"
        maxLogEntries = 1000

        // Clear statistics
        viewModel.clearRequests()

        // Show success message
        showAlert(
            title: "Settings Reset",
            message: "All settings have been reset to default values. Please restart the app for changes to take full effect.",
            style: .informational
        )
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
    SettingsView(viewModel: .preview, ruleService: MockRuleService())
        .frame(width: 800, height: 600)
}

#Preview("About") {
    SettingsView(viewModel: .preview, ruleService: MockRuleService())
        .frame(width: 800, height: 600)
}

#Preview("Dark Mode") {
    SettingsView(viewModel: .preview, ruleService: MockRuleService())
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
}
