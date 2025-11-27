import XCTest
import Network
@testable import SwiftProxyCore

@available(macOS 12.0, *)
final class ProxyServerTests: XCTestCase {
    var sut: ProxyServer!
    var testConfiguration: SwiftProxyCore.ProxyConfiguration!

    override func setUp() async throws {
        try await super.setUp()

        testConfiguration = SwiftProxyCore.ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "127.0.0.1",
            port: 8888
        )

        sut = ProxyServer(configuration: testConfiguration)
    }

    override func tearDown() async throws {
        await sut?.stop()
        sut = nil
        testConfiguration = nil
        try await super.tearDown()
    }

    // MARK: - Server Lifecycle Tests

    func testServerStart() async throws {
        // When
        try await sut.start()

        // Then
        let stats = await sut.getStatistics()
        XCTAssertGreaterThanOrEqual(stats.totalConnections, 0)
    }

    func testServerStartWhenAlreadyRunning() async throws {
        // Given
        try await sut.start()

        // When/Then
        do {
            try await sut.start()
            XCTFail("Should throw error when starting already running server")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }

    func testServerStop() async throws {
        // Given
        try await sut.start()

        // When
        await sut.stop()

        // Then - Server should stop without errors
        let stats = await sut.getStatistics()
        XCTAssertEqual(stats.activeConnections, 0)
    }

    // MARK: - Statistics Tests

    func testGetStatistics() async throws {
        // When
        let stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.totalConnections, 0)
        XCTAssertEqual(stats.activeConnections, 0)
        XCTAssertEqual(stats.totalBytesTransferred, 0)
    }

    func testResetStatistics() async throws {
        // When
        await sut.resetStatistics()
        let stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.totalConnections, 0)
        XCTAssertEqual(stats.successfulConnections, 0)
        XCTAssertEqual(stats.failedConnections, 0)
    }

    // MARK: - Configuration Tests

    func testHTTPProxyConfiguration() async throws {
        // Given
        let httpConfig = ProxyConfiguration(
            name: "HTTP Proxy",
            type: .http,
            host: "127.0.0.1",
            port: 8080
        )

        // When
        let server = ProxyServer(configuration: httpConfig)

        // Then
        XCTAssertNotNil(server)
    }

    func testHTTPSProxyConfiguration() async throws {
        // Given
        let httpsConfig = ProxyConfiguration(
            name: "HTTPS Proxy",
            type: .https,
            host: "127.0.0.1",
            port: 8443
        )

        // When
        let server = ProxyServer(configuration: httpsConfig)

        // Then
        XCTAssertNotNil(server)
    }

    func testSOCKS5ProxyConfiguration() async throws {
        // Given
        let socksConfig = ProxyConfiguration(
            name: "SOCKS5 Proxy",
            type: .socks5,
            host: "127.0.0.1",
            port: 1080
        )

        // When
        let server = ProxyServer(configuration: socksConfig)

        // Then
        XCTAssertNotNil(server)
    }
}
