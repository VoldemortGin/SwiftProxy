import SwiftUI
import SwiftProxyCore

/// View for managing proxy configurations
/// Allows creating, editing, and testing proxy servers
struct ProxyConfigView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedConfiguration: ProxyConfiguration?
    @State private var showingEditor = false
    @State private var editingConfiguration: ProxyConfiguration?
    @State private var testResult: ConnectionTestResult?
    @State private var isTesting = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Proxy toggle
            ProxyToggle(
                isEnabled: $viewModel.isProxyEnabled,
                configuration: viewModel.currentConfiguration,
                onToggle: { Task { await viewModel.toggleProxy() } }
            )
            .padding()

            Divider()

            // Configuration list
            configurationsSection
        }
        .sheet(isPresented: $showingEditor) {
            configurationEditor
        }
    }

    // MARK: - Subviews
    private var configurationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Saved Configurations")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: createNewConfiguration) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.top)

            // List
            if viewModel.savedConfigurations.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.savedConfigurations) { config in
                            configurationRow(config)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Proxy Configurations")
                .font(.headline)

            Text("Add your first proxy configuration to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: createNewConfiguration) {
                Label("Add Configuration", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func configurationRow(_ config: ProxyConfiguration) -> some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: config.type.systemImageName)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(config.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(config.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(config.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.2))
                        )

                    if config.requiresAuth {
                        Image(systemName: "key.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                // Test button
                Button(action: { testConfiguration(config) }) {
                    Image(systemName: "network")
                }
                .buttonStyle(.borderless)
                .help("Test Connection")
                .disabled(isTesting)

                // Edit button
                Button(action: { editConfiguration(config) }) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit")

                // Delete button
                Button(action: { deleteConfiguration(config) }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .help("Delete")

                // Use button
                Button(action: { useConfiguration(config) }) {
                    Image(systemName: viewModel.currentConfiguration?.id == config.id ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.borderless)
                .help(viewModel.currentConfiguration?.id == config.id ? "Currently Active" : "Use This Configuration")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.currentConfiguration?.id == config.id ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
    }

    private var configurationEditor: some View {
        NavigationStack {
            ConfigurationEditorView(
                configuration: editingConfiguration,
                onSave: { config in
                    Task {
                        await viewModel.saveConfiguration(config)
                        showingEditor = false
                        editingConfiguration = nil
                    }
                },
                onCancel: {
                    showingEditor = false
                    editingConfiguration = nil
                }
            )
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    // MARK: - Methods
    private func createNewConfiguration() {
        editingConfiguration = nil
        showingEditor = true
    }

    private func editConfiguration(_ config: ProxyConfiguration) {
        editingConfiguration = config
        showingEditor = true
    }

    private func deleteConfiguration(_ config: ProxyConfiguration) {
        Task {
            await viewModel.deleteConfiguration(config)
        }
    }

    private func useConfiguration(_ config: ProxyConfiguration) {
        Task {
            if viewModel.isProxyEnabled {
                await viewModel.disableProxy()
            }
            await viewModel.enableProxy(configuration: config)
        }
    }

    private func testConfiguration(_ config: ProxyConfiguration) {
        isTesting = true
        Task {
            testResult = await viewModel.testConfiguration(config)
            isTesting = false

            // Show result alert
            if let result = testResult {
                showTestResult(result)
            }
        }
    }

    private func showTestResult(_ result: ConnectionTestResult) {
        let alert = NSAlert()
        alert.messageText = result.success ? "Connection Successful" : "Connection Failed"

        if result.success {
            alert.informativeText = "Latency: \(String(format: "%.0f", (result.latency ?? 0) * 1000))ms"
            alert.alertStyle = .informational
        } else {
            alert.informativeText = result.error?.errorDescription ?? "Unknown error"
            alert.alertStyle = .warning
        }

        alert.runModal()
    }
}

// MARK: - Configuration Editor
struct ConfigurationEditorView: View {
    let configuration: ProxyConfiguration?
    let onSave: (ProxyConfiguration) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var selectedType: ProxyProtocolType = .http
    @State private var host = ""
    @State private var port = ""
    @State private var requiresAuth = false
    @State private var username = ""
    @State private var password = ""
    @State private var bypassDomains = ""
    @State private var proxyDNS = false
    @State private var notes = ""
    @State private var validationError: String?

    var body: some View {
        Form {
            Section("Basic Information") {
                TextField("Name", text: $name)

                Picker("Type", selection: $selectedType) {
                    ForEach(ProxyProtocolType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }

            Section("Server Details") {
                TextField("Host", text: $host)
                    .help("IP address or domain name")

                TextField("Port", text: $port)
                    .help("Port number (1-65535)")
                    .onChange(of: port) { _, newValue in
                        port = newValue.filter { $0.isNumber }
                    }
            }

            Section("Authentication") {
                Toggle("Requires Authentication", isOn: $requiresAuth)

                if requiresAuth {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                }
            }

            Section("Advanced") {
                TextField("Bypass Domains", text: $bypassDomains)
                    .help("Comma-separated list of domains to bypass")

                Toggle("Proxy DNS Requests", isOn: $proxyDNS)

                TextField("Notes (Optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
            }

            if let error = validationError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(configuration == nil ? "New Configuration" : "Edit Configuration")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveConfiguration)
            }
        }
        .onAppear {
            loadConfiguration()
        }
    }

    private func loadConfiguration() {
        guard let config = configuration else {
            port = String(ProxyProtocolType.http.defaultPort)
            return
        }

        name = config.name
        selectedType = config.type
        host = config.host
        port = String(config.port)
        requiresAuth = config.requiresAuth
        username = config.username ?? ""
        password = config.password ?? ""
        bypassDomains = config.bypassDomains.joined(separator: ", ")
        proxyDNS = config.proxyDNS
        notes = config.notes ?? ""
    }

    private func saveConfiguration() {
        validationError = nil

        // Validation
        guard !name.isEmpty else {
            validationError = "Name is required"
            return
        }

        guard !host.isEmpty else {
            validationError = "Host is required"
            return
        }

        guard let portNumber = Int(port), (1...65535).contains(portNumber) else {
            validationError = "Port must be between 1 and 65535"
            return
        }

        if requiresAuth {
            guard !username.isEmpty else {
                validationError = "Username is required for authentication"
                return
            }

            guard !password.isEmpty else {
                validationError = "Password is required for authentication"
                return
            }
        }

        // Create configuration
        let bypass = bypassDomains
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let config = ProxyConfiguration(
            id: configuration?.id ?? UUID(),
            name: name,
            type: selectedType,
            host: host,
            port: portNumber,
            requiresAuth: requiresAuth,
            username: requiresAuth ? username : nil,
            password: requiresAuth ? password : nil,
            bypassDomains: bypass,
            proxyDNS: proxyDNS,
            notes: notes.isEmpty ? nil : notes
        )

        // Validate
        let validation = config.validate()
        guard validation.isValid else {
            validationError = validation.errorMessage
            return
        }

        onSave(config)
    }
}

// MARK: - Previews
#Preview("With Configurations") {
    ProxyConfigView(viewModel: .preview)
        .frame(width: 700, height: 800)
}

#Preview("Empty State") {
    let vm = MainViewModel.preview
    return ProxyConfigView(viewModel: vm)
        .frame(width: 700, height: 800)
}

#Preview("Dark Mode") {
    ProxyConfigView(viewModel: .preview)
        .frame(width: 700, height: 800)
        .preferredColorScheme(.dark)
}
