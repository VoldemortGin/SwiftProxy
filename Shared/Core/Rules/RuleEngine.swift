import Foundation
import OSLog

// MARK: - Rule Engine

/// Engine for evaluating and executing proxy rules
@available(macOS 12.0, *)
public actor RuleEngine {
    // MARK: - Properties

    private var ruleGroups: [RuleGroup] = []
    private var defaultAction: RuleAction = .proxy
    private let logger: OSLog

    // Statistics
    private var totalMatches: Int = 0
    private var actionCounts: [RuleAction: Int] = [:]
    private var ruleMatchCounts: [UUID: Int] = [:]

    // Cache for performance
    private var matchCache: [String: RuleMatchResult] = [:]
    private let maxCacheSize: Int = 1000

    // MARK: - Initialization

    public init(
        ruleGroups: [RuleGroup] = [],
        defaultAction: RuleAction = .proxy,
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "RuleEngine")
    ) {
        self.ruleGroups = ruleGroups
        self.defaultAction = defaultAction
        self.logger = logger

        // Initialize action counts
        for action in RuleAction.allCases {
            actionCounts[action] = 0
        }
    }

    // MARK: - Rule Management

    /// Add a rule group
    public func addRuleGroup(_ group: RuleGroup) {
        ruleGroups.append(group)
        os_log(.info, log: logger, "Added rule group: %{public}@", group.name)
    }

    /// Remove a rule group
    public func removeRuleGroup(_ id: UUID) {
        ruleGroups.removeAll { $0.id == id }
        clearCache()
        os_log(.info, log: logger, "Removed rule group: %{public}@", id.uuidString)
    }

    /// Update a rule group
    public func updateRuleGroup(_ group: RuleGroup) {
        if let index = ruleGroups.firstIndex(where: { $0.id == group.id }) {
            ruleGroups[index] = group
            clearCache()
            os_log(.info, log: logger, "Updated rule group: %{public}@", group.name)
        }
    }

    /// Get all rule groups
    public func getRuleGroups() -> [RuleGroup] {
        return ruleGroups
    }

    /// Set default action
    public func setDefaultAction(_ action: RuleAction) {
        defaultAction = action
        clearCache()
        os_log(.info, log: logger, "Set default action: %{public}@", action.rawValue)
    }

    // MARK: - Rule Evaluation

    /// Evaluate rules for a given request
    public func evaluate(host: String, ip: String? = nil, port: Int? = nil) -> RuleMatchResult {
        // Check cache first
        let cacheKey = makeCacheKey(host: host, ip: ip, port: port)
        if let cached = matchCache[cacheKey] {
            return cached
        }

        // Collect all active rules from all enabled groups
        var allRules: [ProxyRule] = []
        for group in ruleGroups where group.enabled {
            allRules.append(contentsOf: group.activeRules)
        }

        // Sort by priority (highest first)
        allRules.sort { $0.priority > $1.priority }

        // Find first matching rule
        for rule in allRules {
            if rule.matches(host: host, ip: ip, port: port) {
                let result = RuleMatchResult(
                    rule: rule,
                    action: rule.action,
                    proxyServer: rule.proxyServer,
                    modifyHeaders: rule.modifyHeaders
                )

                // Update statistics
                updateStatistics(rule: rule, action: rule.action)

                // Cache result
                cacheResult(key: cacheKey, result: result)

                os_log(.debug, log: logger, "Matched rule: %{public}@ -> %{public}@",
                       rule.name, rule.action.rawValue)

                return result
            }
        }

        // No match found - use default action
        let result = RuleMatchResult(rule: nil, action: defaultAction)

        // Update statistics
        updateStatistics(rule: nil, action: defaultAction)

        // Cache result
        cacheResult(key: cacheKey, result: result)

        os_log(.debug, log: logger, "No rule matched, using default: %{public}@",
               defaultAction.rawValue)

        return result
    }

    /// Quick evaluation with just host
    public func evaluate(host: String) -> RuleMatchResult {
        return evaluate(host: host, ip: nil, port: nil)
    }

    // MARK: - Batch Operations

    /// Import rules from rule strings (Surge/Clash format)
    public func importRules(from strings: [String], groupName: String = "Imported Rules") -> Int {
        var rules: [ProxyRule] = []

        for string in strings {
            if let rule = ProxyRule.parse(from: string) {
                rules.append(rule)
            }
        }

        if !rules.isEmpty {
            let group = RuleGroup(name: groupName, rules: rules)
            addRuleGroup(group)
        }

        os_log(.info, log: logger, "Imported %d rules", rules.count)
        return rules.count
    }

    /// Export all rules as strings
    public func exportRules() -> [String] {
        var strings: [String] = []

        for group in ruleGroups where group.enabled {
            strings.append("# \(group.name)")
            if let description = group.description {
                strings.append("# \(description)")
            }

            for rule in group.rules where rule.enabled {
                strings.append(rule.ruleString)
            }

            strings.append("") // Empty line between groups
        }

        return strings
    }

    // MARK: - Cache Management

    private func makeCacheKey(host: String, ip: String?, port: Int?) -> String {
        var key = host
        if let ip = ip {
            key += "|\(ip)"
        }
        if let port = port {
            key += ":\(port)"
        }
        return key
    }

    private func cacheResult(key: String, result: RuleMatchResult) {
        // Limit cache size
        if matchCache.count >= maxCacheSize {
            // Remove random entries (simple strategy)
            let keysToRemove = Array(matchCache.keys.prefix(maxCacheSize / 4))
            for key in keysToRemove {
                matchCache.removeValue(forKey: key)
            }
        }

        matchCache[key] = result
    }

    /// Clear the match cache
    public func clearCache() {
        matchCache.removeAll()
        os_log(.debug, log: logger, "Cleared rule cache")
    }

    // MARK: - Statistics

    private func updateStatistics(rule: ProxyRule?, action: RuleAction) {
        totalMatches += 1
        actionCounts[action, default: 0] += 1

        if let ruleID = rule?.id {
            ruleMatchCounts[ruleID, default: 0] += 1
        }
    }

    /// Get rule engine statistics
    public func getStatistics() -> RuleEngineStatistics {
        return RuleEngineStatistics(
            totalMatches: totalMatches,
            actionCounts: actionCounts,
            ruleMatchCounts: ruleMatchCounts,
            cacheSize: matchCache.count,
            totalRules: ruleGroups.reduce(0) { $0 + $1.rules.count },
            enabledRules: ruleGroups.reduce(0) { $0 + $1.activeRules.count }
        )
    }

    /// Reset statistics
    public func resetStatistics() {
        totalMatches = 0
        actionCounts = [:]
        ruleMatchCounts = [:]

        for action in RuleAction.allCases {
            actionCounts[action] = 0
        }

        os_log(.info, log: logger, "Reset rule engine statistics")
    }

    // MARK: - Rule Testing

    /// Test a rule against sample inputs
    public func testRule(_ rule: ProxyRule, samples: [(host: String, ip: String?, port: Int?)]) -> [Bool] {
        return samples.map { rule.matches(host: $0.host, ip: $0.ip, port: $0.port) }
    }

    /// Find all rules that would match a given request
    public func findMatchingRules(host: String, ip: String? = nil, port: Int? = nil) -> [ProxyRule] {
        var matches: [ProxyRule] = []

        for group in ruleGroups where group.enabled {
            for rule in group.activeRules {
                if rule.matches(host: host, ip: ip, port: port) {
                    matches.append(rule)
                }
            }
        }

        return matches.sorted { $0.priority > $1.priority }
    }

    // MARK: - Persistence

    /// Load rule groups from file
    public func loadRuleGroups(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let groups = try decoder.decode([RuleGroup].self, from: data)

        ruleGroups = groups
        clearCache()

        os_log(.info, log: logger, "Loaded %d rule groups from file", groups.count)
    }

    /// Save rule groups to file
    public func saveRuleGroups(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(ruleGroups)

        try data.write(to: url)

        os_log(.info, log: logger, "Saved %d rule groups to file", ruleGroups.count)
    }
}

// MARK: - Rule Engine Statistics

public struct RuleEngineStatistics: Codable {
    public let totalMatches: Int
    public let actionCounts: [RuleAction: Int]
    public let ruleMatchCounts: [UUID: Int]
    public let cacheSize: Int
    public let totalRules: Int
    public let enabledRules: Int

    /// Get most matched rules
    public func topRules(limit: Int = 10) -> [(UUID, Int)] {
        ruleMatchCounts.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }

    /// Get action distribution
    public func actionDistribution() -> [(RuleAction, Double)] {
        guard totalMatches > 0 else { return [] }

        return actionCounts.map { action, count in
            (action, Double(count) / Double(totalMatches) * 100.0)
        }.sorted { $0.1 > $1.1 }
    }
}

// MARK: - Rule Builder

/// Fluent interface for building rules
public struct RuleBuilder {
    private var rule: ProxyRule

    public init(name: String) {
        self.rule = ProxyRule(
            name: name,
            matchType: .final,
            pattern: "",
            action: .proxy
        )
    }

    public func matchDomain(_ domain: String) -> RuleBuilder {
        var builder = self
        builder.rule.matchType = .domain
        builder.rule.pattern = domain
        return builder
    }

    public func matchDomainSuffix(_ suffix: String) -> RuleBuilder {
        var builder = self
        builder.rule.matchType = .domainSuffix
        builder.rule.pattern = suffix
        return builder
    }

    public func matchDomainKeyword(_ keyword: String) -> RuleBuilder {
        var builder = self
        builder.rule.matchType = .domainKeyword
        builder.rule.pattern = keyword
        return builder
    }

    public func matchIP(_ ip: String) -> RuleBuilder {
        var builder = self
        builder.rule.matchType = .ipAddress
        builder.rule.pattern = ip
        return builder
    }

    public func matchCIDR(_ cidr: String) -> RuleBuilder {
        var builder = self
        builder.rule.matchType = .ipCIDR
        builder.rule.pattern = cidr
        return builder
    }

    public func matchPort(_ port: Int) -> RuleBuilder {
        var builder = self
        builder.rule.matchType = .port
        builder.rule.pattern = "\(port)"
        return builder
    }

    public func action(_ action: RuleAction) -> RuleBuilder {
        var builder = self
        builder.rule.action = action
        return builder
    }

    public func priority(_ priority: Int) -> RuleBuilder {
        var builder = self
        builder.rule.priority = priority
        return builder
    }

    public func proxyServer(_ server: String) -> RuleBuilder {
        var builder = self
        builder.rule.proxyServer = server
        builder.rule.action = .proxyServer
        return builder
    }

    public func notes(_ notes: String) -> RuleBuilder {
        var builder = self
        builder.rule.notes = notes
        return builder
    }

    public func build() -> ProxyRule {
        return rule
    }
}

// MARK: - Example Usage

extension RuleEngine {
    /// Create example rule engine for testing
    public static func createExample() -> RuleEngine {
        let engine = RuleEngine()

        Task {
            // Add smart routing rules
            await engine.addRuleGroup(RuleGroup.presets[1])

            // Set default to proxy
            await engine.setDefaultAction(.proxy)
        }

        return engine
    }
}
