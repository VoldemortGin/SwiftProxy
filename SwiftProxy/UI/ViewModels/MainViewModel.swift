import Foundation
import Combine
import OSLog

/// Main view model coordinating app-wide state and proxy operations
/// Manages proxy service, configurations, and network monitoring
@MainActor
final class MainViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isProxyEnabled = false
    @Published var currentConfiguration: ProxyConfiguration?
    @Published var proxyStatus: ProxyStatus = .disabled
    @Published var savedConfigurations: [ProxyConfiguration] = []
    @Published var recentRequests: [NetworkRequest] = []
    @Published var statistics = TrafficStatistics()
    @Published var errorMessage: String?
    @Published var isLoading = false

    // MARK: - Dependencies

    private let proxyService: ProxyServiceProtocol
    private let logger = Logger.proxyLog
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(proxyService: ProxyServiceProtocol) {
        self.proxyService = proxyService
        setupBindings()
        loadInitialData()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Bind proxy enabled state
        proxyService.isEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: &$isProxyEnabled)

        // Bind current configuration
        proxyService.currentConfiguration
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentConfiguration)

        // Bind proxy status
        proxyService.proxyStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$proxyStatus)
    }

    private func loadInitialData() {
        Task {
            await loadConfigurations()
        }
    }

    // MARK: - Proxy Operations

    func enableProxy(configuration: ProxyConfiguration) async {
        isLoading = true
        errorMessage = nil

        do {
            try await proxyService.enable(configuration: configuration)
            os_log(.info, log: logger, "Proxy enabled successfully")
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func disableProxy() async {
        isLoading = true
        errorMessage = nil

        do {
            try await proxyService.disable()
            os_log(.info, log: logger, "Proxy disabled successfully")
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func toggleProxy() async {
        if isProxyEnabled {
            await disableProxy()
        } else if let config = currentConfiguration ?? savedConfigurations.first {
            await enableProxy(configuration: config)
        } else {
            errorMessage = "No proxy configuration available"
        }
    }

    // MARK: - Configuration Management

    func loadConfigurations() async {
        isLoading = true

        do {
            savedConfigurations = try await proxyService.loadConfigurations()
            os_log(.debug, log: logger, "Loaded %d configurations", savedConfigurations.count)
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func saveConfiguration(_ configuration: ProxyConfiguration) async {
        isLoading = true
        errorMessage = nil

        do {
            try await proxyService.saveConfiguration(configuration)
            await loadConfigurations()
            os_log(.info, log: logger, "Configuration saved: %@", configuration.name)
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func deleteConfiguration(_ configuration: ProxyConfiguration) async {
        isLoading = true
        errorMessage = nil

        do {
            try await proxyService.deleteConfiguration(id: configuration.id)
            await loadConfigurations()
            os_log(.info, log: logger, "Configuration deleted: %@", configuration.name)
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func testConfiguration(_ configuration: ProxyConfiguration) async -> ConnectionTestResult {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await proxyService.testConnection(configuration: configuration)
            os_log(.info, log: logger, "Connection test completed: %d", result.success)
            return result
        } catch {
            handleError(error)
            return ConnectionTestResult(success: false, error: error as? AppError)
        }
    }

    // MARK: - Network Monitoring

    func addRequest(_ request: NetworkRequest) {
        recentRequests.insert(request, at: 0)

        // Keep only last 100 requests
        if recentRequests.count > 100 {
            recentRequests = Array(recentRequests.prefix(100))
        }

        // Update statistics
        statistics.update(with: request)
    }

    func clearRequests() {
        recentRequests.removeAll()
        statistics = TrafficStatistics()
    }

    func filterRequests(by status: RequestStatus? = nil, host: String? = nil) -> [NetworkRequest] {
        var filtered = recentRequests

        if let status = status {
            filtered = filtered.filter { $0.status == status }
        }

        if let host = host, !host.isEmpty {
            filtered = filtered.filter { $0.host.contains(host) }
        }

        return filtered
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        let appError = error as? AppError ?? .unknown(error)
        errorMessage = appError.errorDescription
        os_log(.error, log: logger, "Error: %@", appError.errorDescription ?? "Unknown error")
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Preview Helpers

extension MainViewModel {
    static var preview: MainViewModel {
        let service = MockProxyService()
        return MainViewModel(proxyService: service)
    }
}

// MARK: - Mock Service for Previews

final class MockProxyService: ProxyServiceProtocol {
    private let isEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let configurationSubject = CurrentValueSubject<ProxyConfiguration?, Never>(nil)
    private let statusSubject = CurrentValueSubject<ProxyStatus, Never>(.disabled)

    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    var currentConfiguration: AnyPublisher<ProxyConfiguration?, Never> {
        configurationSubject.eraseToAnyPublisher()
    }

    var proxyStatus: AnyPublisher<ProxyStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    func enable(configuration: ProxyConfiguration) async throws {
        isEnabledSubject.send(true)
        configurationSubject.send(configuration)
        statusSubject.send(.enabled(configuration))
    }

    func disable() async throws {
        isEnabledSubject.send(false)
        configurationSubject.send(nil)
        statusSubject.send(.disabled)
    }

    func toggle() async throws {
        if isEnabledSubject.value {
            try await disable()
        } else {
            let config = ProxyConfiguration.presets.first!
            try await enable(configuration: config)
        }
    }

    func updateConfiguration(_ configuration: ProxyConfiguration) async throws {
        configurationSubject.send(configuration)
    }

    func getCurrentSystemProxy() async throws -> SystemProxySettings {
        SystemProxySettings(
            httpEnabled: false,
            httpsEnabled: false,
            socksEnabled: false,
            httpProxy: nil,
            httpPort: nil,
            httpsProxy: nil,
            httpsPort: nil,
            socksProxy: nil,
            socksPort: nil,
            bypassDomains: []
        )
    }

    func testConnection(configuration: ProxyConfiguration) async throws -> ConnectionTestResult {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return ConnectionTestResult(success: true, latency: 0.045)
    }

    func saveConfiguration(_ configuration: ProxyConfiguration) async throws {
        // Mock save
    }

    func loadConfigurations() async throws -> [ProxyConfiguration] {
        ProxyConfiguration.presets
    }

    func deleteConfiguration(id: UUID) async throws {
        // Mock delete
    }
}
