import XCTest
@testable import SwiftProxy

/// Comprehensive unit tests for ProxyConfiguration model
final class ProxyConfigurationTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        // Given & When
        let config = ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "127.0.0.1",
            port: 8080
        )

        // Then
        XCTAssertNotNil(config.id)
        XCTAssertEqual(config.name, "Test Proxy")
        XCTAssertEqual(config.type, .http)
        XCTAssertEqual(config.host, "127.0.0.1")
        XCTAssertEqual(config.port, 8080)
        XCTAssertFalse(config.requiresAuth)
        XCTAssertNil(config.username)
        XCTAssertNil(config.password)
        XCTAssertTrue(config.bypassDomains.isEmpty)
        XCTAssertFalse(config.proxyDNS)
        XCTAssertFalse(config.autoDetect)
        XCTAssertNotNil(config.createdAt)
        XCTAssertNotNil(config.updatedAt)
        XCTAssertNil(config.lastUsed)
    }

    func testInitializationWithAuthentication() {
        // Given & When
        let config = ProxyConfiguration(
            name: "Auth Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 3128,
            requiresAuth: true,
            username: "testuser",
            password: "testpass"
        )

        // Then
        XCTAssertTrue(config.requiresAuth)
        XCTAssertEqual(config.username, "testuser")
        XCTAssertEqual(config.password, "testpass")
    }

    func testInitializationWithBypassDomains() {
        // Given & When
        let config = ProxyConfiguration(
            name: "Bypass Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080,
            bypassDomains: ["localhost", "*.local", "192.168.1.0/24"]
        )

        // Then
        XCTAssertEqual(config.bypassDomains.count, 3)
        XCTAssertTrue(config.bypassDomains.contains("localhost"))
        XCTAssertTrue(config.bypassDomains.contains("*.local"))
    }

    // MARK: - Computed Properties Tests

    func testAddress() {
        // Given
        let config = ProxyConfiguration(
            name: "Test",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        // When
        let address = config.address

        // Then
        XCTAssertEqual(address, "proxy.example.com:8080")
    }

    func testURLGeneration() {
        // Given - HTTP proxy
        let httpConfig = ProxyConfiguration(
            name: "HTTP Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        // When
        let httpURL = httpConfig.url

        // Then
        XCTAssertNotNil(httpURL)
        XCTAssertEqual(httpURL?.scheme, "http")
        XCTAssertEqual(httpURL?.host, "proxy.example.com")
        XCTAssertEqual(httpURL?.port, 8080)
    }

    func testURLGenerationWithAuth() {
        // Given
        let config = ProxyConfiguration(
            name: "Auth Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080,
            requiresAuth: true,
            username: "user",
            password: "pass"
        )

        // When
        let url = config.url

        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.user, "user")
        XCTAssertEqual(url?.password, "pass")
    }

    func testPACString() {
        // Given
        let config = ProxyConfiguration(
            name: "Test",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        // When
        let pacString = config.pacString

        // Then
        XCTAssertEqual(pacString, "PROXY proxy.example.com:8080")
    }

    // MARK: - Validation Tests

    func testValidConfiguration() {
        // Given
        let config = ProxyConfiguration(
            name: "Valid Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testValidationWithEmptyHost() {
        // Given
        let config = ProxyConfiguration(
            name: "Invalid",
            type: .http,
            host: "",
            port: 8080
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Host cannot be empty")
    }

    func testValidationWithInvalidPort() {
        // Given
        let config = ProxyConfiguration(
            name: "Invalid Port",
            type: .http,
            host: "proxy.example.com",
            port: 0
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Port must be between 1 and 65535")
    }

    func testValidationWithInvalidHighPort() {
        // Given
        let config = ProxyConfiguration(
            name: "Invalid Port",
            type: .http,
            host: "proxy.example.com",
            port: 70000
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertFalse(result.isValid)
    }

    func testValidationWithMissingUsername() {
        // Given
        let config = ProxyConfiguration(
            name: "Missing User",
            type: .http,
            host: "proxy.example.com",
            port: 8080,
            requiresAuth: true,
            username: nil,
            password: "pass"
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Username required for authentication")
    }

    func testValidationWithMissingPassword() {
        // Given
        let config = ProxyConfiguration(
            name: "Missing Pass",
            type: .http,
            host: "proxy.example.com",
            port: 8080,
            requiresAuth: true,
            username: "user",
            password: nil
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Password required for authentication")
    }

    func testValidationWithIPv4Host() {
        // Given
        let config = ProxyConfiguration(
            name: "IP Proxy",
            type: .http,
            host: "192.168.1.1",
            port: 8080
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertTrue(result.isValid)
    }

    func testValidationWithInvalidIPv4() {
        // Given
        let config = ProxyConfiguration(
            name: "Invalid IP",
            type: .http,
            host: "256.1.1.1",
            port: 8080
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertFalse(result.isValid)
    }

    func testValidationWithInvalidDomain() {
        // Given
        let config = ProxyConfiguration(
            name: "Invalid Domain",
            type: .http,
            host: "not a valid domain!",
            port: 8080
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertFalse(result.isValid)
    }

    // MARK: - ProxyProtocolType Tests

    func testProxyProtocolTypeDisplayNames() {
        XCTAssertEqual(ProxyProtocolType.http.displayName, "HTTP")
        XCTAssertEqual(ProxyProtocolType.https.displayName, "HTTPS")
        XCTAssertEqual(ProxyProtocolType.socks5.displayName, "SOCKS5")
    }

    func testProxyProtocolTypeSchemes() {
        XCTAssertEqual(ProxyProtocolType.http.scheme, "http")
        XCTAssertEqual(ProxyProtocolType.https.scheme, "https")
        XCTAssertEqual(ProxyProtocolType.socks5.scheme, "socks5")
    }

    func testProxyProtocolTypeDefaultPorts() {
        XCTAssertEqual(ProxyProtocolType.http.defaultPort, 8080)
        XCTAssertEqual(ProxyProtocolType.https.defaultPort, 8443)
        XCTAssertEqual(ProxyProtocolType.socks5.defaultPort, 1080)
    }

    func testProxyProtocolTypeSupportsAuth() {
        XCTAssertTrue(ProxyProtocolType.http.supportsAuth)
        XCTAssertTrue(ProxyProtocolType.https.supportsAuth)
        XCTAssertTrue(ProxyProtocolType.socks5.supportsAuth)
    }

    // MARK: - Method Tests

    func testMarkAsUsed() {
        // Given
        var config = ProxyConfiguration(
            name: "Test",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )
        XCTAssertNil(config.lastUsed)

        // When
        config.markAsUsed()

        // Then
        XCTAssertNotNil(config.lastUsed)
        XCTAssertTrue(config.updatedAt > config.createdAt)
    }

    func testCopy() {
        // Given
        let original = ProxyConfiguration(
            name: "Original",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )
        let originalUpdated = original.updatedAt

        // Wait a bit to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        // When
        let copy = original.copy()

        // Then
        XCTAssertEqual(copy.id, original.id)
        XCTAssertEqual(copy.name, original.name)
        XCTAssertTrue(copy.updatedAt > originalUpdated)
    }

    // MARK: - Factory Methods Tests

    func testFromURLString() {
        // Test HTTP URL
        let httpConfig = ProxyConfiguration.from(urlString: "http://proxy.example.com:8080")
        XCTAssertNotNil(httpConfig)
        XCTAssertEqual(httpConfig?.type, .http)
        XCTAssertEqual(httpConfig?.host, "proxy.example.com")
        XCTAssertEqual(httpConfig?.port, 8080)
        XCTAssertFalse(httpConfig?.requiresAuth ?? true)

        // Test HTTPS URL
        let httpsConfig = ProxyConfiguration.from(urlString: "https://proxy.example.com:8443")
        XCTAssertNotNil(httpsConfig)
        XCTAssertEqual(httpsConfig?.type, .https)

        // Test SOCKS5 URL
        let socksConfig = ProxyConfiguration.from(urlString: "socks5://proxy.example.com:1080")
        XCTAssertNotNil(socksConfig)
        XCTAssertEqual(socksConfig?.type, .socks5)

        // Test URL with auth
        let authConfig = ProxyConfiguration.from(urlString: "http://user:pass@proxy.example.com:8080")
        XCTAssertNotNil(authConfig)
        XCTAssertTrue(authConfig?.requiresAuth ?? false)
        XCTAssertEqual(authConfig?.username, "user")
        XCTAssertEqual(authConfig?.password, "pass")

        // Test invalid URL
        let invalidConfig = ProxyConfiguration.from(urlString: "not-a-url")
        XCTAssertNil(invalidConfig)

        // Test unsupported scheme
        let ftpConfig = ProxyConfiguration.from(urlString: "ftp://proxy.example.com")
        XCTAssertNil(ftpConfig)
    }

    func testPresets() {
        // When
        let presets = ProxyConfiguration.presets

        // Then
        XCTAssertFalse(presets.isEmpty)
        XCTAssertTrue(presets.contains { $0.name == "Local Proxy" })
        XCTAssertTrue(presets.contains { $0.name == "SOCKS5 Local" })
    }

    // MARK: - System Configuration Tests

    func testToSystemConfigDict_HTTP() {
        // Given
        let config = ProxyConfiguration(
            name: "HTTP Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080,
            bypassDomains: ["localhost", "*.local"]
        )

        // When
        let dict = config.toSystemConfigDict()

        // Then
        XCTAssertEqual(dict[kCFNetworkProxiesHTTPEnable as String] as? Int, 1)
        XCTAssertEqual(dict[kCFNetworkProxiesHTTPProxy as String] as? String, "proxy.example.com")
        XCTAssertEqual(dict[kCFNetworkProxiesHTTPPort as String] as? Int, 8080)
        XCTAssertEqual((dict[kCFNetworkProxiesExceptionsList as String] as? [String])?.count, 2)
    }

    func testToSystemConfigDict_HTTPS() {
        // Given
        let config = ProxyConfiguration(
            name: "HTTPS Proxy",
            type: .https,
            host: "proxy.example.com",
            port: 8443
        )

        // When
        let dict = config.toSystemConfigDict()

        // Then
        XCTAssertEqual(dict[kCFNetworkProxiesHTTPSEnable as String] as? Int, 1)
        XCTAssertEqual(dict[kCFNetworkProxiesHTTPSProxy as String] as? String, "proxy.example.com")
        XCTAssertEqual(dict[kCFNetworkProxiesHTTPSPort as String] as? Int, 8443)
    }

    func testToSystemConfigDict_SOCKS5() {
        // Given
        let config = ProxyConfiguration(
            name: "SOCKS5 Proxy",
            type: .socks5,
            host: "proxy.example.com",
            port: 1080
        )

        // When
        let dict = config.toSystemConfigDict()

        // Then
        XCTAssertEqual(dict[kCFNetworkProxiesSOCKSEnable as String] as? Int, 1)
        XCTAssertEqual(dict[kCFNetworkProxiesSOCKSProxy as String] as? String, "proxy.example.com")
        XCTAssertEqual(dict[kCFNetworkProxiesSOCKSPort as String] as? Int, 1080)
    }

    func testToURLSessionProxyDict() {
        // Given
        let config = ProxyConfiguration(
            name: "Test",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        // When
        let dict = config.toURLSessionProxyDict()

        // Then
        XCTAssertEqual(dict[kCFNetworkProxiesHTTPEnable] as? Int, 1)
        XCTAssertEqual(dict[kCFNetworkProxiesHTTPProxy] as? String, "proxy.example.com")
        XCTAssertEqual(dict[kCFNetworkProxiesHTTPPort] as? Int, 8080)
    }

    // MARK: - Codable Tests

    func testEncodingDecoding() throws {
        // Given
        let original = ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080,
            requiresAuth: true,
            username: "user",
            password: "pass",
            bypassDomains: ["localhost"],
            proxyDNS: true,
            autoDetect: false,
            description: "Test description"
        )

        // When - encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        // Then - decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProxyConfiguration.self, from: data)

        // Verify
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.host, original.host)
        XCTAssertEqual(decoded.port, original.port)
        XCTAssertEqual(decoded.requiresAuth, original.requiresAuth)
        XCTAssertEqual(decoded.username, original.username)
        // Note: password is not encoded/decoded
        XCTAssertNil(decoded.password)
        XCTAssertEqual(decoded.bypassDomains, original.bypassDomains)
        XCTAssertEqual(decoded.proxyDNS, original.proxyDNS)
        XCTAssertEqual(decoded.autoDetect, original.autoDetect)
        XCTAssertEqual(decoded.description, original.description)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        // Given
        let id = UUID()
        let config1 = ProxyConfiguration(
            id: id,
            name: "Test",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )
        let config2 = ProxyConfiguration(
            id: id,
            name: "Test",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )
        let config3 = ProxyConfiguration(
            name: "Different",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        // Then
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }

    // MARK: - Hashable Tests

    func testHashability() {
        // Given
        let config1 = ProxyConfiguration(
            name: "Test1",
            type: .http,
            host: "proxy1.example.com",
            port: 8080
        )
        let config2 = ProxyConfiguration(
            name: "Test2",
            type: .http,
            host: "proxy2.example.com",
            port: 8080
        )

        // When
        var set = Set<ProxyConfiguration>()
        set.insert(config1)
        set.insert(config2)
        set.insert(config1) // Duplicate

        // Then
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - CustomStringConvertible Tests

    func testDescription() {
        // Given
        let config = ProxyConfiguration(
            name: "Test Proxy",
            type: .http,
            host: "proxy.example.com",
            port: 8080
        )

        // When
        let description = config.description

        // Then
        XCTAssertTrue(description.contains("Test Proxy"))
        XCTAssertTrue(description.contains("HTTP"))
        XCTAssertTrue(description.contains("proxy.example.com:8080"))
    }

    // MARK: - Edge Cases

    func testMinimumValidPort() {
        // Given
        let config = ProxyConfiguration(
            name: "Min Port",
            type: .http,
            host: "proxy.example.com",
            port: 1
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertTrue(result.isValid)
    }

    func testMaximumValidPort() {
        // Given
        let config = ProxyConfiguration(
            name: "Max Port",
            type: .http,
            host: "proxy.example.com",
            port: 65535
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertTrue(result.isValid)
    }

    func testBypassDomainWithWildcard() {
        // Given
        let config = ProxyConfiguration(
            name: "Wildcard Bypass",
            type: .http,
            host: "proxy.example.com",
            port: 8080,
            bypassDomains: ["*.local", "*.internal.example.com"]
        )

        // When
        let result = config.validate()

        // Then
        XCTAssertTrue(result.isValid)
    }
}
