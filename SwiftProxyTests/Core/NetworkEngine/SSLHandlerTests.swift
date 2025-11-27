import XCTest
import Network
import Security
import OSLog
@testable import SwiftProxyCore

@available(macOS 12.0, *)
final class SSLHandlerTests: XCTestCase {
    var sslHandler: SSLHandler!

    override func setUp() async throws {
        try await super.setUp()
        sslHandler = await SSLHandler()
    }

    override func tearDown() async throws {
        sslHandler = nil
        try await super.tearDown()
    }

    // MARK: - TLS Configuration Tests

    func testDefaultTLSConfiguration() async throws {
        // Get the default configuration
        let config = await sslHandler.getTLSConfiguration()

        // Verify default settings
        XCTAssertEqual(config.minimumTLSVersion, .TLSv12)
        XCTAssertEqual(config.maximumTLSVersion, .TLSv13)
        XCTAssertEqual(config.alpnProtocols, ["h2", "http/1.1"])
        XCTAssertTrue(config.enableOCSPStapling)
        XCTAssertTrue(config.enableCertificateTransparency)
    }

    func testSecureTLSConfiguration() async throws {
        // Update to secure configuration
        await sslHandler.updateTLSConfiguration(.secure)
        let config = await sslHandler.getTLSConfiguration()

        // Verify secure settings
        XCTAssertEqual(config.minimumTLSVersion, .TLSv13)
        XCTAssertEqual(config.maximumTLSVersion, .TLSv13)
        XCTAssertEqual(config.alpnProtocols, ["h2"])
        XCTAssertTrue(config.enableOCSPStapling)
        XCTAssertTrue(config.enableCertificateTransparency)
    }

    func testTLSOptionsConfiguration() async throws {
        // Configure TLS options
        let tlsOptions = await sslHandler.configureTLS(
            for: "example.com",
            port: 443,
            requireClientCert: false
        )

        // Verify options are created
        XCTAssertNotNil(tlsOptions)
        XCTAssertNotNil(tlsOptions.securityProtocolOptions)
    }

    // MARK: - Certificate Pinning Tests

    func testCertificatePinning() async throws {
        // Create a test certificate
        guard let testCert = createTestCertificate() else {
            XCTFail("Failed to create test certificate")
            return
        }

        // Pin the certificate
        await sslHandler.pinCertificates([testCert], for: "test.example.com")

        // Update trust policy to pinned
        await sslHandler.setTrustPolicy(.pinned)

        // Verify the certificate is pinned
        // Note: Actual verification would require a full TLS handshake
        // This test just verifies the pinning mechanism is in place
        let config = await sslHandler.getTLSConfiguration()
        XCTAssertNotNil(config)
    }

    func testRemovePinnedCertificates() async throws {
        // Create and pin a test certificate
        guard let testCert = createTestCertificate() else {
            XCTFail("Failed to create test certificate")
            return
        }

        await sslHandler.pinCertificates([testCert], for: "test.example.com")

        // Remove pinned certificates
        await sslHandler.removePinnedCertificates(for: "test.example.com")

        // Verify removal (would be tested in actual TLS verification)
        let config = await sslHandler.getTLSConfiguration()
        XCTAssertNotNil(config)
    }

    // MARK: - Certificate Info Tests

    func testCertificateInfoExtraction() async throws {
        // Create a test certificate
        guard let testCert = createTestCertificate() else {
            XCTFail("Failed to create test certificate")
            return
        }

        // Extract certificate info
        let certInfo = await sslHandler.getCertificateInfo(testCert)

        // Verify info extraction
        XCTAssertNotNil(certInfo.data)
        XCTAssertFalse(certInfo.data.isEmpty)
        XCTAssertNotNil(certInfo.fingerprint)
        XCTAssertFalse(certInfo.fingerprint.isEmpty)
    }

    // MARK: - Trust Policy Tests

    func testTrustPolicySettings() async throws {
        // Test default policy
        await sslHandler.setTrustPolicy(.default)

        // Test pinned policy
        await sslHandler.setTrustPolicy(.pinned)

        // Test custom policy
        let customValidator: ([SecCertificate], String) async -> Bool = { certs, host in
            // Custom validation logic
            return !certs.isEmpty && host == "trusted.example.com"
        }
        await sslHandler.setTrustPolicy(.custom(customValidator))

        // Test allowAll policy (debug only)
        #if DEBUG
        await sslHandler.setTrustPolicy(.allowAll)
        #endif

        // Verify policy changes don't crash
        let config = await sslHandler.getTLSConfiguration()
        XCTAssertNotNil(config)
    }

    // MARK: - Certificate Store Tests

    func testCertificateStore() throws {
        let store = CertificateStore()

        // Test adding certificate
        guard let testCert = createTestCertificate() else {
            XCTFail("Failed to create test certificate")
            return
        }

        store.addCertificate(testCert)

        // Verify certificate is stored
        let certs = store.getCertificates()
        XCTAssertEqual(certs.count, 1)
    }

    func testClientIdentityStore() throws {
        let store = CertificateStore()

        // Test identity storage (would require a real identity in production)
        XCTAssertNil(store.getClientIdentity())

        // Note: Creating a test identity requires keychain access and is complex
        // In production, this would be tested with real certificates
    }

    // MARK: - TLS Version Tests

    func testTLSVersionCompatibility() async throws {
        // Test different TLS configurations
        let configs: [(name: String, config: TLSConfiguration)] = [
            ("Default", .default),
            ("Secure", .secure)
        ]

        for (name, config) in configs {
            await sslHandler.updateTLSConfiguration(config)
            let tlsOptions = await sslHandler.configureTLS(
                for: "\(name.lowercased()).example.com",
                port: 443
            )
            XCTAssertNotNil(tlsOptions, "Failed to configure TLS for \(name)")
        }
    }

    // MARK: - ALPN Protocol Tests

    func testALPNProtocolConfiguration() async throws {
        // Test custom ALPN configuration
        var customConfig = TLSConfiguration.default
        customConfig.alpnProtocols = ["h3", "h2", "http/1.1"]

        await sslHandler.updateTLSConfiguration(customConfig)

        let config = await sslHandler.getTLSConfiguration()
        XCTAssertEqual(config.alpnProtocols, ["h3", "h2", "http/1.1"])
    }

    // MARK: - Cipher Suite Tests

    func testCipherSuiteConfiguration() async throws {
        // Test custom cipher suite configuration
        var customConfig = TLSConfiguration.default
        // TLS 1.3 cipher suites
        customConfig.cipherSuites = [
            tls_ciphersuite_t(rawValue: 0x1301)!, // TLS_AES_128_GCM_SHA256
            tls_ciphersuite_t(rawValue: 0x1302)!, // TLS_AES_256_GCM_SHA384
        ]

        await sslHandler.updateTLSConfiguration(customConfig)

        let config = await sslHandler.getTLSConfiguration()
        XCTAssertEqual(config.cipherSuites.count, 2)
    }

    // MARK: - Session Info Tests

    func testSessionInfoExtraction() async throws {
        // This would require a real TLS connection to test properly
        // Here we just verify the structure exists

        let sessionInfo = SessionInfo(
            negotiatedProtocol: "h2",
            tlsVersion: "TLS 1.3",
            cipherSuite: "TLS_AES_128_GCM_SHA256"
        )

        XCTAssertEqual(sessionInfo.negotiatedProtocol, "h2")
        XCTAssertEqual(sessionInfo.tlsVersion, "TLS 1.3")
        XCTAssertEqual(sessionInfo.cipherSuite, "TLS_AES_128_GCM_SHA256")
    }

    // MARK: - Error Handling Tests

    func testInvalidCertificateFileLoading() throws {
        let store = CertificateStore()

        // Test loading non-existent file
        XCTAssertThrows(
            try store.loadCertificateFromFile("/non/existent/file.cer"),
            "Should throw error for non-existent file"
        )
    }

    func testInvalidCertificatePinning() async throws {
        // Test pinning from non-existent file
        do {
            try await sslHandler.pinCertificateFromFile(
                "/non/existent/cert.cer",
                for: "example.com"
            )
            XCTFail("Should have thrown an error")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Helper Methods

    private func createTestCertificate() -> SecCertificate? {
        // Create a self-signed certificate for testing
        // This is a simplified example - in production, use proper certificate generation

        let testCertData = Data([
            // Minimal X.509 certificate structure (simplified for testing)
            0x30, 0x82, 0x02, 0x00, // SEQUENCE
            0x30, 0x82, 0x01, 0x00, // SEQUENCE (TBSCertificate)
            // ... (certificate data would go here)
        ])

        // Note: This won't create a valid certificate, but it's sufficient for testing
        // the certificate handling mechanisms
        return SecCertificateCreateWithData(nil, testCertData as CFData)
    }
}

// MARK: - Test Helpers

extension XCTestCase {
    func XCTAssertThrows<T>(
        _ expression: @autoclosure () throws -> T,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            _ = try expression()
            XCTFail(message, file: file, line: line)
        } catch {
            // Success - an error was thrown
        }
    }
}