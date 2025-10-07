import Foundation

/// Represents a proxy routing rule that determines how traffic is handled
/// Rules can match based on domain patterns, URL patterns, or IP addresses
public struct ProxyRule: Identifiable, Codable, Equatable, Hashable {
    // MARK: - Properties

    public let id: UUID
    public var name: String
    public var pattern: String
    public var matchType: MatchType
    public var action: RuleAction
    public var priority: Int
    public var isEnabled: Bool

    public var ruleDescription: String?
    public var createdAt: Date
    public var updatedAt: Date

    // Advanced options
    public var caseSensitive: Bool
    public var processFilter: ProcessFilter?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        pattern: String,
        matchType: MatchType,
        action: RuleAction,
        priority: Int = 0,
        isEnabled: Bool = true,
        ruleDescription: String? = nil,
        caseSensitive: Bool = false,
        processFilter: ProcessFilter? = nil
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.matchType = matchType
        self.action = action
        self.priority = priority
        self.isEnabled = isEnabled
        self.ruleDescription = ruleDescription
        self.caseSensitive = caseSensitive
        self.processFilter = processFilter
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Matching Logic

    /// Test if this rule matches the given request
    public func matches(_ request: NetworkRequest) -> Bool {
        guard isEnabled else { return false }

        // Check process filter if specified
        if let filter = processFilter, !filter.matches(request) {
            return false
        }

        // Perform pattern matching based on match type
        switch matchType {
        case .domain:
            return matchesDomain(request.host)
        case .domainSuffix:
            return matchesDomainSuffix(request.host)
        case .domainKeyword:
            return matchesDomainKeyword(request.host)
        case .urlPattern:
            return matchesURLPattern(request.url.absoluteString)
        case .ipAddress:
            return matchesIPAddress(request.host)
        case .ipCIDR:
            return matchesIPCIDR(request.host)
        case .regex:
            return matchesRegex(request.url.absoluteString)
        }
    }

    // MARK: - Private Matching Methods

    private func matchesDomain(_ host: String) -> Bool {
        let compareHost = caseSensitive ? host : host.lowercased()
        let comparePattern = caseSensitive ? pattern : pattern.lowercased()
        return compareHost == comparePattern
    }

    private func matchesDomainSuffix(_ host: String) -> Bool {
        let compareHost = caseSensitive ? host : host.lowercased()
        let comparePattern = caseSensitive ? pattern : pattern.lowercased()
        return compareHost.hasSuffix(comparePattern) ||
               compareHost == comparePattern.dropFirst() // Handle .example.com matching example.com
    }

    private func matchesDomainKeyword(_ host: String) -> Bool {
        let compareHost = caseSensitive ? host : host.lowercased()
        let comparePattern = caseSensitive ? pattern : pattern.lowercased()
        return compareHost.contains(comparePattern)
    }

    private func matchesURLPattern(_ url: String) -> Bool {
        let compareURL = caseSensitive ? url : url.lowercased()
        let comparePattern = caseSensitive ? pattern : pattern.lowercased()

        // Convert wildcard pattern to regex
        let regexPattern = comparePattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")

        return matchesRegexPattern(compareURL, pattern: "^" + regexPattern + "$")
    }

    private func matchesIPAddress(_ host: String) -> Bool {
        return host == pattern
    }

    private func matchesIPCIDR(_ host: String) -> Bool {
        // Parse CIDR notation and check if IP is in range
        guard let (networkIP, prefixLength) = parseCIDR(pattern),
              let hostIP = parseIPv4(host) else {
            return false
        }

        let mask = createNetworkMask(prefixLength: prefixLength)
        let network = networkIP & mask
        let hostNetwork = hostIP & mask

        return network == hostNetwork
    }

    private func matchesRegex(_ url: String) -> Bool {
        return matchesRegexPattern(url, pattern: pattern)
    }

    private func matchesRegexPattern(_ text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : .caseInsensitive) else {
            return false
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    // MARK: - IP Parsing Utilities

    private func parseIPv4(_ ip: String) -> UInt32? {
        let components = ip.split(separator: ".").compactMap { UInt32($0) }
        guard components.count == 4, components.allSatisfy({ $0 <= 255 }) else {
            return nil
        }

        return (components[0] << 24) | (components[1] << 16) | (components[2] << 8) | components[3]
    }

    private func parseCIDR(_ cidr: String) -> (ip: UInt32, prefixLength: Int)? {
        let parts = cidr.split(separator: "/")
        guard parts.count == 2,
              let ip = parseIPv4(String(parts[0])),
              let prefixLength = Int(parts[1]),
              (0...32).contains(prefixLength) else {
            return nil
        }

        return (ip, prefixLength)
    }

    private func createNetworkMask(prefixLength: Int) -> UInt32 {
        guard prefixLength > 0 else { return 0 }
        return ~UInt32(0) << (32 - prefixLength)
    }
}

// MARK: - Supporting Types

/// Defines how a rule should be matched against incoming requests
public enum MatchType: String, Codable, CaseIterable {
    case domain = "DOMAIN"                      // Exact domain match
    case domainSuffix = "DOMAIN-SUFFIX"         // Matches domain and all subdomains
    case domainKeyword = "DOMAIN-KEYWORD"       // Domain contains keyword
    case urlPattern = "URL-PATTERN"             // Wildcard pattern matching
    case ipAddress = "IP-ADDRESS"               // Exact IP match
    case ipCIDR = "IP-CIDR"                     // IP CIDR range
    case regex = "REGEX"                        // Regular expression

    public var displayName: String {
        switch self {
        case .domain: return "Domain"
        case .domainSuffix: return "Domain Suffix"
        case .domainKeyword: return "Domain Keyword"
        case .urlPattern: return "URL Pattern"
        case .ipAddress: return "IP Address"
        case .ipCIDR: return "IP CIDR"
        case .regex: return "Regular Expression"
        }
    }

    public var examplePattern: String {
        switch self {
        case .domain: return "example.com"
        case .domainSuffix: return ".example.com"
        case .domainKeyword: return "example"
        case .urlPattern: return "*.example.com/api/*"
        case .ipAddress: return "192.168.1.1"
        case .ipCIDR: return "192.168.1.0/24"
        case .regex: return "^https://.*\\.example\\.com/.*$"
        }
    }
}

/// Defines what action to take when a rule matches
public enum RuleAction: String, Codable, CaseIterable {
    case direct = "DIRECT"      // Direct connection, bypass proxy
    case proxy = "PROXY"        // Route through proxy
    case reject = "REJECT"      // Block the request

    public var displayName: String {
        switch self {
        case .direct: return "Direct"
        case .proxy: return "Proxy"
        case .reject: return "Reject"
        }
    }

    public var systemImageName: String {
        switch self {
        case .direct: return "arrow.right"
        case .proxy: return "arrow.triangle.turn.up.right.diamond"
        case .reject: return "xmark.circle"
        }
    }
}

/// Optional process filtering for rules
public struct ProcessFilter: Codable, Equatable, Hashable {
    public var processNames: Set<String>
    public var matchMode: MatchMode

    public enum MatchMode: String, Codable {
        case include = "include"    // Only match specified processes
        case exclude = "exclude"    // Match all except specified processes
    }

    public init(processNames: Set<String>, matchMode: MatchMode = .include) {
        self.processNames = processNames
        self.matchMode = matchMode
    }

    public func matches(_ request: NetworkRequest) -> Bool {
        guard let processName = request.processName else {
            return matchMode == .exclude
        }

        let isInList = processNames.contains(processName)

        switch matchMode {
        case .include:
            return isInList
        case .exclude:
            return !isInList
        }
    }
}

// MARK: - Rule Validation

extension ProxyRule {
    /// Validate the rule pattern for the current match type
    public func validate() -> ValidationResult {
        guard !pattern.isEmpty else {
            return .invalid("Pattern cannot be empty")
        }

        switch matchType {
        case .domain, .domainSuffix, .domainKeyword:
            return validateDomainPattern()

        case .urlPattern:
            return .valid

        case .ipAddress:
            return validateIPAddress()

        case .ipCIDR:
            return validateIPCIDR()

        case .regex:
            return validateRegex()
        }
    }

    private func validateDomainPattern() -> ValidationResult {
        // Basic domain validation
        let domainPattern = "^[a-zA-Z0-9][a-zA-Z0-9-_.]*[a-zA-Z0-9]$"
        let cleanPattern = pattern.hasPrefix(".") ? String(pattern.dropFirst()) : pattern

        guard cleanPattern.range(of: domainPattern, options: .regularExpression) != nil else {
            return .invalid("Invalid domain pattern")
        }

        return .valid
    }

    private func validateIPAddress() -> ValidationResult {
        guard parseIPv4(pattern) != nil else {
            return .invalid("Invalid IPv4 address format")
        }
        return .valid
    }

    private func validateIPCIDR() -> ValidationResult {
        guard parseCIDR(pattern) != nil else {
            return .invalid("Invalid CIDR notation (e.g., 192.168.1.0/24)")
        }
        return .valid
    }

    private func validateRegex() -> ValidationResult {
        do {
            _ = try NSRegularExpression(pattern: pattern)
            return .valid
        } catch {
            return .invalid("Invalid regular expression: \(error.localizedDescription)")
        }
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
}

// MARK: - CustomStringConvertible

extension ProxyRule: CustomStringConvertible {
    public var description: String {
        "\(matchType.rawValue),\(pattern),\(action.rawValue)"
    }
}

// MARK: - Comparable

extension ProxyRule: Comparable {
    /// Rules are ordered by priority (higher first), then by creation date
    public static func < (lhs: ProxyRule, rhs: ProxyRule) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority // Higher priority comes first
        }
        return lhs.createdAt < rhs.createdAt
    }
}
