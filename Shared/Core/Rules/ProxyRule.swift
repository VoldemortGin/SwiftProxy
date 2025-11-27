import Foundation

// MARK: - Rule Action

/// Actions that can be taken when a rule matches
public enum RuleAction: String, Codable, CaseIterable {
    /// Connect directly without proxy
    case direct = "DIRECT"

    /// Use proxy server
    case proxy = "PROXY"

    /// Reject the connection
    case reject = "REJECT"

    /// Modify the request
    case modify = "MODIFY"

    /// Use specific proxy server
    case proxyServer = "PROXY-SERVER"

    public var description: String {
        switch self {
        case .direct:
            return "Direct connection (no proxy)"
        case .proxy:
            return "Use default proxy"
        case .reject:
            return "Reject connection"
        case .modify:
            return "Modify request"
        case .proxyServer:
            return "Use specific proxy server"
        }
    }
}

// MARK: - Rule Match Type

/// Types of matching criteria
public enum RuleMatchType: String, Codable {
    /// Match domain exactly
    case domain = "DOMAIN"

    /// Match domain suffix (e.g., .example.com)
    case domainSuffix = "DOMAIN-SUFFIX"

    /// Match domain keyword
    case domainKeyword = "DOMAIN-KEYWORD"

    /// Match using regular expression
    case domainRegex = "DOMAIN-REGEX"

    /// Match IP address
    case ipAddress = "IP-ADDR"

    /// Match IP CIDR range
    case ipCIDR = "IP-CIDR"

    /// Match port number
    case port = "PORT"

    /// Match port range
    case portRange = "PORT-RANGE"

    /// Match process name (macOS)
    case process = "PROCESS"

    /// Match user agent
    case userAgent = "USER-AGENT"

    /// Match URL pattern
    case urlPattern = "URL-PATTERN"

    /// Match based on GeoIP
    case geoIP = "GEOIP"

    /// Match all (catch-all rule)
    case final = "FINAL"
}

// MARK: - Proxy Rule

/// Represents a single proxy rule
public struct ProxyRule: Codable, Identifiable, Comparable, Hashable {
    public let id: UUID
    public var name: String
    public var matchType: RuleMatchType
    public var pattern: String
    public var action: RuleAction
    public var priority: Int
    public var enabled: Bool
    public var proxyServer: String? // For PROXY-SERVER action
    public var modifyHeaders: [String: String]? // For MODIFY action
    public var notes: String?

    // Metadata
    public var createdAt: Date
    public var updatedAt: Date
    public var matchCount: Int

    // MARK: - Comparable

    /// Compare rules by priority (higher priority comes first)
    public static func < (lhs: ProxyRule, rhs: ProxyRule) -> Bool {
        return lhs.priority < rhs.priority
    }

    public init(
        id: UUID = UUID(),
        name: String,
        matchType: RuleMatchType,
        pattern: String,
        action: RuleAction,
        priority: Int = 0,
        enabled: Bool = true,
        proxyServer: String? = nil,
        modifyHeaders: [String: String]? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.matchType = matchType
        self.pattern = pattern
        self.action = action
        self.priority = priority
        self.enabled = enabled
        self.proxyServer = proxyServer
        self.modifyHeaders = modifyHeaders
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.matchCount = 0
    }

    // MARK: - Rule Matching

    /// Check if this rule matches the given request
    public func matches(host: String, ip: String? = nil, port: Int? = nil) -> Bool {
        guard enabled else { return false }

        switch matchType {
        case .domain:
            return host.lowercased() == pattern.lowercased()

        case .domainSuffix:
            return host.lowercased().hasSuffix(pattern.lowercased())

        case .domainKeyword:
            return host.lowercased().contains(pattern.lowercased())

        case .domainRegex:
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return false
            }
            let range = NSRange(host.startIndex..., in: host)
            return regex.firstMatch(in: host, range: range) != nil

        case .ipAddress:
            guard let ip = ip else { return false }
            return ip == pattern

        case .ipCIDR:
            guard let ip = ip else { return false }
            return matchesCIDR(ip: ip, cidr: pattern)

        case .port:
            guard let port = port, let targetPort = Int(pattern) else { return false }
            return port == targetPort

        case .portRange:
            guard let port = port else { return false }
            return matchesPortRange(port: port, range: pattern)

        case .final:
            return true

        default:
            // Other match types require additional context
            return false
        }
    }

    // MARK: - Helper Methods

    private func matchesCIDR(ip: String, cidr: String) -> Bool {
        let components = cidr.components(separatedBy: "/")
        guard components.count == 2,
              let network = components.first,
              let prefixLength = Int(components.last ?? "") else {
            return false
        }

        // Convert IP addresses to integers for comparison
        guard let ipInt = ipToInt(ip),
              let networkInt = ipToInt(network) else {
            return false
        }

        // Create subnet mask
        let mask = ~UInt32(0) << (32 - prefixLength)

        // Check if IP is in the subnet
        return (ipInt & mask) == (networkInt & mask)
    }

    private func ipToInt(_ ip: String) -> UInt32? {
        let components = ip.components(separatedBy: ".")
        guard components.count == 4 else { return nil }

        var result: UInt32 = 0
        for (index, component) in components.enumerated() {
            guard let value = UInt32(component), value <= 255 else { return nil }
            result |= value << (8 * (3 - index))
        }

        return result
    }

    private func matchesPortRange(port: Int, range: String) -> Bool {
        let components = range.components(separatedBy: "-")
        guard components.count == 2,
              let startPort = Int(components[0]),
              let endPort = Int(components[1]) else {
            return false
        }

        return port >= startPort && port <= endPort
    }

    // MARK: - Rule String Representation

    /// Convert rule to Surge/Clash compatible string format
    public var ruleString: String {
        var components = [matchType.rawValue, pattern, action.rawValue]

        if let server = proxyServer, action == .proxyServer {
            components.append(server)
        }

        return components.joined(separator: ",")
    }

    /// Parse rule from Surge/Clash string format
    public static func parse(from string: String) -> ProxyRule? {
        let components = string.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count >= 3 else { return nil }

        guard let matchType = RuleMatchType(rawValue: components[0]),
              let action = RuleAction(rawValue: components[2]) else {
            return nil
        }

        let pattern = components[1]
        let proxyServer = components.count > 3 ? components[3] : nil

        return ProxyRule(
            name: "Imported Rule",
            matchType: matchType,
            pattern: pattern,
            action: action,
            proxyServer: proxyServer
        )
    }
}

// MARK: - Rule Group

/// A group of related proxy rules
public struct RuleGroup: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var rules: [ProxyRule]
    public var enabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        rules: [ProxyRule] = [],
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.rules = rules
        self.enabled = enabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Get active (enabled) rules sorted by priority
    public var activeRules: [ProxyRule] {
        guard enabled else { return [] }
        return rules.filter { $0.enabled }.sorted { $0.priority > $1.priority }
    }
}

// MARK: - Rule Match Result

/// Result of rule matching
public struct RuleMatchResult {
    public let rule: ProxyRule?
    public let action: RuleAction
    public let proxyServer: String?
    public let modifyHeaders: [String: String]?

    public init(
        rule: ProxyRule?,
        action: RuleAction,
        proxyServer: String? = nil,
        modifyHeaders: [String: String]? = nil
    ) {
        self.rule = rule
        self.action = action
        self.proxyServer = proxyServer
        self.modifyHeaders = modifyHeaders
    }

    /// Create a default DIRECT result when no rules match
    public static var direct: RuleMatchResult {
        RuleMatchResult(rule: nil, action: .direct)
    }

    /// Create a default PROXY result
    public static var proxy: RuleMatchResult {
        RuleMatchResult(rule: nil, action: .proxy)
    }
}

// MARK: - Validation Result

extension ProxyRule {
    /// Result of rule validation
    public struct ValidationResult {
        public let isValid: Bool
        public let errorMessage: String?

        public static var valid: ValidationResult {
            ValidationResult(isValid: true, errorMessage: nil)
        }

        public static func invalid(_ message: String) -> ValidationResult {
            ValidationResult(isValid: false, errorMessage: message)
        }
    }

    /// Validate the rule configuration
    public func validate() -> ValidationResult {
        // Check pattern is not empty
        guard !pattern.isEmpty || matchType == .final else {
            return .invalid("Pattern cannot be empty")
        }

        // Validate regex pattern if applicable
        if matchType == .domainRegex {
            guard (try? NSRegularExpression(pattern: pattern)) != nil else {
                return .invalid("Invalid regular expression pattern")
            }
        }

        // Validate IP CIDR format
        if matchType == .ipCIDR {
            let components = pattern.components(separatedBy: "/")
            guard components.count == 2,
                  ipToInt(components[0]) != nil,
                  let prefix = Int(components[1]),
                  prefix >= 0 && prefix <= 32 else {
                return .invalid("Invalid CIDR format")
            }
        }

        // Validate port range
        if matchType == .portRange {
            let components = pattern.components(separatedBy: "-")
            guard components.count == 2,
                  let start = Int(components[0]),
                  let end = Int(components[1]),
                  start > 0 && start <= 65535,
                  end > 0 && end <= 65535,
                  start <= end else {
                return .invalid("Invalid port range")
            }
        }

        return .valid
    }
}

// MARK: - Preset Rules

extension ProxyRule {
    /// Common preset rules
    public static let presets: [ProxyRule] = [
        // Block ads
        ProxyRule(
            name: "Block Ads",
            matchType: .domainSuffix,
            pattern: "doubleclick.net",
            action: .reject,
            priority: 100
        ),
        ProxyRule(
            name: "Block Analytics",
            matchType: .domainSuffix,
            pattern: "google-analytics.com",
            action: .reject,
            priority: 100
        ),

        // Direct China domains
        ProxyRule(
            name: "Direct .cn Domains",
            matchType: .domainSuffix,
            pattern: ".cn",
            action: .direct,
            priority: 90
        ),

        // Proxy international services
        ProxyRule(
            name: "Proxy Google",
            matchType: .domainSuffix,
            pattern: "google.com",
            action: .proxy,
            priority: 80
        ),
        ProxyRule(
            name: "Proxy YouTube",
            matchType: .domainSuffix,
            pattern: "youtube.com",
            action: .proxy,
            priority: 80
        ),
        ProxyRule(
            name: "Proxy Twitter",
            matchType: .domainSuffix,
            pattern: "twitter.com",
            action: .proxy,
            priority: 80
        ),

        // Direct local networks
        ProxyRule(
            name: "Direct Local Networks",
            matchType: .ipCIDR,
            pattern: "192.168.0.0/16",
            action: .direct,
            priority: 95
        ),
        ProxyRule(
            name: "Direct Localhost",
            matchType: .ipCIDR,
            pattern: "127.0.0.0/8",
            action: .direct,
            priority: 95
        ),

        // Default rule
        ProxyRule(
            name: "Default - Proxy All",
            matchType: .final,
            pattern: "",
            action: .proxy,
            priority: 0
        )
    ]
}

// MARK: - Rule Group Presets

extension RuleGroup {
    /// Common preset rule groups
    public static let presets: [RuleGroup] = [
        RuleGroup(
            name: "Global Proxy",
            description: "Proxy all traffic except local networks",
            rules: [
                ProxyRule(
                    name: "Direct Local",
                    matchType: .ipCIDR,
                    pattern: "192.168.0.0/16",
                    action: .direct,
                    priority: 100
                ),
                ProxyRule(
                    name: "Default Proxy",
                    matchType: .final,
                    pattern: "",
                    action: .proxy,
                    priority: 0
                )
            ]
        ),

        RuleGroup(
            name: "Smart Routing",
            description: "Intelligent routing based on domain patterns",
            rules: ProxyRule.presets
        ),

        RuleGroup(
            name: "Ad Blocking",
            description: "Block common ad and tracking domains",
            rules: [
                ProxyRule(
                    name: "Block Ads",
                    matchType: .domainKeyword,
                    pattern: "ads",
                    action: .reject,
                    priority: 100
                ),
                ProxyRule(
                    name: "Block Trackers",
                    matchType: .domainKeyword,
                    pattern: "tracker",
                    action: .reject,
                    priority: 100
                )
            ]
        )
    ]
}
