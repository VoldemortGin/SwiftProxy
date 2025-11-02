import Foundation
import Network
import Security
import OSLog

/// Handles SSL/TLS connections, certificate validation, and secure communication
/// Provides certificate pinning, custom trust evaluation, and protocol negotiation
@available(macOS 12.0, *)
public actor SSLHandler {
    // MARK: - Properties

    private let logger: OSLog
    private var certificateStore: CertificateStore
    private var tlsConfiguration: TLSConfiguration

    // Certificate pinning
    private var pinnedCertificates: [String: [SecCertificate]] = [:]

    // Trust evaluation policy
    private var trustPolicy: TrustPolicy = .default

    // MARK: - Initialization

    public init(
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "SSLHandler"),
        certificateStore: CertificateStore = CertificateStore()
    ) {
        self.logger = logger
        self.certificateStore = certificateStore
        self.tlsConfiguration = TLSConfiguration.default
    }

    // MARK: - TLS Configuration

    /// Configure TLS options for a connection
    public func configureTLS(
        for host: String,
        port: Int,
        requireClientCert: Bool = false
    ) -> NWProtocolTLS.Options {
        let tlsOptions = NWProtocolTLS.Options()

        // Set minimum TLS version
        if let minVersion = tlsConfiguration.minimumTLSVersion {
            sec_protocol_options_set_min_tls_protocol_version(
                tlsOptions.securityProtocolOptions,
                minVersion
            )
        }

        // Set maximum TLS version
        if let maxVersion = tlsConfiguration.maximumTLSVersion {
            sec_protocol_options_set_max_tls_protocol_version(
                tlsOptions.securityProtocolOptions,
                maxVersion
            )
        }

        // Configure ALPN protocols
        for alpn in tlsConfiguration.alpnProtocols {
            alpn.withCString { cString in
                sec_protocol_options_add_tls_application_protocol(
                    tlsOptions.securityProtocolOptions,
                    cString
                )
            }
        }

        // Configure cipher suites
        if !tlsConfiguration.cipherSuites.isEmpty {
            for suite in tlsConfiguration.cipherSuites {
                sec_protocol_options_append_tls_ciphersuite(
                    tlsOptions.securityProtocolOptions,
                    suite
                )
            }
        }

        // Configure custom verification
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { [weak self] metadata, trust, completionHandler in
                Task {
                    let result = await self?.verifyServerTrust(
                        metadata: metadata,
                        trust: trust,
                        host: host
                    ) ?? false
                    completionHandler(result)
                }
            },
            DispatchQueue.global(qos: .userInitiated)
        )

        // Configure client certificate if required
        if requireClientCert {
            if let identity = certificateStore.getClientIdentity() {
                sec_protocol_options_set_local_identity(
                    tlsOptions.securityProtocolOptions,
                    sec_identity_create(identity)!
                )
            }
        }

        return tlsOptions
    }

    // MARK: - Certificate Verification

    private func verifyServerTrust(
        metadata: sec_protocol_metadata_t,
        trust: sec_trust_t,
        host: String
    ) async -> Bool {
        os_log(.debug, log: logger, "Verifying server certificate for \(host)")

        // Convert sec_trust_t to SecTrust
        let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()

        // Get server certificates
        guard let certChain = SecTrustCopyCertificateChain(secTrust) as? [SecCertificate],
              !certChain.isEmpty else {
            os_log(.error, log: logger, "No certificates found in chain")
            return false
        }

        // Apply trust policy
        switch trustPolicy {
        case .default:
            return await verifyDefaultTrust(trust: secTrust, host: host)

        case .pinned:
            return await verifyPinnedCertificate(certificates: certChain, host: host)

        case .custom(let validator):
            return await validator(certChain, host)

        case .allowAll:
            #if DEBUG
            os_log(.default, log: logger, "⚠️ Allowing all certificates (DEBUG ONLY - insecure)")
            return true
            #else
            os_log(.error, log: logger, "🚫 allowAll trust policy is disabled in production builds")
            return false
            #endif
        }
    }

    private func verifyDefaultTrust(trust: SecTrust, host: String) async -> Bool {
        // Use system's default trust evaluation
        var error: CFError?
        let result = SecTrustEvaluateWithError(trust, &error)

        if let error = error {
            os_log(.error, log: logger, "Trust evaluation failed: \(error.localizedDescription)")
        }

        return result
    }

    private func verifyPinnedCertificate(
        certificates: [SecCertificate],
        host: String
    ) async -> Bool {
        guard let pinnedCerts = pinnedCertificates[host] else {
            os_log(.default, log: logger, "No pinned certificates for \(host)")
            return false
        }

        // Check if any certificate in the chain matches pinned certificates
        for serverCert in certificates {
            for pinnedCert in pinnedCerts {
                if certificatesMatch(serverCert, pinnedCert) {
                    os_log(.info, log: logger, "Certificate matched pinned certificate for \(host)")
                    return true
                }
            }
        }

        os_log(.error, log: logger, "No matching pinned certificate found for \(host)")
        return false
    }

    private func certificatesMatch(_ cert1: SecCertificate, _ cert2: SecCertificate) -> Bool {
        let data1 = SecCertificateCopyData(cert1) as Data
        let data2 = SecCertificateCopyData(cert2) as Data
        return data1 == data2
    }

    // MARK: - Certificate Pinning

    /// Pin certificates for a specific host
    public func pinCertificates(_ certificates: [SecCertificate], for host: String) {
        pinnedCertificates[host] = certificates
        os_log(.info, log: logger, "Pinned \(certificates.count) certificate(s) for \(host)")
    }

    /// Load and pin certificate from file
    public func pinCertificateFromFile(_ path: String, for host: String) throws {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)

        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            throw AppError.sslError("Failed to create certificate from data")
        }

        pinnedCertificates[host] = [certificate]
        os_log(.info, log: logger, "Pinned certificate from file for \(host)")
    }

    /// Remove pinned certificates for a host
    public func removePinnedCertificates(for host: String) {
        pinnedCertificates.removeValue(forKey: host)
        os_log(.info, log: logger, "Removed pinned certificates for \(host)")
    }

    // MARK: - Trust Policy

    public func setTrustPolicy(_ policy: TrustPolicy) {
        trustPolicy = policy
        os_log(.info, log: logger, "Updated trust policy: \(policy)")
    }

    // MARK: - Certificate Info

    /// Extract information from a certificate
    public func getCertificateInfo(_ certificate: SecCertificate) -> CertificateInfo {
        var commonName: CFString?
        SecCertificateCopyCommonName(certificate, &commonName)

        let data = SecCertificateCopyData(certificate) as Data
        let summary = SecCertificateCopySubjectSummary(certificate) as String?

        return CertificateInfo(
            commonName: commonName as String?,
            summary: summary,
            data: data,
            publicKeyData: extractPublicKey(from: certificate)
        )
    }

    private func extractPublicKey(from certificate: SecCertificate) -> Data? {
        var publicKey: SecKey?
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?

        let status = SecTrustCreateWithCertificates(
            certificate,
            policy,
            &trust
        )

        guard status == errSecSuccess, let trust = trust else {
            return nil
        }

        publicKey = SecTrustCopyKey(trust)

        guard let key = publicKey else {
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            return nil
        }

        return keyData
    }

    // MARK: - Session Management

    /// Extract negotiated protocol information
    public func getSessionInfo(from metadata: sec_protocol_metadata_t) -> SessionInfo {
        let negotiatedProtocol = sec_protocol_metadata_get_negotiated_protocol(metadata)
        let negotiatedTLSVersion = sec_protocol_metadata_get_negotiated_tls_protocol_version(metadata)
        let cipherSuite = sec_protocol_metadata_get_negotiated_tls_ciphersuite(metadata)

        let protocolString = negotiatedProtocol.map { String(cString: $0) } ?? "unknown"

        return SessionInfo(
            negotiatedProtocol: protocolString,
            tlsVersion: tlsVersionString(negotiatedTLSVersion),
            cipherSuite: cipherSuiteString(cipherSuite)
        )
    }

    private func tlsVersionString(_ version: tls_protocol_version_t) -> String {
        switch version {
        case .TLSv10:
            return "TLS 1.0"
        case .TLSv11:
            return "TLS 1.1"
        case .TLSv12:
            return "TLS 1.2"
        case .TLSv13:
            return "TLS 1.3"
        default:
            return "Unknown"
        }
    }

    private func cipherSuiteString(_ suite: tls_ciphersuite_t) -> String {
        // Map common cipher suites
        switch suite.rawValue {
        case 0x1301:
            return "TLS_AES_128_GCM_SHA256"
        case 0x1302:
            return "TLS_AES_256_GCM_SHA384"
        case 0x1303:
            return "TLS_CHACHA20_POLY1305_SHA256"
        default:
            return "0x\(String(format: "%04X", suite.rawValue))"
        }
    }
}

// MARK: - TLS Configuration

public struct TLSConfiguration {
    public var minimumTLSVersion: tls_protocol_version_t?
    public var maximumTLSVersion: tls_protocol_version_t?
    public var alpnProtocols: [String]
    public var cipherSuites: [tls_ciphersuite_t]

    public static let `default` = TLSConfiguration(
        minimumTLSVersion: .TLSv12,
        maximumTLSVersion: .TLSv13,
        alpnProtocols: ["h2", "http/1.1"],
        cipherSuites: []
    )

    public static let secure = TLSConfiguration(
        minimumTLSVersion: .TLSv13,
        maximumTLSVersion: .TLSv13,
        alpnProtocols: ["h2"],
        cipherSuites: []
    )
}

// MARK: - Trust Policy

public enum TrustPolicy {
    case `default`
    case pinned
    case custom((([SecCertificate], String) async -> Bool))
    case allowAll // For testing only, NOT recommended for production
}

extension TrustPolicy: CustomStringConvertible {
    public var description: String {
        switch self {
        case .default:
            return "default"
        case .pinned:
            return "pinned"
        case .custom:
            return "custom"
        case .allowAll:
            return "allowAll"
        }
    }
}

// MARK: - Certificate Store

public class CertificateStore {
    private var clientIdentity: SecIdentity?
    private var certificates: [SecCertificate] = []

    public init() {}

    public func setClientIdentity(_ identity: SecIdentity) {
        self.clientIdentity = identity
    }

    public func getClientIdentity() -> SecIdentity? {
        return clientIdentity
    }

    public func addCertificate(_ certificate: SecCertificate) {
        certificates.append(certificate)
    }

    public func getCertificates() -> [SecCertificate] {
        return certificates
    }

    public func loadCertificateFromFile(_ path: String) throws {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)

        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            throw AppError.sslError("Failed to load certificate")
        }

        certificates.append(certificate)
    }
}

// MARK: - Certificate Info

public struct CertificateInfo {
    public let commonName: String?
    public let summary: String?
    public let data: Data
    public let publicKeyData: Data?

    public var fingerprint: String {
        data.sha256Hex
    }
}

// MARK: - Session Info

public struct SessionInfo {
    public let negotiatedProtocol: String
    public let tlsVersion: String
    public let cipherSuite: String
}

// MARK: - Extensions

extension Data {
    var sha256: Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }

    var sha256Hex: String {
        sha256.map { String(format: "%02x", $0) }.joined()
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto
