import Foundation
import SwiftProxyCore
import Combine
import SwiftUI
import OSLog

/// View model for proxy management
/// Coordinates between proxy service, configuration service, and UI
/// Implements MVVM pattern with Combine for reactive updates
@MainActor
public final class ProxyViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var currentConfiguration: ProxyConfiguration?
    @Published public private(set) var status: ProxyStatus = .disabled
    @Published public private(set) var configurations: [ProxyConfiguration] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: AppError?

    // Test connection state
    @Published public private(set) var testResult: ConnectionTestResult?
    @Published public private(set) var isTesting: Bool = false

    // Network status
    @Published public private(set) var networkStatus: NetworkStatus = .unknown
    @Published public private(set) var isNetworkAvailable: Bool = false

    // MARK: - Dependencies
    private let proxyService: ProxyServiceProtocol
    private let configService: ConfigurationServiceProtocol
    private let networkMonitor: NetworkMonitor
    private let logger: OSLog
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    public init(
        proxyService: ProxyServiceProtocol,
        configService: ConfigurationServiceProtocol,
        networkMonitor: NetworkMonitor,
        logger: OSLog = Logger.proxyLog
    ) {
        self.proxyService = proxyService
        self.configService = configService
        self.networkMonitor = networkMonitor
        self.logger = logger

        setupBindings()
        startNetworkMonitoring()

        // Load initial data
        Task {
            await loadData()
        }
    }

    // MARK: - Public Methods

    /// Enable proxy with the specified configuration
    public func enableProxy(configuration: ProxyConfiguration) async {
        isLoading = true
        error = nil

        do {
            os_log(.info, log: logger, "Enabling proxy: %@", configuration.name)
            try await proxyService.enable(configuration: configuration)
            try await configService.setActiveConfiguration(configuration)
            os_log(.info, log: logger, "Proxy enabled successfully")
        } catch let appError as AppError {
            os_log(.error, log: logger, "Failed to enable proxy: %@", appError.errorDescription ?? "Unknown error")
            error = appError
        } catch {
            os_log(.error, log: logger, "Failed to enable proxy: %@", error.localizedDescription)
            self.error = .unknown(error)
        }

        isLoading = false
    }

    /// Disable the current proxy
    public func disableProxy() async {
        do {
            os_log(.info, log: logger, "Disabling proxy")
            try await proxyService.disable()
            try await configService.setActiveConfiguration(nil)
            os_log(.info, log: logger, "Proxy disabled successfully")
        } catch let appError as AppError {
            os_log(.error, log: logger, "Failed to disable proxy: %@", appError.errorDescription ?? "Unknown error")
            error = appError
        } catch {
            os_log(.error, log: logger, "Failed to disable proxy: %@", error.localizedDescription)
            self.error = .unknown(error)
        }
    }

    /// Toggle proxy on/off
    public func toggleProxy() async {
        if isEnabled {
            await disableProxy()
        } else if let config = currentConfiguration {
            await enableProxy(configuration: config)
        } else if let firstConfig = configurations.first {
            await enableProxy(configuration: firstConfig)
        } else {
            error = .proxyConfigurationInvalid("No configuration available")
        }
    }

    /// Save a new or updated configuration
    public func saveConfiguration(_ configuration: ProxyConfiguration) async {
        do {
            try await configService.saveConfiguration(configuration)
            await loadConfigurations()
            os_log(.info, log: logger, "Configuration saved: %@", configuration.name)
        } catch {
            os_log(.error, log: logger, "Failed to save configuration: %@", error.localizedDescription)
            self.error = .storageWriteFailed(error.localizedDescription)
        }
    }

    /// Delete a configuration
    public func deleteConfiguration(id: UUID) async {
        do {
            try await configService.deleteConfiguration(id: id)
            os_log(.info, log: logger, "Configuration deleted: %@", id.uuidString)
        } catch {
            os_log(.error, log: logger, "Failed to delete configuration: %@", error.localizedDescription)
            self.error = .storageWriteFailed(error.localizedDescription)
        }
    }

    /// Test connection to a proxy configuration
    public func testConnection(_ configuration: ProxyConfiguration) async {
        isTesting = true
        testResult = nil

        do {
            os_log(.info, log: logger, "Testing connection: %@", configuration.name)
            let result = try await proxyService.testConnection(configuration: configuration)
            testResult = result

            if result.success {
                os_log(.info, log: logger, "Connection test successful (latency: %.2fms)",
                       (result.latency ?? 0) * 1000)
            } else {
                os_log(.error, log: logger, "Connection test failed: %@",
                       result.error?.errorDescription ?? "Unknown error")
            }
        } catch let appError as AppError {
            testResult = ConnectionTestResult(success: false, error: appError)
        } catch {
            testResult = ConnectionTestResult(success: false, error: .unknown(error))
        }

        isTesting = false
    }

    /// Load all configurations
    public func loadConfigurations() async {
        do {
            let configs = try await configService.loadConfigurations()
            configurations = configs.sorted { $0.name < $1.name }
        } catch {
            os_log(.error, log: logger, "Failed to load configurations: %@", error.localizedDescription)
            self.error = .storageReadFailed(error.localizedDescription)
        }
    }

    /// Refresh all data
    public func refresh() async {
        await loadData()
    }

    /// Clear error state
    public func clearError() {
        error = nil
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Bind proxy service state
        proxyService.isEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: &$isEnabled)

        proxyService.currentConfiguration
            .assign(to: &$currentConfiguration)

        proxyService.proxyStatus
            .assign(to: &$status)

        // Bind configuration service state
        configService.configurations
            .sink { [weak self] configs in
                self?.configurations = configs.sorted { $0.name < $1.name }
            }
            .store(in: &cancellables)

        // Bind network monitor state
        networkMonitor.statusPublisher
            .assign(to: &$networkStatus)

        networkMonitor.$isConnected
            .assign(to: &$isNetworkAvailable)
    }

    private func startNetworkMonitoring() {
        networkMonitor.startMonitoring()
    }

    private func loadData() async {
        // Load configurations
        await loadConfigurations()

        // Check current system proxy state
        do {
            let systemProxy = try await proxyService.getCurrentSystemProxy()
            if systemProxy.isAnyProxyEnabled {
                os_log(.info, log: logger, "System proxy is currently enabled")
            }
        } catch {
            os_log(.error, log: logger, "Failed to check system proxy: %@", error.localizedDescription)
        }
    }
}

// MARK: - Convenience Computed Properties

extension ProxyViewModel {
    /// Whether proxy can be toggled
    public var canToggleProxy: Bool {
        !isLoading && isNetworkAvailable && (!configurations.isEmpty || isEnabled)
    }

    /// Status description for UI display
    public var statusDescription: String {
        switch status {
        case .disabled:
            return "Disabled"
        case .enabling:
            return "Enabling..."
        case .enabled(let config):
            return "Connected to \(config.name)"
        case .disabling:
            return "Disabling..."
        case .error(let error):
            return "Error: \(error.errorDescription ?? "Unknown")"
        }
    }

    /// Status color for UI display
    public var statusColor: Color {
        switch status {
        case .disabled:
            return .gray
        case .enabling, .disabling:
            return .orange
        case .enabled:
            return .green
        case .error:
            return .red
        }
    }

    /// Whether there are any saved configurations
    public var hasConfigurations: Bool {
        !configurations.isEmpty
    }

    /// Network status description
    public var networkStatusDescription: String {
        networkStatus.displayName
    }
}

// MARK: - Configuration Management Helpers

extension ProxyViewModel {
    /// Create a new configuration with defaults
    public func createNewConfiguration() -> ProxyConfiguration {
        ProxyConfiguration(
            name: "New Proxy",
            type: .http,
            host: "",
            port: 8080,
            notes: "New proxy configuration"
        )
    }

    /// Duplicate an existing configuration
    public func duplicateConfiguration(_ configuration: ProxyConfiguration) async {
        var duplicate = configuration.copy()
        duplicate.name = "\(configuration.name) Copy"
        await saveConfiguration(duplicate)
    }

    /// Quick enable for a specific configuration
    public func quickEnable(_ configuration: ProxyConfiguration) async {
        if currentConfiguration?.id == configuration.id && isEnabled {
            // Already enabled, do nothing
            return
        }
        await enableProxy(configuration: configuration)
    }
}
