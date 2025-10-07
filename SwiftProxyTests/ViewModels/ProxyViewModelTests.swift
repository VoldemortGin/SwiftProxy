import XCTest
import Combine
@testable import SwiftProxy

/// Comprehensive unit tests for ProxyViewModel
@MainActor
final class ProxyViewModelTests: XCTestCase {

    var sut: ProxyViewModel!
    var mockProxyService: MockProxyService!
    var mockConfigService: MockConfigurationService!
    var mockNetworkMonitor: MockNetworkMonitor!
    var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        mockProxyService = MockProxyService()
        mockConfigService = MockConfigurationService()
        mockNetworkMonitor = MockNetworkMonitor()
        cancellables = Set<AnyCancellable>()

        sut = ProxyViewModel(
            proxyService: mockProxyService,
            configService: mockConfigService,
            networkMonitor: mockNetworkMonitor
        )
    }

    override func tearDownWithError() throws {
        sut = nil
        mockProxyService = nil
        mockConfigService = nil
        mockNetworkMonitor = nil
        cancellables = nil

        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        // Then
        XCTAssertFalse(sut.isEnabled)
        XCTAssertNil(sut.currentConfiguration)
        XCTAssertEqual(sut.status, .disabled)
        XCTAssertTrue(sut.configurations.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    // MARK: - Enable Proxy Tests

    func testEnableProxySuccess() async {
        // Given
        let config = ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        mockProxyService.enableResult = .success(())
        mockConfigService.setActiveResult = .success(())

        // When
        await sut.enableProxy(configuration: config)

        // Then
        XCTAssertTrue(mockProxyService.enableCalled)
        XCTAssertTrue(mockConfigService.setActiveCalled)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    func testEnableProxyFailure() async {
        // Given
        let config = ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        mockProxyService.enableResult = .failure(.proxyConnectionFailed("Test error"))

        // When
        await sut.enableProxy(configuration: config)

        // Then
        XCTAssertTrue(mockProxyService.enableCalled)
        XCTAssertNotNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Disable Proxy Tests

    func testDisableProxySuccess() async {
        // Given
        mockProxyService.disableResult = .success(())
        mockConfigService.setActiveResult = .success(())

        // When
        await sut.disableProxy()

        // Then
        XCTAssertTrue(mockProxyService.disableCalled)
        XCTAssertTrue(mockConfigService.setActiveCalled)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    func testDisableProxyFailure() async {
        // Given
        mockProxyService.disableResult = .failure(.proxyNotEnabled)

        // When
        await sut.disableProxy()

        // Then
        XCTAssertTrue(mockProxyService.disableCalled)
        XCTAssertNotNil(sut.error)
    }

    // MARK: - Toggle Proxy Tests

    func testToggleProxyWhenDisabled() async {
        // Given
        let config = ProxyConfiguration(
            name: "Test",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        mockProxyService.isEnabledSubject.send(false)
        mockConfigService.configurationsSubject.send([config])
        mockConfigService.activeConfigSubject.send(config)

        mockProxyService.enableResult = .success(())
        mockConfigService.setActiveResult = .success(())

        // Wait for bindings to update
        try? await Task.sleep(nanoseconds: 100_000_000)

        // When
        await sut.toggleProxy()

        // Then
        XCTAssertTrue(mockProxyService.enableCalled)
    }

    func testToggleProxyWhenEnabled() async {
        // Given
        mockProxyService.isEnabledSubject.send(true)
        mockProxyService.disableResult = .success(())
        mockConfigService.setActiveResult = .success(())

        // Wait for bindings
        try? await Task.sleep(nanoseconds: 100_000_000)

        // When
        await sut.toggleProxy()

        // Then
        XCTAssertTrue(mockProxyService.disableCalled)
    }

    // MARK: - Configuration Management Tests

    func testSaveConfiguration() async {
        // Given
        let config = ProxyConfiguration(
            name: "New Config",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        mockConfigService.saveResult = .success(())
        mockConfigService.loadResult = [config]

        // When
        await sut.saveConfiguration(config)

        // Then
        XCTAssertTrue(mockConfigService.saveCalled)
        XCTAssertFalse(sut.isLoading)
    }

    func testDeleteConfiguration() async {
        // Given
        let config = ProxyConfiguration(
            name: "To Delete",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        mockConfigService.deleteResult = .success(())
        mockConfigService.loadResult = []

        // When
        await sut.deleteConfiguration(id: config.id)

        // Then
        XCTAssertTrue(mockConfigService.deleteCalled)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Test Connection Tests

    func testTestConnectionSuccess() async {
        // Given
        let config = ProxyConfiguration(
            name: "Test",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        let successResult = ConnectionTestResult(
            success: true,
            latency: 0.1,
            error: nil
        )

        mockProxyService.testConnectionResult = .success(successResult)

        // When
        await sut.testConnection(config)

        // Then
        XCTAssertTrue(mockProxyService.testConnectionCalled)
        XCTAssertNotNil(sut.testResult)
        XCTAssertTrue(sut.testResult?.success ?? false)
        XCTAssertFalse(sut.isTesting)
    }

    func testTestConnectionFailure() async {
        // Given
        let config = ProxyConfiguration(
            name: "Test",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        mockProxyService.testConnectionResult = .failure(.connectionTimeout)

        // When
        await sut.testConnection(config)

        // Then
        XCTAssertNotNil(sut.testResult)
        XCTAssertFalse(sut.testResult?.success ?? true)
        XCTAssertNotNil(sut.testResult?.error)
    }

    // MARK: - Publisher Binding Tests

    func testProxyServiceBindings() async {
        // Given
        let config = ProxyConfiguration(
            name: "Test",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        // When
        mockProxyService.isEnabledSubject.send(true)
        mockProxyService.currentConfigSubject.send(config)
        mockProxyService.statusSubject.send(.enabled(config))

        // Wait for updates
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertTrue(sut.isEnabled)
        XCTAssertEqual(sut.currentConfiguration?.id, config.id)
        if case .enabled(let enabledConfig) = sut.status {
            XCTAssertEqual(enabledConfig.id, config.id)
        } else {
            XCTFail("Status should be enabled")
        }
    }

    func testNetworkMonitorBindings() async {
        // When
        mockNetworkMonitor.statusSubject.send(.wifi)
        mockNetworkMonitor.isConnected = true

        // Wait for updates
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(sut.networkStatus, .wifi)
        XCTAssertTrue(sut.isNetworkAvailable)
    }

    // MARK: - Computed Properties Tests

    func testCanToggleProxy() async {
        // Given
        mockNetworkMonitor.isConnected = true
        mockConfigService.configurationsSubject.send([
            ProxyConfiguration(name: "Test", type: .http, host: "proxy.example.com", port: 8080)
        ])

        // Wait for updates
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertTrue(sut.canToggleProxy)

        // When - no network
        mockNetworkMonitor.isConnected = false

        // Wait
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertFalse(sut.canToggleProxy)
    }

    func testStatusDescription() {
        // When disabled
        XCTAssertEqual(sut.statusDescription, "Disabled")

        // When enabled
        let config = ProxyConfiguration(name: "Test", type: .http, host: "proxy.example.com", port: 8080)
        mockProxyService.statusSubject.send(.enabled(config))

        // Wait
        let expectation = XCTestExpectation(description: "Status updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.sut.statusDescription.contains("Test"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testHasConfigurations() async {
        // Initially false
        XCTAssertFalse(sut.hasConfigurations)

        // When configurations added
        mockConfigService.configurationsSubject.send([
            ProxyConfiguration(name: "Test", type: .http, host: "proxy.example.com", port: 8080)
        ])

        // Wait
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertTrue(sut.hasConfigurations)
    }

    // MARK: - Helper Methods Tests

    func testCreateNewConfiguration() {
        // When
        let config = sut.createNewConfiguration()

        // Then
        XCTAssertNotNil(config)
        XCTAssertEqual(config.name, "New Proxy")
        XCTAssertEqual(config.type, .http)
        XCTAssertEqual(config.port, 8080)
    }

    func testDuplicateConfiguration() async {
        // Given
        let original = ProxyConfiguration(
            name: "Original",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        mockConfigService.saveResult = .success(())

        // When
        await sut.duplicateConfiguration(original)

        // Then
        XCTAssertTrue(mockConfigService.saveCalled)
    }

    func testQuickEnable() async {
        // Given
        let config = ProxyConfiguration(
            name: "Quick Enable",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        mockProxyService.enableResult = .success(())
        mockConfigService.setActiveResult = .success(())

        // When
        await sut.quickEnable(config)

        // Then
        XCTAssertTrue(mockProxyService.enableCalled)
    }

    // MARK: - Error Handling Tests

    func testClearError() {
        // Given
        mockProxyService.enableResult = .failure(.proxyConnectionFailed("Test"))

        Task {
            let config = ProxyConfiguration(name: "Test", type: .http, host: "proxy.example.com", port: 8080)
            await sut.enableProxy(configuration: config)

            // Then
            XCTAssertNotNil(sut.error)

            // When
            await sut.clearError()

            // Then
            XCTAssertNil(sut.error)
        }
    }

    // MARK: - Refresh Tests

    func testRefresh() async {
        // Given
        mockConfigService.loadResult = [
            ProxyConfiguration(name: "Config1", type: .http, host: "proxy1.example.com", port: 8080),
            ProxyConfiguration(name: "Config2", type: .http, host: "proxy2.example.com", port: 8080)
        ]

        // When
        await sut.refresh()

        // Then - should have loaded configurations
        XCTAssertTrue(mockConfigService.loadCalled)
    }
}

// MARK: - Mock Services

class MockProxyService: ProxyServiceProtocol {
    let isEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    let currentConfigSubject = CurrentValueSubject<ProxyConfiguration?, Never>(nil)
    let statusSubject = CurrentValueSubject<ProxyStatus, Never>(.disabled)

    var isEnabled: AnyPublisher<Bool, Never> { isEnabledSubject.eraseToAnyPublisher() }
    var currentConfiguration: AnyPublisher<ProxyConfiguration?, Never> { currentConfigSubject.eraseToAnyPublisher() }
    var proxyStatus: AnyPublisher<ProxyStatus, Never> { statusSubject.eraseToAnyPublisher() }

    var enableCalled = false
    var disableCalled = false
    var testConnectionCalled = false

    var enableResult: Result<Void, AppError> = .success(())
    var disableResult: Result<Void, AppError> = .success(())
    var testConnectionResult: Result<ConnectionTestResult, AppError> = .success(
        ConnectionTestResult(success: true, latency: 0.1, error: nil)
    )

    func enable(configuration: ProxyConfiguration) async throws {
        enableCalled = true
        switch enableResult {
        case .success:
            isEnabledSubject.send(true)
            currentConfigSubject.send(configuration)
            statusSubject.send(.enabled(configuration))
        case .failure(let error):
            throw error
        }
    }

    func disable() async throws {
        disableCalled = true
        switch disableResult {
        case .success:
            isEnabledSubject.send(false)
            currentConfigSubject.send(nil)
            statusSubject.send(.disabled)
        case .failure(let error):
            throw error
        }
    }

    func testConnection(configuration: ProxyConfiguration) async throws -> ConnectionTestResult {
        testConnectionCalled = true
        switch testConnectionResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }

    func getCurrentSystemProxy() async throws -> SystemProxySettings {
        return SystemProxySettings(isAnyProxyEnabled: false, httpProxy: nil, httpsProxy: nil, socksProxy: nil)
    }
}

class MockConfigurationService: ConfigurationServiceProtocol {
    let configurationsSubject = CurrentValueSubject<[ProxyConfiguration], Never>([])
    let activeConfigSubject = CurrentValueSubject<ProxyConfiguration?, Never>(nil)

    var configurations: AnyPublisher<[ProxyConfiguration], Never> { configurationsSubject.eraseToAnyPublisher() }
    var activeConfiguration: AnyPublisher<ProxyConfiguration?, Never> { activeConfigSubject.eraseToAnyPublisher() }

    var loadCalled = false
    var saveCalled = false
    var deleteCalled = false
    var setActiveCalled = false

    var loadResult: [ProxyConfiguration] = []
    var saveResult: Result<Void, AppError> = .success(())
    var deleteResult: Result<Void, AppError> = .success(())
    var setActiveResult: Result<Void, AppError> = .success(())

    func loadConfigurations() async throws -> [ProxyConfiguration] {
        loadCalled = true
        configurationsSubject.send(loadResult)
        return loadResult
    }

    func saveConfiguration(_ configuration: ProxyConfiguration) async throws {
        saveCalled = true
        if case .failure(let error) = saveResult {
            throw error
        }
    }

    func updateConfiguration(_ configuration: ProxyConfiguration) async throws {
        saveCalled = true
        if case .failure(let error) = saveResult {
            throw error
        }
    }

    func deleteConfiguration(id: UUID) async throws {
        deleteCalled = true
        if case .failure(let error) = deleteResult {
            throw error
        }
    }

    func getConfiguration(id: UUID) async throws -> ProxyConfiguration? {
        return loadResult.first { $0.id == id }
    }

    func setActiveConfiguration(_ configuration: ProxyConfiguration?) async throws {
        setActiveCalled = true
        if case .failure(let error) = setActiveResult {
            throw error
        }
        activeConfigSubject.send(configuration)
    }

    func getActiveConfiguration() async throws -> ProxyConfiguration? {
        return activeConfigSubject.value
    }

    func exportConfigurations() async throws -> Data {
        return Data()
    }

    func importConfigurations(from data: Data, merge: Bool) async throws {}

    func exportConfiguration(id: UUID) async throws -> Data {
        return Data()
    }

    func validateConfiguration(_ configuration: ProxyConfiguration) async -> ProxyConfiguration.ValidationResult {
        return .valid
    }
}

class MockNetworkMonitor: NetworkMonitor {
    let statusSubject = CurrentValueSubject<NetworkStatus, Never>(.unknown)

    override var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    override func startMonitoring() {}
    override func stopMonitoring() {}
}
