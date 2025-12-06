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
