import Foundation
import Combine
#if os(macOS)
import SystemConfiguration
#endif
import OSLog

/// Protocol defining the proxy service interface
/// Provides system proxy management and configuration persistence
public protocol ProxyServiceProtocol: AnyObject {
    // State publishers
    var isEnabled: AnyPublisher<Bool, Never> { get }
    var currentConfiguration: AnyPublisher<ProxyConfiguration?, Never> { get }
    var proxyStatus: AnyPublisher<ProxyStatus, Never> { get }

    // Proxy control operations
    func enable(configuration: ProxyConfiguration) async throws
    func disable() async throws
    func toggle() async throws
    func updateConfiguration(_ configuration: ProxyConfiguration) async throws

    // System proxy inspection
    func getCurrentSystemProxy() async throws -> SystemProxySettings
    func testConnection(configuration: ProxyConfiguration) async throws -> ConnectionTestResult

    // Configuration persistence
    func saveConfiguration(_ configuration: ProxyConfiguration) async throws
    func loadConfigurations() async throws -> [ProxyConfiguration]
    func deleteConfiguration(id: UUID) async throws
}

// MARK: - ProxyStatus

public enum ProxyStatus: Equatable {
    case disabled
    case enabling
    case enabled(ProxyConfiguration)
    case disabling
    case error(AppError)

    public var isActive: Bool {
        if case .enabled = self { return true }
        return false
    }

    public static func == (lhs: ProxyStatus, rhs: ProxyStatus) -> Bool {
        switch (lhs, rhs) {
        case (.disabled, .disabled),
             (.enabling, .enabling),
             (.disabling, .disabling):
            return true
        case let (.enabled(lConfig), .enabled(rConfig)):
            return lConfig.id == rConfig.id
        case let (.error(lError), .error(rError)):
            return lError == rError
        default:
            return false
        }
    }
}

// MARK: - SystemProxySettings

public struct SystemProxySettings {
    public let httpEnabled: Bool
    public let httpsEnabled: Bool
    public let socksEnabled: Bool
    public let httpProxy: String?
    public let httpPort: Int?
    public let httpsProxy: String?
    public let httpsPort: Int?
    public let socksProxy: String?
    public let socksPort: Int?
    public let bypassDomains: [String]

    public init(
        httpEnabled: Bool,
        httpsEnabled: Bool,
        socksEnabled: Bool,
        httpProxy: String?,
        httpPort: Int?,
        httpsProxy: String?,
        httpsPort: Int?,
        socksProxy: String?,
        socksPort: Int?,
        bypassDomains: [String]
    ) {
        self.httpEnabled = httpEnabled
        self.httpsEnabled = httpsEnabled
        self.socksEnabled = socksEnabled
        self.httpProxy = httpProxy
        self.httpPort = httpPort
        self.httpsProxy = httpsProxy
        self.httpsPort = httpsPort
        self.socksProxy = socksProxy
        self.socksPort = socksPort
        self.bypassDomains = bypassDomains
    }

    public var isAnyProxyEnabled: Bool {
        httpEnabled || httpsEnabled || socksEnabled
    }
}

// MARK: - ConnectionTestResult

public struct ConnectionTestResult {
    public let success: Bool
    public let latency: TimeInterval?
    public let error: AppError?
    public let timestamp: Date

    public init(success: Bool, latency: TimeInterval? = nil, error: AppError? = nil) {
        self.success = success
        self.latency = latency
        self.error = error
        self.timestamp = Date()
    }
}

// MARK: - ProxyService Implementation

public final class ProxyService: ProxyServiceProtocol {
    // MARK: - Publishers

    private let isEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let configurationSubject = CurrentValueSubject<ProxyConfiguration?, Never>(nil)
    private let statusSubject = CurrentValueSubject<ProxyStatus, Never>(.disabled)

    public var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    public var currentConfiguration: AnyPublisher<ProxyConfiguration?, Never> {
        configurationSubject.eraseToAnyPublisher()
    }

    public var proxyStatus: AnyPublisher<ProxyStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    // MARK: - Dependencies

    private let logger: OSLog
    private let configurationsKey = "proxy_configurations"
    private let lastActiveConfigKey = "last_active_configuration"

    // Thread-safe state management
    private let stateQueue = DispatchQueue(label: "com.swiftproxy.proxyservice", qos: .userInitiated)
    private var cachedConfigurations: [ProxyConfiguration] = []

    // MARK: - Initialization

    public init(logger: OSLog = Logger.proxyLog) {
        self.logger = logger

        // Initialize by checking current system proxy state
        Task { [weak self] in
            await self?.checkSystemProxyStatus()
        }
    }

    // MARK: - Proxy Control

    public func enable(configuration: ProxyConfiguration) async throws {
        os_log(.info, log: logger, "Enabling proxy: %@", configuration.name)

        // Validate configuration
        let validation = configuration.validate()
        guard validation.isValid else {
            throw AppError.proxyConfigurationInvalid(validation.errorMessage ?? "Unknown validation error")
        }

        statusSubject.send(.enabling)

        do {
            // Set system proxy settings
            try await setSystemProxy(configuration: configuration)

            // Update state
            await MainActor.run {
                isEnabledSubject.send(true)
                configurationSubject.send(configuration)
                statusSubject.send(.enabled(configuration))
            }

            // Save as last used configuration
            try await saveLastActiveConfiguration(configuration)

            os_log(.info, log: logger, "Proxy enabled successfully")
        } catch {
            let appError = error as? AppError ?? .unknown(error)
            statusSubject.send(.error(appError))
            throw appError
        }
    }

    public func disable() async throws {
        os_log(.info, log: logger, "Disabling proxy")

        statusSubject.send(.disabling)

        do {
            // Clear system proxy settings
            try await clearSystemProxy()

            // Update state
            await MainActor.run {
                isEnabledSubject.send(false)
                configurationSubject.send(nil)
                statusSubject.send(.disabled)
            }

            os_log(.info, log: logger, "Proxy disabled successfully")
        } catch {
            let appError = error as? AppError ?? .unknown(error)
            statusSubject.send(.error(appError))
            throw appError
        }
    }

    public func toggle() async throws {
        if isEnabledSubject.value {
            try await disable()
        } else {
            // Try to load last used configuration
            if let lastConfig = try await loadLastActiveConfiguration() {
                try await enable(configuration: lastConfig)
            } else {
                throw AppError.proxyConfigurationInvalid("No saved configuration available")
            }
        }
    }

    public func updateConfiguration(_ configuration: ProxyConfiguration) async throws {
        os_log(.info, log: logger, "Updating configuration: %@", configuration.name)

        // If currently enabled with this config, re-enable with new settings
        if case .enabled(let current) = statusSubject.value,
           current.id == configuration.id {
            try await disable()
            try await enable(configuration: configuration)
        }

        // Update stored configuration
        try await saveConfiguration(configuration)
    }

    // MARK: - System Proxy Operations

    public func getCurrentSystemProxy() async throws -> SystemProxySettings {
        // Since readSystemProxySettings() is nonisolated, we can call it directly
        return try readSystemProxySettings()
    }

    public func testConnection(configuration: ProxyConfiguration) async throws -> ConnectionTestResult {
        os_log(.debug, log: logger, "Testing proxy connection: %@", configuration.address)

        let startTime = Date()

        do {
            // Create a test request through the proxy
            let testURL = URL(string: "https://www.google.com/generate_204")!
            var request = URLRequest(url: testURL, timeoutInterval: 10)
            request.httpMethod = "GET"

            // Configure session with proxy
            let sessionConfig = URLSessionConfiguration.ephemeral
            sessionConfig.connectionProxyDictionary = configuration.toURLSessionProxyDict()
            sessionConfig.timeoutIntervalForRequest = 10

            let session = URLSession(configuration: sessionConfig)

            let (_, response) = try await session.data(for: request)

            // Check response
            guard let httpResponse = response as? HTTPURLResponse else {
                return ConnectionTestResult(
                    success: false,
                    error: .invalidResponse
                )
            }

            let latency = Date().timeIntervalSince(startTime)

            // 204 No Content is expected from this endpoint
            if httpResponse.statusCode == 204 || (200...299).contains(httpResponse.statusCode) {
                os_log(.debug, log: logger, "Proxy connection successful, latency: %.2fms", latency * 1000)
                return ConnectionTestResult(success: true, latency: latency)
            } else {
                return ConnectionTestResult(
                    success: false,
                    error: .proxyConnectionFailed("Unexpected status code: \(httpResponse.statusCode)")
                )
            }
        } catch let error as NSError {
            os_log(.error, log: logger, "Proxy connection test failed: %@", error.localizedDescription)

            // Map NSError to AppError
            let appError: AppError
            switch error.code {
            case NSURLErrorTimedOut:
                appError = .connectionTimeout
            case NSURLErrorCannotConnectToHost:
                appError = .proxyServerUnreachable(configuration.address)
            case NSURLErrorUserAuthenticationRequired:
                appError = .proxyAuthenticationFailed
            default:
                appError = .proxyConnectionFailed(error.localizedDescription)
            }

            return ConnectionTestResult(success: false, error: appError)
        }
    }

    // MARK: - Configuration Management

    public func saveConfiguration(_ configuration: ProxyConfiguration) async throws {
        try await stateQueue.sync {
            // Load existing configurations
            var configurations = (try? self.loadConfigurationsSync()) ?? []

            // Update or append
            if let index = configurations.firstIndex(where: { $0.id == configuration.id }) {
                configurations[index] = configuration
            } else {
                configurations.append(configuration)
            }

            // Save to UserDefaults
            if let encoded = try? JSONEncoder().encode(configurations) {
                UserDefaults.standard.set(encoded, forKey: self.configurationsKey)
                self.cachedConfigurations = configurations
                os_log(.debug, log: self.logger, "Saved configuration: %@", configuration.name)
            } else {
                throw AppError.dataEncodingFailed
            }

            // Password is now stored directly in configuration (via UserDefaults)
        }
    }

    public func loadConfigurations() async throws -> [ProxyConfiguration] {
        return try await stateQueue.sync {
            try self.loadConfigurationsSync()
        }
    }

    public func deleteConfiguration(id: UUID) async throws {
        try await stateQueue.sync {
            var configurations = (try? self.loadConfigurationsSync()) ?? []
            configurations.removeAll { $0.id == id }

            if let encoded = try? JSONEncoder().encode(configurations) {
                UserDefaults.standard.set(encoded, forKey: self.configurationsKey)
                self.cachedConfigurations = configurations

                // Password is deleted with configuration (stored in UserDefaults)

                os_log(.debug, log: self.logger, "Deleted configuration: %@", id.uuidString)
            } else {
                throw AppError.dataEncodingFailed
            }
        }
    }

    // MARK: - Private Methods

    nonisolated private func readSystemProxySettings() throws -> SystemProxySettings {
        #if os(macOS)
        guard let dynamicStore = SCDynamicStoreCreate(nil, "SwiftProxy" as CFString, nil, nil) else {
            throw AppError.proxyConnectionFailed("Failed to create SCDynamicStore")
        }

        guard let proxies = SCDynamicStoreCopyProxies(dynamicStore) as? [String: Any] else {
            throw AppError.proxyConnectionFailed("Failed to read proxy settings")
        }

        return SystemProxySettings(
            httpEnabled: (proxies[kCFNetworkProxiesHTTPEnable as String] as? Int) == 1,
            httpsEnabled: (proxies[kCFNetworkProxiesHTTPSEnable as String] as? Int) == 1,
            socksEnabled: (proxies[kCFNetworkProxiesSOCKSEnable as String] as? Int) == 1,
            httpProxy: proxies[kCFNetworkProxiesHTTPProxy as String] as? String,
            httpPort: proxies[kCFNetworkProxiesHTTPPort as String] as? Int,
            httpsProxy: proxies[kCFNetworkProxiesHTTPSProxy as String] as? String,
            httpsPort: proxies[kCFNetworkProxiesHTTPSPort as String] as? Int,
            socksProxy: proxies[kCFNetworkProxiesSOCKSProxy as String] as? String,
            socksPort: proxies[kCFNetworkProxiesSOCKSPort as String] as? Int,
            bypassDomains: proxies[kCFNetworkProxiesExceptionsList as String] as? [String] ?? []
        )
        #else
        // On iOS/tvOS/watchOS, system-wide proxy settings are not accessible
        // Return default empty settings
        return SystemProxySettings(
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
        #endif
    }

    private func setSystemProxy(configuration: ProxyConfiguration) async throws {
        #if os(macOS)
        // Request authorization for system modification
        guard let authRef = try? await requestAuthorization() else {
            throw AppError.proxyNotAuthorized
        }

        defer {
            AuthorizationFree(authRef, [])
        }

        // Create preferences with authorization
        guard let preferences = SCPreferencesCreateWithAuthorization(
            nil,
            "SwiftProxy" as CFString,
            nil,
            authRef
        ) else {
            throw AppError.proxyConfigurationInvalid("Failed to create system preferences")
        }

        // Get network services
        guard let services = SCNetworkServiceCopyAll(preferences) as? [SCNetworkService] else {
            throw AppError.proxyConfigurationInvalid("Failed to get network services")
        }

        // Apply proxy settings to all network services
        for service in services {
            try setProxyForService(service, configuration: configuration)
        }

        // Commit and apply changes
        guard SCPreferencesCommitChanges(preferences) else {
            throw AppError.proxyConfigurationInvalid("Failed to commit proxy changes")
        }

        guard SCPreferencesApplyChanges(preferences) else {
            throw AppError.proxyConfigurationInvalid("Failed to apply proxy changes")
        }

        os_log(.info, log: logger, "System proxy set successfully")
        #else
        // On iOS/tvOS/watchOS, system-wide proxy configuration is not supported
        // Use Network Extension (NEProvider) instead for iOS
        throw AppError.proxyNotSupported("System proxy configuration is not available on this platform. Use Network Extension instead.")
        #endif
    }

    private func clearSystemProxy() async throws {
        #if os(macOS)
        guard let authRef = try? await requestAuthorization() else {
            throw AppError.proxyNotAuthorized
        }

        defer {
            AuthorizationFree(authRef, [])
        }

        guard let preferences = SCPreferencesCreateWithAuthorization(
            nil,
            "SwiftProxy" as CFString,
            nil,
            authRef
        ) else {
            throw AppError.proxyConfigurationInvalid("Failed to create system preferences")
        }

        guard let services = SCNetworkServiceCopyAll(preferences) as? [SCNetworkService] else {
            throw AppError.proxyConfigurationInvalid("Failed to get network services")
        }

        for service in services {
            try clearProxyForService(service)
        }

        guard SCPreferencesCommitChanges(preferences),
              SCPreferencesApplyChanges(preferences) else {
            throw AppError.proxyConfigurationInvalid("Failed to clear system proxy")
        }

        os_log(.info, log: logger, "System proxy cleared successfully")
        #else
        // On iOS/tvOS/watchOS, system proxy clearing is not applicable
        throw AppError.proxyNotSupported("System proxy configuration is not available on this platform.")
        #endif
    }

    #if os(macOS)
    private func setProxyForService(_ service: SCNetworkService, configuration: ProxyConfiguration) throws {
        guard let protocolConfig = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeProxies) else {
            return // Service doesn't support proxies
        }

        let proxyDict = configuration.toSystemConfigDict()

        SCNetworkProtocolSetConfiguration(protocolConfig, proxyDict as CFDictionary)
    }

    private func clearProxyForService(_ service: SCNetworkService) throws {
        guard let protocolConfig = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeProxies) else {
            return
        }

        let emptyDict: [String: Any] = [
            kCFNetworkProxiesHTTPEnable as String: 0,
            kCFNetworkProxiesHTTPSEnable as String: 0,
            kCFNetworkProxiesSOCKSEnable as String: 0
        ]

        SCNetworkProtocolSetConfiguration(protocolConfig, emptyDict as CFDictionary)
    }

    private func requestAuthorization() async throws -> AuthorizationRef {
        return try await withCheckedThrowingContinuation { continuation in
            var authRef: AuthorizationRef?
            let status = AuthorizationCreate(nil, nil, [], &authRef)

            guard status == errAuthorizationSuccess, let auth = authRef else {
                continuation.resume(throwing: AppError.proxyNotAuthorized)
                return
            }

            continuation.resume(returning: auth)
        }
    }
    #endif

    private func checkSystemProxyStatus() async {
        do {
            let settings = try await getCurrentSystemProxy()
            let isActive = settings.isAnyProxyEnabled

            await MainActor.run {
                isEnabledSubject.send(isActive)
            }

            if isActive {
                // Try to match with saved configurations
                if let matchedConfig = try await findMatchingConfiguration(settings) {
                    await MainActor.run {
                        configurationSubject.send(matchedConfig)
                        statusSubject.send(.enabled(matchedConfig))
                    }
                }
            }
        } catch {
            os_log(.error, log: logger, "Failed to check system proxy status: %@", error.localizedDescription)
        }
    }

    private func findMatchingConfiguration(_ settings: SystemProxySettings) async throws -> ProxyConfiguration? {
        let configurations = try await loadConfigurations()

        return configurations.first { config in
            switch config.type {
            case .http:
                return settings.httpEnabled &&
                       settings.httpProxy == config.host &&
                       settings.httpPort == config.port
            case .https:
                return settings.httpsEnabled &&
                       settings.httpsProxy == config.host &&
                       settings.httpsPort == config.port
            case .socks5:
                return settings.socksEnabled &&
                       settings.socksProxy == config.host &&
                       settings.socksPort == config.port
            }
        }
    }

    private func loadConfigurationsSync() throws -> [ProxyConfiguration] {
        guard let data = UserDefaults.standard.data(forKey: configurationsKey),
              let configurations = try? JSONDecoder().decode([ProxyConfiguration].self, from: data) else {
            return []
        }

        // Password is now stored directly in configuration
        cachedConfigurations = configurations
        return configurations
    }

    private func saveLastActiveConfiguration(_ configuration: ProxyConfiguration) async throws {
        if let encoded = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(encoded, forKey: lastActiveConfigKey)
        }
    }

    private func loadLastActiveConfiguration() async throws -> ProxyConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: lastActiveConfigKey),
              let configuration = try? JSONDecoder().decode(ProxyConfiguration.self, from: data) else {
            return nil
        }

        // Password is stored directly in configuration
        return configuration
    }

}

// NOTE: DispatchQueue extension moved to Shared/Core/Utils/DispatchQueueExtensions.swift
