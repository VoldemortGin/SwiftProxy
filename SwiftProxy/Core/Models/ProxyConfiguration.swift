import Foundation

/// Represents a complete proxy server configuration
/// Supports HTTP, HTTPS, and SOCKS5 proxy types
public struct ProxyConfiguration: Identifiable, Codable, Equatable, Hashable {
    // MARK: - Properties

    public let id: UUID
    public var name: String
    public var type: ProxyProtocolType
    public var host: String
    public var port: Int

    // Authentication
    public var requiresAuth: Bool
    public var username: String?
    public var password: String? // Will be stored in Keychain

    // Advanced settings
    public var bypassDomains: [String]
    public var proxyDNS: Bool
    public var autoDetect: Bool

    // Metadata
    public var description: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var lastUsed: Date?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        type: ProxyProtocolType,
        host: String,
        port: Int,
        requiresAuth: Bool = false,
        username: String? = nil,
        password: String? = nil,
        bypassDomains: [String] = [],
        proxyDNS: Bool = false,
        autoDetect: Bool = false,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.host = host
        self.port = port
        self.requiresAuth = requiresAuth
        self.username = username
        self.password = password
        self.bypassDomains = bypassDomains
        self.proxyDNS = proxyDNS
        self.autoDetect = autoDetect
        self.description = description
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastUsed = nil
    }

    // MARK: - Computed Properties

    /// Full proxy address in format "host:port"
    public var address: String {
        "\(host):\(port)"
    }

    /// URL representation of the proxy
    public var url: URL? {
        guard var components = URLComponents() else { return nil }

        components.scheme = type.scheme
        components.host = host
        components.port = port

        if requiresAuth, let username = username {
            components.user = username
            components.password = password
        }

        return components.url
    }

    /// PAC (Proxy Auto-Configuration) format string
    public var pacString: String {
        "PROXY \(host):\(port)"
    }

    // MARK: - Validation

    public func validate() -> ValidationResult {
        // Validate host
        guard !host.isEmpty else {
            return .invalid("Host cannot be empty")
        }

        guard isValidHost(host) else {
            return .invalid("Invalid host format")
        }

        // Validate port
        guard (1...65535).contains(port) else {
            return .invalid("Port must be between 1 and 65535")
        }

        // Validate authentication
        if requiresAuth {
            guard let username = username, !username.isEmpty else {
                return .invalid("Username required for authentication")
            }

            guard let password = password, !password.isEmpty else {
                return .invalid("Password required for authentication")
            }
        }

        // Validate bypass domains
        for domain in bypassDomains {
            if !isValidDomainPattern(domain) {
                return .invalid("Invalid bypass domain: \(domain)")
            }
        }

        return .valid
    }

    private func isValidHost(_ host: String) -> Bool {
        // Check if it's a valid IP address
        if isValidIPv4(host) {
            return true
        }

        // Check if it's a valid domain name
        let domainPattern = "^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
        return host.range(of: domainPattern, options: .regularExpression) != nil
    }

    private func isValidIPv4(_ ip: String) -> Bool {
        let components = ip.split(separator: ".").compactMap { Int($0) }
        guard components.count == 4 else { return false }
        return components.allSatisfy { (0...255).contains($0) }
    }

    private func isValidDomainPattern(_ pattern: String) -> Bool {
        // Allow wildcards for bypass domains
        let cleanPattern = pattern.replacingOccurrences(of: "*", with: "a")
        return isValidHost(cleanPattern.hasPrefix(".") ? String(cleanPattern.dropFirst()) : cleanPattern)
    }

    public enum ValidationResult {
        case valid
        case invalid(String)

        public var isValid: Bool {
            if case .valid = self { return true }
            return false
        }

        public var errorMessage: String? {
            if case .invalid(let message) = self { return message }
            return nil
        }
    }

    // MARK: - Methods

    /// Update the last used timestamp
    public mutating func markAsUsed() {
        lastUsed = Date()
        updatedAt = Date()
    }

    /// Create a copy for editing
    public func copy() -> ProxyConfiguration {
        var config = self
        config.updatedAt = Date()
        return config
    }
}

// MARK: - Supporting Types

/// Supported proxy protocol types
public enum ProxyProtocolType: String, Codable, CaseIterable {
    case http = "HTTP"
    case https = "HTTPS"
    case socks5 = "SOCKS5"

    public var displayName: String {
        rawValue
    }

    public var scheme: String {
        switch self {
        case .http:
            return "http"
        case .https:
            return "https"
        case .socks5:
            return "socks5"
        }
    }

    public var defaultPort: Int {
        switch self {
        case .http:
            return 8080
        case .https:
            return 8443
        case .socks5:
            return 1080
        }
    }

    public var supportsAuth: Bool {
        switch self {
        case .http, .https, .socks5:
            return true
        }
    }

    public var systemImageName: String {
        switch self {
        case .http:
            return "network"
        case .https:
            return "lock.shield"
        case .socks5:
            return "server.rack"
        }
    }
}

// MARK: - Preset Configurations

extension ProxyConfiguration {
    /// Create a configuration from a URL string
    public static func from(urlString: String) -> ProxyConfiguration? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              let host = url.host else {
            return nil
        }

        let type: ProxyProtocolType
        switch scheme.lowercased() {
        case "http":
            type = .http
        case "https":
            type = .https
        case "socks5", "socks":
            type = .socks5
        default:
            return nil
        }

        let port = url.port ?? type.defaultPort
        let requiresAuth = url.user != nil
        let username = url.user
        let password = url.password

        return ProxyConfiguration(
            name: host,
            type: type,
            host: host,
            port: port,
            requiresAuth: requiresAuth,
            username: username,
            password: password
        )
    }

    /// Common preset configurations for testing
    public static var presets: [ProxyConfiguration] {
        [
            ProxyConfiguration(
                name: "Local Proxy",
                type: .http,
                host: "127.0.0.1",
                port: 8080,
                description: "Local proxy server"
            ),
            ProxyConfiguration(
                name: "SOCKS5 Local",
                type: .socks5,
                host: "127.0.0.1",
                port: 1080,
                description: "Local SOCKS5 proxy"
            )
        ]
    }
}

// MARK: - System Configuration

/// Maps to SystemConfiguration framework proxy dictionary
extension ProxyConfiguration {
    /// Convert to SystemConfiguration proxy dictionary
    public func toSystemConfigDict() -> [String: Any] {
        var dict: [String: Any] = [:]

        switch type {
        case .http:
            dict[kCFNetworkProxiesHTTPEnable as String] = 1
            dict[kCFNetworkProxiesHTTPProxy as String] = host
            dict[kCFNetworkProxiesHTTPPort as String] = port

        case .https:
            dict[kCFNetworkProxiesHTTPSEnable as String] = 1
            dict[kCFNetworkProxiesHTTPSProxy as String] = host
            dict[kCFNetworkProxiesHTTPSPort as String] = port

        case .socks5:
            dict[kCFNetworkProxiesSOCKSEnable as String] = 1
            dict[kCFNetworkProxiesSOCKSProxy as String] = host
            dict[kCFNetworkProxiesSOCKSPort as String] = port
        }

        // Add bypass domains
        if !bypassDomains.isEmpty {
            dict[kCFNetworkProxiesExceptionsList as String] = bypassDomains
        }

        return dict
    }

    /// Convert to URLSessionConfiguration proxy dictionary
    public func toURLSessionProxyDict() -> [AnyHashable: Any] {
        var dict: [AnyHashable: Any] = [:]

        switch type {
        case .http:
            dict[kCFNetworkProxiesHTTPEnable] = 1
            dict[kCFNetworkProxiesHTTPProxy] = host
            dict[kCFNetworkProxiesHTTPPort] = port

        case .https:
            dict[kCFNetworkProxiesHTTPSEnable] = 1
            dict[kCFNetworkProxiesHTTPSProxy] = host
            dict[kCFNetworkProxiesHTTPSPort] = port

        case .socks5:
            dict[kCFNetworkProxiesSOCKSEnable] = 1
            dict[kCFNetworkProxiesSOCKSProxy] = host
            dict[kCFNetworkProxiesSOCKSPort] = port
        }

        if !bypassDomains.isEmpty {
            dict[kCFNetworkProxiesExceptionsList] = bypassDomains
        }

        return dict
    }
}

// MARK: - CustomStringConvertible

extension ProxyConfiguration: CustomStringConvertible {
    public var description: String {
        "\(name) (\(type.rawValue)://\(address))"
    }
}

// MARK: - Codable Custom Implementation

extension ProxyConfiguration {
    enum CodingKeys: String, CodingKey {
        case id, name, type, host, port
        case requiresAuth, username
        // Note: password is NOT encoded here - it should be stored in Keychain
        case bypassDomains, proxyDNS, autoDetect
        case description, createdAt, updatedAt, lastUsed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ProxyProtocolType.self, forKey: .type)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(Int.self, forKey: .port)
        requiresAuth = try container.decode(Bool.self, forKey: .requiresAuth)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        // Password will be loaded from Keychain separately
        password = nil
        bypassDomains = try container.decode([String].self, forKey: .bypassDomains)
        proxyDNS = try container.decode(Bool.self, forKey: .proxyDNS)
        autoDetect = try container.decode(Bool.self, forKey: .autoDetect)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastUsed = try container.decodeIfPresent(Date.self, forKey: .lastUsed)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(host, forKey: .host)
        try container.encode(port, forKey: .port)
        try container.encode(requiresAuth, forKey: .requiresAuth)
        try container.encodeIfPresent(username, forKey: .username)
        // Password is NOT encoded - stored in Keychain
        try container.encode(bypassDomains, forKey: .bypassDomains)
        try container.encode(proxyDNS, forKey: .proxyDNS)
        try container.encode(autoDetect, forKey: .autoDetect)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(lastUsed, forKey: .lastUsed)
    }
}
