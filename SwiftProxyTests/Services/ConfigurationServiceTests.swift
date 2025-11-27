import XCTest
import Combine
@testable import SwiftProxyCore

/// Unit tests for ConfigurationService
final class ConfigurationServiceTests: XCTestCase {

    // MARK: - Properties

    var sut: ConfigurationService!
    var mockKeychain: MockConfigKeychain!
    var tempDirectory: URL!
    var cancellables: Set<AnyCancellable>!

    // MARK: - Test Lifecycle

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create temp directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        mockKeychain = MockConfigKeychain()
        cancellables = Set<AnyCancellable>()

        // Create mock keychain service
        let keychainService = MockKeychainService()
        try sut = ConfigurationService(keychainService: keychainService)
    }

    override func tearDownWithError() throws {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)

        cancellables = nil
        sut = nil
        mockKeychain = nil

        try super.tearDownWithError()
    }

    // MARK: - Save Configuration Tests

    func testSaveConfiguration() async throws {
        // Given
        let configuration = ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        // When
        try await sut.saveConfiguration(configuration)

        // Then
        let loaded = try await sut.loadConfigurations()
        XCTAssertTrue(loaded.contains(where: { $0.id == configuration.id }))
    }

    func testSaveConfigurationWithPassword() async throws {
        // Given
        let configuration = ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080,
            requiresAuth: true,
            username: "user",
            password: "password123"
        )

        // When
        try await sut.saveConfiguration(configuration)

        // Then
        let loaded = try await sut.getConfiguration(id: configuration.id)
        XCTAssertNotNil(loaded)
        // Password should be loaded from keychain
        XCTAssertEqual(loaded?.password, "password123")
    }

    func testSaveInvalidConfiguration() async {
        // Given
        let configuration = ProxyConfiguration(
            name: "Invalid Proxy",
            type: .http,
            host: "", // Invalid: empty host
            port: 8080
        )

        // When/Then
        do {
            try await sut.saveConfiguration(configuration)
            XCTFail("Should throw error for invalid configuration")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }

    // MARK: - Load Configuration Tests

    func testLoadConfigurations() async throws {
        // Given
        let config1 = ProxyConfiguration(name: "Proxy 1", type: .http, host: "proxy1.com", port: 8080)
        let config2 = ProxyConfiguration(name: "Proxy 2", type: .https, host: "proxy2.com", port: 8443)

        try await sut.saveConfiguration(config1)
        try await sut.saveConfiguration(config2)

        // When
        let loaded = try await sut.loadConfigurations()

        // Then
        XCTAssertEqual(loaded.count, 2)
        XCTAssertTrue(loaded.contains(where: { $0.id == config1.id }))
        XCTAssertTrue(loaded.contains(where: { $0.id == config2.id }))
    }

    // MARK: - Update Configuration Tests

    func testUpdateConfiguration() async throws {
        // Given
        var configuration = ProxyConfiguration(
            name: "Original Name",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        try await sut.saveConfiguration(configuration)

        // When
        configuration.name = "Updated Name"
        try await sut.updateConfiguration(configuration)

        // Then
        let loaded = try await sut.getConfiguration(id: configuration.id)
        XCTAssertEqual(loaded?.name, "Updated Name")
    }

    // MARK: - Delete Configuration Tests

    func testDeleteConfiguration() async throws {
        // Given
        let configuration = ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        try await sut.saveConfiguration(configuration)

        // When
        try await sut.deleteConfiguration(id: configuration.id)

        // Then
        let loaded = try await sut.getConfiguration(id: configuration.id)
        XCTAssertNil(loaded)
    }

    func testDeleteNonexistentConfiguration() async {
        // Given
        let nonexistentID = UUID()

        // When/Then
        do {
            try await sut.deleteConfiguration(id: nonexistentID)
            XCTFail("Should throw error for nonexistent configuration")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }

    // MARK: - Active Configuration Tests

    func testSetActiveConfiguration() async throws {
        // Given
        let configuration = ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        try await sut.saveConfiguration(configuration)

        // When
        try await sut.setActiveConfiguration(configuration)

        // Then
        let active = try await sut.getActiveConfiguration()
        XCTAssertEqual(active?.id, configuration.id)
    }

    func testClearActiveConfiguration() async throws {
        // Given
        let configuration = ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        try await sut.saveConfiguration(configuration)
        try await sut.setActiveConfiguration(configuration)

        // When
        try await sut.setActiveConfiguration(nil)

        // Then
        let active = try await sut.getActiveConfiguration()
        XCTAssertNil(active)
    }

    // MARK: - Import/Export Tests

    func testExportConfigurations() async throws {
        // Given
        let config1 = ProxyConfiguration(name: "Proxy 1", type: .http, host: "proxy1.com", port: 8080)
        let config2 = ProxyConfiguration(name: "Proxy 2", type: .https, host: "proxy2.com", port: 8443)

        try await sut.saveConfiguration(config1)
        try await sut.saveConfiguration(config2)

        // When
        let data = try await sut.exportConfigurations()

        // Then
        XCTAssertGreaterThan(data.count, 0)

        // Verify it's valid JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([ProxyConfiguration].self, from: data)
        XCTAssertEqual(decoded.count, 2)
    }

    func testImportConfigurations() async throws {
        // Given
        let config = ProxyConfiguration(name: "Import Test", type: .http, host: "import.com", port: 8080)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([config])

        // When
        try await sut.importConfigurations(from: data, merge: false)

        // Then
        let loaded = try await sut.loadConfigurations()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Import Test")
    }

    func testImportConfigurationsMerge() async throws {
        // Given
        let existing = ProxyConfiguration(name: "Existing", type: .http, host: "existing.com", port: 8080)
        try await sut.saveConfiguration(existing)

        let imported = ProxyConfiguration(name: "Imported", type: .http, host: "imported.com", port: 8080)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([imported])

        // When
        try await sut.importConfigurations(from: data, merge: true)

        // Then
        let loaded = try await sut.loadConfigurations()
        XCTAssertEqual(loaded.count, 2)
    }

    // MARK: - Validation Tests

    func testValidateConfiguration() async {
        // Given - valid configuration
        let validConfig = ProxyConfiguration(
            name: "Valid Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        // When
        let validResult = await sut.validateConfiguration(validConfig)

        // Then
        XCTAssertTrue(validResult.isValid)

        // Given - invalid configuration
        let invalidConfig = ProxyConfiguration(
            name: "Invalid Proxy",
            type: .http,
            host: "", // Invalid
            port: 8080
        )

        // When
        let invalidResult = await sut.validateConfiguration(invalidConfig)

        // Then
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertNotNil(invalidResult.errorMessage)
    }

    // MARK: - Publisher Tests

    func testConfigurationsPublisher() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Configurations publisher updates")
        var receivedConfigs: [ProxyConfiguration] = []

        sut.configurations
            .dropFirst() // Skip initial empty state
            .sink { configs in
                receivedConfigs = configs
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        let configuration = ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        try await sut.saveConfiguration(configuration)

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertTrue(receivedConfigs.contains(where: { $0.id == configuration.id }))
    }
}

// MARK: - Mock Keychain

class MockConfigKeychain {
    private var storage: [String: String] = [:]

    func setPassword(_ password: String, for key: String) {
        storage[key] = password
    }

    func getPassword(for key: String) -> String? {
        storage[key]
    }

    func deletePassword(for key: String) {
        storage.removeValue(forKey: key)
    }
}

// MARK: - Mock Keychain Service

class MockKeychainService: KeychainServiceProtocol {
    private var storage: [String: String] = [:]

    func savePassword(_ password: String, for identifier: String) async throws {
        storage[identifier] = password
    }

    func loadPassword(for identifier: String) async throws -> String? {
        return storage[identifier]
    }

    func deletePassword(for identifier: String) async throws {
        storage.removeValue(forKey: identifier)
    }

    func deleteAllPasswords() async throws {
        storage.removeAll()
    }

    func passwordExists(for identifier: String) async -> Bool {
        return storage[identifier] != nil
    }

    func migratePasswords(_ migrations: [String: String]) async throws {
        for (oldIdentifier, newIdentifier) in migrations {
            if let password = storage[oldIdentifier] {
                storage[newIdentifier] = password
                storage.removeValue(forKey: oldIdentifier)
            }
        }
    }
}
