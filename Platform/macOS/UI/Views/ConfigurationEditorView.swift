import SwiftUI
import SwiftProxyCore

/// View for creating and editing proxy configurations
struct ConfigurationEditorView: View {
    // MARK: - Properties

    @State private var name: String
    @State private var type: ProxyProtocolType
    @State private var host: String
    @State private var port: String
    @State private var username: String
    @State private var password: String
    @State private var requiresAuth: Bool

    let configuration: ProxyConfiguration?
    let onSave: (ProxyConfiguration) -> Void
    let onCancel: () -> Void

    // MARK: - Initialization

    init(
        configuration: ProxyConfiguration?,
        onSave: @escaping (ProxyConfiguration) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.onSave = onSave
        self.onCancel = onCancel

        _name = State(initialValue: configuration?.name ?? "")
        _type = State(initialValue: configuration?.type ?? .http)
        _host = State(initialValue: configuration?.host ?? "")
        _port = State(initialValue: configuration?.port.description ?? "")
        _username = State(initialValue: configuration?.username ?? "")
        _password = State(initialValue: configuration?.password ?? "")
        _requiresAuth = State(initialValue: configuration?.requiresAuth ?? false)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(configuration == nil ? L10n.configNew : L10n.configEdit)
                    .font(AppTheme.Typography.title2)

                Spacer()

                Button(L10n.actionCancel) {
                    onCancel()
                }
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Basic Information") {
                    TextField(L10n.configName, text: $name)
                        .accessibleButton(label: "Configuration name field")

                    Picker(L10n.configType, selection: $type) {
                        ForEach(ProxyProtocolType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .accessibleButton(label: "Proxy type picker")
                }

                Section("Server") {
                    TextField(L10n.configHost, text: $host)
                        .accessibleButton(label: "Server host field")

                    TextField(L10n.configPort, text: $port)
                        .accessibleButton(label: "Server port field")
                }

                Section("Authentication") {
                    Toggle(L10n.configRequiresAuth, isOn: $requiresAuth)
                        .accessibleToggle(label: "Requires authentication", isOn: requiresAuth)

                    if requiresAuth {
                        TextField(L10n.configUsername, text: $username)
                            .accessibleButton(label: "Username field")

                        SecureField(L10n.configPassword, text: $password)
                            .accessibleButton(label: "Password field")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Spacer()

                Button(L10n.actionCancel) {
                    onCancel()
                }

                Button(L10n.actionSave) {
                    saveConfiguration()
                }
                .primaryButtonStyle()
                .disabled(!isValid)
            }
            .padding()
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !name.isEmpty &&
        !host.isEmpty &&
        Int(port) != nil &&
        (!requiresAuth || !username.isEmpty)
    }

    // MARK: - Methods

    private func saveConfiguration() {
        guard let portInt = Int(port) else { return }

        let config = ProxyConfiguration(
            id: configuration?.id ?? UUID(),
            name: name,
            type: type,
            host: host,
            port: portInt,
            requiresAuth: requiresAuth,
            username: requiresAuth ? username : nil,
            password: requiresAuth ? password : nil
        )

        onSave(config)
    }
}

// MARK: - Preview

#Preview("New Configuration") {
    ConfigurationEditorView(
        configuration: nil,
        onSave: { _ in },
        onCancel: {}
    )
    .frame(width: 500, height: 600)
}

#Preview("Edit Configuration") {
    ConfigurationEditorView(
        configuration: ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080,
            requiresAuth: true,
            username: "user",
            password: "pass"
        ),
        onSave: { _ in },
        onCancel: {}
    )
    .frame(width: 500, height: 600)
}
