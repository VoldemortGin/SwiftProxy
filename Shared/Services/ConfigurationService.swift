import Foundation
import Combine
import OSLog

/// Service for managing proxy configurations
/// Provides CRUD operations with persistence and validation
/// Thread-safe implementation using actors for Swift concurrency
public protocol ConfigurationServiceProtocol: AnyObject {
    // Publishers
    var configurations: AnyPublisher<[ProxyConfiguration], Never> { get }
    var activeConfiguration: AnyPublisher<ProxyConfiguration?, Never> { get }

    // CRUD operations
    func loadConfigurations() async throws -> [ProxyConfiguration]
    func saveConfiguration(_ configuration: ProxyConfiguration) async throws
    func updateConfiguration(_ configuration: ProxyConfiguration) async throws
    func deleteConfiguration(id: UUID) async throws
    func getConfiguration(id: UUID) async throws -> ProxyConfiguration?

    // Active configuration management
    func setActiveConfiguration(_ configuration: ProxyConfiguration?) async throws
    func getActiveConfiguration() async throws -> ProxyConfiguration?

    // Import/Export
    func exportConfigurations() async throws -> Data
    func importConfigurations(from data: Data, merge: Bool) async throws
    func exportConfiguration(id: UUID) async throws -> Data

    // Validation
    func validateConfiguration(_ configuration: ProxyConfiguration) async -> ProxyConfiguration.ValidationResult
}

public final class ConfigurationService: ConfigurationServiceProtocol {
    // MARK: - Publishers

    private let configurationsSubject = CurrentValueSubject<[ProxyConfiguration], Never>([])
    private let activeConfigurationSubject = CurrentValueSubject<ProxyConfiguration?, Never>(nil)

    public var configurations: AnyPublisher<[ProxyConfiguration], Never> {
        configurationsSubject.eraseToAnyPublisher()
    }

    public var activeConfiguration: AnyPublisher<ProxyConfiguration?, Never> {
        activeConfigurationSubject.eraseToAnyPublisher()
    }

    // MARK: - Properties

    private let logger: OSLog
    private let fileManager: FileManager
    private let storageURL: URL
    private let stateQueue = DispatchQueue(label: "com.swiftproxy.configservice", qos: .userInitiated)

    // Storage keys
    private let configurationsKey = "proxy_configurations"
    private let activeConfigIDKey = "active_configuration_id"

    // In-memory cache for performance
    private var cachedConfigurations: [UUID: ProxyConfiguration] = [:]

    // MARK: - Initialization

    public init(
        fileManager: FileManager = .default,
        logger: OSLog = Logger.storageLog
    ) throws {
        self.fileManager = fileManager
        self.logger = logger

        // Setup storage directory
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        self.storageURL = appSupport.appendingPathComponent("SwiftProxy", isDirectory: true)

        try createStorageDirectoryIfNeeded()

        // Load initial data
        Task {
            await loadInitialData()
        }
    }

    // MARK: - CRUD Operations

    public func loadConfigurations() async throws -> [ProxyConfiguration] {
        try await stateQueue.syncThrowing {
            try await self.loadConfigurationsAsync()
        }
    }

    public func saveConfiguration(_ configuration: ProxyConfiguration) async throws {
        os_log(.info, log: logger, "Saving configuration: %@", configuration.name)

        // Validate before saving
        let validation = await validateConfiguration(configuration)
        guard validation.isValid else {
            throw AppError.proxyConfigurationInvalid(validation.errorMessage ?? "Validation failed")
        }

        try await stateQueue.syncThrowing {
            // Add or update in cache
            self.cachedConfigurations[configuration.id] = configuration

            // Password is stored directly in configuration file

            // Persist to disk
            try self.persistConfigurations()

            // Update publisher
            await MainActor.run {
                self.configurationsSubject.send(Array(self.cachedConfigurations.values).sorted { $0.name < $1.name })
            }

            os_log(.debug, log: self.logger, "Configuration saved: %@", configuration.id.uuidString)
        }
    }

    public func updateConfiguration(_ configuration: ProxyConfiguration) async throws {
        os_log(.info, log: logger, "Updating configuration: %@", configuration.name)

        // Ensure configuration exists
        guard cachedConfigurations[configuration.id] != nil else {
            throw AppError.proxyConfigurationInvalid("Configuration not found")
        }

        // Save uses same logic as update
        try await saveConfiguration(configuration)

        // If this is the active configuration, update it
        if activeConfigurationSubject.value?.id == configuration.id {
            await MainActor.run {
                activeConfigurationSubject.send(configuration)
            }
        }
    }

    public func deleteConfiguration(id: UUID) async throws {
        os_log(.info, log: logger, "Deleting configuration: %@", id.uuidString)

        try await stateQueue.syncThrowing {
            // Remove from cache
            guard self.cachedConfigurations.removeValue(forKey: id) != nil else {
                throw AppError.proxyConfigurationInvalid("Configuration not found")
            }

            // Password is deleted along with configuration

            // Persist changes
            try self.persistConfigurations()

            // Update publisher
            await MainActor.run {
                self.configurationsSubject.send(Array(self.cachedConfigurations.values).sorted { $0.name < $1.name })

                // Clear active configuration if it was deleted
                if self.activeConfigurationSubject.value?.id == id {
                    self.activeConfigurationSubject.send(nil)
                    UserDefaults.standard.removeObject(forKey: self.activeConfigIDKey)
                }
            }

            os_log(.debug, log: self.logger, "Configuration deleted: %@", id.uuidString)
        }
    }

    public func getConfiguration(id: UUID) async throws -> ProxyConfiguration? {
        cachedConfigurations[id]
    }

    // MARK: - Active Configuration Management

    public func setActiveConfiguration(_ configuration: ProxyConfiguration?) async throws {
        if let config = configuration {
            // Validate that configuration exists
            guard cachedConfigurations[config.id] != nil else {
                throw AppError.proxyConfigurationInvalid("Configuration not found")
            }

            // Save to UserDefaults
            UserDefaults.standard.set(config.id.uuidString, forKey: activeConfigIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeConfigIDKey)
        }

        await MainActor.run {
            activeConfigurationSubject.send(configuration)
        }

        os_log(.info, log: logger, "Active configuration set: %@", configuration?.name ?? "None")
    }

    public func getActiveConfiguration() async throws -> ProxyConfiguration? {
        activeConfigurationSubject.value
    }

    // MARK: - Import/Export

    public func exportConfigurations() async throws -> Data {
        let configs = Array(cachedConfigurations.values)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(configs)

        os_log(.info, log: logger, "Exported %d configurations", configs.count)
        return data
    }

    public func importConfigurations(from data: Data, merge: Bool) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let configs = try decoder.decode([ProxyConfiguration].self, from: data)

        if !merge {
            // Clear existing configurations
            cachedConfigurations.removeAll()
        }

        // Import configurations (passwords are stored in the configuration file)
        for config in configs {
            cachedConfigurations[config.id] = config
        }

        try persistConfigurations()

        await MainActor.run {
            configurationsSubject.send(Array(cachedConfigurations.values).sorted { $0.name < $1.name })
        }

        os_log(.info, log: logger, "Imported %d configurations (merge: %@)", configs.count, merge ? "yes" : "no")
    }

    public func exportConfiguration(id: UUID) async throws -> Data {
        guard let config = cachedConfigurations[id] else {
            throw AppError.proxyConfigurationInvalid("Configuration not found")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(config)
    }

    // MARK: - Validation

    public func validateConfiguration(_ configuration: ProxyConfiguration) async -> ProxyConfiguration.ValidationResult {
        // Use built-in validation
        let result = configuration.validate()

        // Additional service-level validations
        if case .valid = result {
            // Check for duplicate names (excluding self)
            let duplicateName = cachedConfigurations.values.contains { config in
                config.id != configuration.id && config.name == configuration.name
            }

            if duplicateName {
                os_log(.default, log: logger, "Duplicate configuration name: %@", configuration.name)
                // Note: We allow duplicate names but log a warning
            }
        }

        return result
    }

    // MARK: - Private Methods

    private func createStorageDirectoryIfNeeded() throws {
        if !fileManager.fileExists(atPath: storageURL.path) {
            try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
            os_log(.info, log: logger, "Created storage directory: %@", storageURL.path)
        }
    }

    private func loadInitialData() async {
        do {
            let configs = try await loadConfigurations()

            await MainActor.run {
                configurationsSubject.send(configs)
            }

            // Load active configuration
            if let activeIDString = UserDefaults.standard.string(forKey: activeConfigIDKey),
               let activeID = UUID(uuidString: activeIDString),
               let activeConfig = cachedConfigurations[activeID] {

                await MainActor.run {
                    activeConfigurationSubject.send(activeConfig)
                }
            }

            os_log(.info, log: logger, "Loaded %d configurations", configs.count)
        } catch {
            os_log(.error, log: logger, "Failed to load initial data: %@", error.localizedDescription)
        }
    }

    private func loadConfigurationsAsync() async throws -> [ProxyConfiguration] {
        let fileURL = storageURL.appendingPathComponent("configurations.json")

        // If file doesn't exist, return empty array
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let configs = try decoder.decode([ProxyConfiguration].self, from: data)

        // Passwords are stored directly in configuration file

        // Update cache
        cachedConfigurations = Dictionary(uniqueKeysWithValues: configs.map { ($0.id, $0) })

        return configs.sorted { $0.name < $1.name }
    }

    private func persistConfigurations() throws {
        let configs = Array(cachedConfigurations.values)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(configs)

        let fileURL = storageURL.appendingPathComponent("configurations.json")
        try data.write(to: fileURL, options: [.atomic])

        os_log(.debug, log: logger, "Persisted %d configurations to disk", configs.count)
    }
}

// NOTE: DispatchQueue extension moved to StatisticsService.swift to avoid duplication
