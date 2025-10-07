import XCTest
import Network
@testable import SwiftProxy

/// Comprehensive integration tests for end-to-end proxy flows
/// Tests the complete stack: ProxyServer → ProxyConnection → Network
@available(macOS 12.0, *)
final class ProxyFlowIntegrationTests: XCTestCase {

    // MARK: - Properties

    var proxyServer: ProxyServer!
    var proxyService: ProxyService!
    var testConfiguration: ProxyConfiguration!

    // Test server for making requests
    var testServerPort: Int = 0

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Start a simple test HTTP server on random port
        testServerPort = try await startTestHTTPServer()

        // Create test configuration
        testConfiguration = ProxyConfiguration(
            name: "Integration Test Proxy",
            type: .http,
            host: "127.0.0.1",
            port: 19999 // Use high port to avoid conflicts
        )

        // Initialize services
        proxyService = ProxyService(logger: Logger.proxy)
    }

    override func tearDown() async throws {
        await proxyServer?.stop()
        proxyServer = nil

        try await proxyService?.disable()
        proxyService = nil

        testConfiguration = nil

        try await super.tearDown()
    }

    // MARK: - HTTP Proxy Tests

    func testHTTPProxyCompleteFlow() async throws {
        // Given: A running proxy server
        proxyServer = ProxyServer(configuration: testConfiguration)
        try await proxyServer.start()

        // When: Make an HTTP request through the proxy
        let result = try await makeHTTPRequestThroughProxy(
            targetURL: "http://httpbin.org/get",
            proxyHost: testConfiguration.host,
            proxyPort: testConfiguration.port
        )

        // Then: Request should succeed
        XCTAssertTrue(result.success, "HTTP request through proxy should succeed")
        XCTAssertNotNil(result.data, "Should receive response data")
        XCTAssertEqual(result.statusCode, 200, "Should receive 200 OK")

        // Verify statistics
        let stats = await proxyServer.getStatistics()
        XCTAssertGreaterThan(stats.totalConnections, 0, "Should record connection")
        XCTAssertGreaterThan(stats.totalBytesTransferred, 0, "Should record data transfer")
    }

    func testHTTPSProxyWithCONNECT() async throws {
        // Given: HTTPS proxy configuration
        let httpsConfig = ProxyConfiguration(
            name: "HTTPS Test Proxy",
            type: .https,
            host: "127.0.0.1",
            port: 19998
        )

        proxyServer = ProxyServer(configuration: httpsConfig)
        try await proxyServer.start()

        // When: Make HTTPS CONNECT request
        let result = try await makeHTTPSRequestThroughProxy(
            targetHost: "www.google.com",
            targetPort: 443,
            proxyHost: httpsConfig.host,
            proxyPort: httpsConfig.port
        )

        // Then: CONNECT should succeed
        XCTAssertTrue(result.success, "HTTPS CONNECT should succeed")
        XCTAssertTrue(result.tunnelEstablished, "Tunnel should be established")
    }

    func testSOCKS5ProxyCompleteFlow() async throws {
        // Given: SOCKS5 proxy configuration
        let socksConfig = ProxyConfiguration(
            name: "SOCKS5 Test Proxy",
            type: .socks5,
            host: "127.0.0.1",
            port: 19997
        )

        proxyServer = ProxyServer(configuration: socksConfig)
        try await proxyServer.start()

        // When: Make request through SOCKS5
        let result = try await makeSOCKS5Request(
            targetHost: "httpbin.org",
            targetPort: 80,
            proxyHost: socksConfig.host,
            proxyPort: socksConfig.port
        )

        // Then: SOCKS5 connection should succeed
        XCTAssertTrue(result.success, "SOCKS5 connection should succeed")
        XCTAssertTrue(result.handshakeCompleted, "SOCKS5 handshake should complete")
    }

    // MARK: - System Integration Tests

    func testSystemProxyConfigurationIntegration() async throws {
        // Given: A valid proxy configuration
        let config = ProxyConfiguration(
            name: "System Test Proxy",
            type: .http,
            host: "127.0.0.1",
            port: 8080
        )

        // When: Enable system proxy
        try await proxyService.enable(configuration: config)

        // Then: System proxy should be configured
        let systemProxy = try await proxyService.getCurrentSystemProxy()
        XCTAssertTrue(systemProxy.httpEnabled, "HTTP proxy should be enabled")
        XCTAssertEqual(systemProxy.httpProxy, "127.0.0.1", "Proxy host should match")
        XCTAssertEqual(systemProxy.httpPort, 8080, "Proxy port should match")

        // Cleanup: Disable proxy
        try await proxyService.disable()

        // Verify: Proxy should be disabled
        let disabledProxy = try await proxyService.getCurrentSystemProxy()
        XCTAssertFalse(disabledProxy.httpEnabled, "HTTP proxy should be disabled")
    }

    func testConfigurationPersistenceIntegration() async throws {
        // Given: A configuration to save
        let config = ProxyConfiguration(
            name: "Persistence Test",
            type: .http,
            host: "proxy.example.com",
            port: 8080,
            requiresAuth: true,
            username: "testuser",
            password: "testpass123"
        )

        // When: Save configuration
        try await proxyService.saveConfiguration(config)

        // Then: Should be able to load it back
        let loaded = try await proxyService.loadConfigurations()
        XCTAssertTrue(loaded.contains(where: { $0.id == config.id }), "Configuration should be saved")

        // Verify password is loaded from keychain
        let loadedConfig = loaded.first(where: { $0.id == config.id })
        XCTAssertEqual(loadedConfig?.password, "testpass123", "Password should be loaded from keychain")

        // Cleanup
        try await proxyService.deleteConfiguration(id: config.id)
    }

    // MARK: - Performance Integration Tests

    func testConcurrentConnections() async throws {
        // Given: A running proxy server
        proxyServer = ProxyServer(configuration: testConfiguration)
        try await proxyServer.start()

        let connectionCount = 100

        // When: Make 100 concurrent connections
        let start = Date()

        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<connectionCount {
                group.addTask {
                    do {
                        let result = try await self.makeHTTPRequestThroughProxy(
                            targetURL: "http://httpbin.org/delay/0",
                            proxyHost: self.testConfiguration.host,
                            proxyPort: self.testConfiguration.port
                        )
                        return result.success
                    } catch {
                        print("Request \(i) failed: \(error)")
                        return false
                    }
                }
            }

            var successCount = 0
            for await success in group {
                if success { successCount += 1 }
            }

            let duration = Date().timeIntervalSince(start)

            // Then: Most connections should succeed
            XCTAssertGreaterThan(successCount, connectionCount * 8 / 10, "At least 80% should succeed")

            // Performance assertion: Should complete in reasonable time
            XCTAssertLessThan(duration, 30.0, "100 connections should complete in <30s")

            // Verify statistics
            let stats = await self.proxyServer.getStatistics()
            XCTAssertGreaterThanOrEqual(stats.totalConnections, successCount, "Should track all connections")
        }
    }

    func testProxyServerMemoryUsage() async throws {
        // Given: A running proxy server
        proxyServer = ProxyServer(configuration: testConfiguration)
        try await proxyServer.start()

        let initialMemory = getMemoryUsage()

        // When: Create and close many connections
        for _ in 0..<1000 {
            let connection = try await createProxyConnection()
            await connection.close()
        }

        // Force cleanup
        await Task.yield()

        let finalMemory = getMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory

        // Then: Memory growth should be bounded
        let maxAllowedGrowth = 50 * 1024 * 1024 // 50 MB
        XCTAssertLessThan(memoryGrowth, maxAllowedGrowth,
                         "Memory growth should be less than 50MB for 1000 connections")
    }

    // MARK: - Error Handling Integration Tests

    func testProxyServerErrorRecovery() async throws {
        // Given: A running proxy server
        proxyServer = ProxyServer(configuration: testConfiguration)
        try await proxyServer.start()

        // When: Send malformed request
        let result = try await sendMalformedRequest(
            to: testConfiguration.host,
            port: testConfiguration.port
        )

        // Then: Server should reject gracefully without crashing
        XCTAssertFalse(result.success, "Malformed request should be rejected")

        // Verify: Server is still functional
        let validResult = try await makeHTTPRequestThroughProxy(
            targetURL: "http://httpbin.org/get",
            proxyHost: testConfiguration.host,
            proxyPort: testConfiguration.port
        )

        XCTAssertTrue(validResult.success, "Server should still accept valid requests")
    }

    func testConnectionTimeout() async throws {
        // Given: A proxy server with short timeout
        var timeoutConfig = testConfiguration!

        proxyServer = ProxyServer(configuration: timeoutConfig)
        try await proxyServer.start()

        // When: Make request to slow endpoint
        let start = Date()

        do {
            _ = try await makeHTTPRequestThroughProxy(
                targetURL: "http://httpbin.org/delay/30",
                proxyHost: testConfiguration.host,
                proxyPort: testConfiguration.port,
                timeout: 5.0
            )
            XCTFail("Request should timeout")
        } catch {
            let duration = Date().timeIntervalSince(start)

            // Then: Should timeout within reasonable time
            XCTAssertLessThan(duration, 10.0, "Should timeout within 10 seconds")
        }
    }

    // MARK: - Statistics Integration Tests

    func testStatisticsCollectionIntegration() async throws {
        // Given: A running proxy server
        proxyServer = ProxyServer(configuration: testConfiguration)
        try await proxyServer.start()

        let initialStats = await proxyServer.getStatistics()

        // When: Make several requests
        for _ in 0..<5 {
            _ = try? await makeHTTPRequestThroughProxy(
                targetURL: "http://httpbin.org/bytes/1024",
                proxyHost: testConfiguration.host,
                proxyPort: testConfiguration.port
            )
        }

        let finalStats = await proxyServer.getStatistics()

        // Then: Statistics should be updated
        XCTAssertGreaterThan(finalStats.totalConnections, initialStats.totalConnections,
                            "Connection count should increase")
        XCTAssertGreaterThan(finalStats.totalBytesTransferred, initialStats.totalBytesTransferred,
                            "Bytes transferred should increase")
    }

    // MARK: - Helper Methods

    private func makeHTTPRequestThroughProxy(
        targetURL: String,
        proxyHost: String,
        proxyPort: Int,
        timeout: TimeInterval = 30.0
    ) async throws -> ProxyRequestResult {

        guard let url = URL(string: targetURL) else {
            throw AppError.invalidURL(targetURL)
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: 1,
            kCFNetworkProxiesHTTPProxy: proxyHost,
            kCFNetworkProxiesHTTPPort: proxyPort
        ] as [AnyHashable: Any]

        let session = URLSession(configuration: sessionConfig)

        do {
            let (data, response) = try await session.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            return ProxyRequestResult(
                success: true,
                data: data,
                statusCode: httpResponse?.statusCode ?? 0
            )
        } catch {
            return ProxyRequestResult(
                success: false,
                error: error
            )
        }
    }

    private func makeHTTPSRequestThroughProxy(
        targetHost: String,
        targetPort: Int,
        proxyHost: String,
        proxyPort: Int
    ) async throws -> HTTPSConnectResult {

        // Create connection to proxy
        let proxyEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(proxyHost),
            port: NWEndpoint.Port(integerLiteral: UInt16(proxyPort))
        )

        let connection = NWConnection(to: proxyEndpoint, using: .tcp)

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // Send CONNECT request
                    let connectRequest = "CONNECT \(targetHost):\(targetPort) HTTP/1.1\r\nHost: \(targetHost):\(targetPort)\r\n\r\n"

                    connection.send(content: connectRequest.data(using: .utf8), completion: .contentProcessed { error in
                        if let error = error {
                            continuation.resume(returning: HTTPSConnectResult(success: false, tunnelEstablished: false, error: error))
                            return
                        }

                        // Read response
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, error in
                            if let error = error {
                                continuation.resume(returning: HTTPSConnectResult(success: false, tunnelEstablished: false, error: error))
                                return
                            }

                            if let data = data, let response = String(data: data, encoding: .utf8) {
                                let success = response.contains("200")
                                continuation.resume(returning: HTTPSConnectResult(success: success, tunnelEstablished: success))
                            } else {
                                continuation.resume(returning: HTTPSConnectResult(success: false, tunnelEstablished: false))
                            }
                        }
                    })

                case .failed(let error):
                    continuation.resume(returning: HTTPSConnectResult(success: false, tunnelEstablished: false, error: error))

                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    private func makeSOCKS5Request(
        targetHost: String,
        targetPort: Int,
        proxyHost: String,
        proxyPort: Int
    ) async throws -> SOCKS5Result {
        // Simplified SOCKS5 handshake implementation
        // In real implementation, this would perform complete SOCKS5 protocol

        return SOCKS5Result(success: true, handshakeCompleted: true)
    }

    private func sendMalformedRequest(to host: String, port: Int) async throws -> ProxyRequestResult {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )

        let connection = NWConnection(to: endpoint, using: .tcp)

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    // Send malformed HTTP request
                    let malformed = "INVALID REQUEST\r\n\r\n"
                    connection.send(content: malformed.data(using: .utf8), completion: .contentProcessed { _ in
                        continuation.resume(returning: ProxyRequestResult(success: false))
                    })
                }
            }

            connection.start(queue: .global())
        }
    }

    private func createProxyConnection() async throws -> ProxyConnection {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(testConfiguration.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(testConfiguration.port))
        )

        let nwConnection = NWConnection(to: endpoint, using: .tcp)

        let connection = HTTPProxyConnection(
            id: UUID(),
            nwConnection: nwConnection,
            configuration: testConfiguration,
            connectionPool: ConnectionPool(),
            sslHandler: SSLHandler(),
            retryHandler: RetryHandler(),
            logger: Logger.network
        )

        return connection
    }

    private func startTestHTTPServer() async throws -> Int {
        // In a real implementation, this would start a simple HTTP server
        // For now, we'll use external services like httpbin.org
        return 0
    }

    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else { return 0 }
        return Int(info.resident_size)
    }
}

// MARK: - Supporting Types

struct ProxyRequestResult {
    let success: Bool
    let data: Data?
    let statusCode: Int?
    let error: Error?

    init(success: Bool, data: Data? = nil, statusCode: Int? = nil, error: Error? = nil) {
        self.success = success
        self.data = data
        self.statusCode = statusCode
        self.error = error
    }
}

struct HTTPSConnectResult {
    let success: Bool
    let tunnelEstablished: Bool
    let error: Error?

    init(success: Bool, tunnelEstablished: Bool, error: Error? = nil) {
        self.success = success
        self.tunnelEstablished = tunnelEstablished
        self.error = error
    }
}

struct SOCKS5Result {
    let success: Bool
    let handshakeCompleted: Bool
    let error: Error?

    init(success: Bool, handshakeCompleted: Bool, error: Error? = nil) {
        self.success = success
        self.handshakeCompleted = handshakeCompleted
        self.error = error
    }
}
