import Foundation
import OSLog

// MARK: - GeoIP-Enhanced Rule Engine

/// Rule engine with GeoIP lookup capabilities
@available(macOS 12.0, *)
public actor GeoIPRuleEngine {
    // MARK: - Properties

    private let ruleEngine: RuleEngine
    private let geoIPProvider: LocalGeoIPProvider
    private let logger: OSLog

    // Cache for IP -> Country lookups
    private var geoCache: [String: String] = [:]
    private let maxGeoCacheSize: Int = 5000

    // MARK: - Initialization

    public init(
        ruleEngine: RuleEngine? = nil,
        geoIPProvider: LocalGeoIPProvider? = nil,
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "GeoIPRuleEngine")
    ) {
        self.ruleEngine = ruleEngine ?? RuleEngine(logger: logger)
        self.geoIPProvider = geoIPProvider ?? LocalGeoIPProvider(logger: logger)
        self.logger = logger
    }

    // MARK: - Rule Evaluation with GeoIP

    /// Evaluate rules with GeoIP lookup
    public func evaluate(host: String, ip: String? = nil, port: Int? = nil) async -> RuleMatchResult {
        // First try standard rule evaluation
        var result = await ruleEngine.evaluate(host: host, ip: ip, port: port)

        // If no GeoIP rules matched and we have an IP, check GeoIP-based rules
        if let ip = ip, result.rule == nil || !isGeoIPRule(result.rule) {
            if let geoResult = await evaluateGeoIPRules(host: host, ip: ip, port: port) {
                result = geoResult
            }
        }

        return result
    }

    /// Evaluate only GeoIP-based rules
    private func evaluateGeoIPRules(host: String, ip: String, port: Int?) async -> RuleMatchResult? {
        // Get country code for IP
        guard let countryCode = await getCountryCode(for: ip) else {
            return nil
        }

        // Get all rule groups
        let groups = await ruleEngine.getRuleGroups()

        // Collect GeoIP rules
        var geoIPRules: [ProxyRule] = []
        for group in groups where group.enabled {
            let rules = group.activeRules.filter { $0.matchType == .geoIP }
            geoIPRules.append(contentsOf: rules)
        }

        // Sort by priority
        geoIPRules.sort { $0.priority > $1.priority }

        // Find matching rule
        for rule in geoIPRules {
            if matchesGeoIP(rule: rule, countryCode: countryCode) {
                os_log(.debug, log: logger, "Matched GeoIP rule: %{public}@ (Country: %{public}@)",
                       rule.name, countryCode)

                return RuleMatchResult(
                    rule: rule,
                    action: rule.action,
                    proxyServer: rule.proxyServer,
                    modifyHeaders: rule.modifyHeaders
                )
            }
        }

        return nil
    }

    // MARK: - GeoIP Lookup

    /// Get country code for IP address
    private func getCountryCode(for ip: String) async -> String? {
        // Check cache first
        if let cached = geoCache[ip] {
            return cached
        }

        // Lookup using GeoIP provider
        guard let info = try? await geoIPProvider.lookup(ip: ip) else {
            return nil
        }

        let countryCode = info.countryCode

        // Cache result
        cacheCountryCode(ip: ip, countryCode: countryCode)

        return countryCode
    }

    private func cacheCountryCode(ip: String, countryCode: String) {
        // Limit cache size
        if geoCache.count >= maxGeoCacheSize {
            let keysToRemove = Array(geoCache.keys.prefix(maxGeoCacheSize / 4))
            for key in keysToRemove {
                geoCache.removeValue(forKey: key)
            }
        }

        geoCache[ip] = countryCode
    }

    /// Clear GeoIP cache
    public func clearGeoCache() {
        geoCache.removeAll()
        os_log(.debug, log: logger, "Cleared GeoIP cache")
    }

    // MARK: - GeoIP Rule Matching

    private func matchesGeoIP(rule: ProxyRule, countryCode: String) -> Bool {
        // Pattern can be:
        // - Single country code: "CN"
        // - Multiple codes separated by comma: "CN,US,JP"
        // - Continent code: "AS", "EU", etc.

        let patterns = rule.pattern.uppercased().components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return patterns.contains(countryCode.uppercased())
    }

    private func isGeoIPRule(_ rule: ProxyRule?) -> Bool {
        return rule?.matchType == .geoIP
    }

    // MARK: - Rule Management (Delegate to RuleEngine)

    public func addRuleGroup(_ group: RuleGroup) async {
        await ruleEngine.addRuleGroup(group)
    }

    public func removeRuleGroup(_ id: UUID) async {
        await ruleEngine.removeRuleGroup(id)
    }

    public func updateRuleGroup(_ group: RuleGroup) async {
        await ruleEngine.updateRuleGroup(group)
    }

    public func getRuleGroups() async -> [RuleGroup] {
        await ruleEngine.getRuleGroups()
    }

    public func setDefaultAction(_ action: RuleAction) async {
        await ruleEngine.setDefaultAction(action)
    }

    // MARK: - Statistics

    public func getStatistics() async -> GeoIPRuleEngineStatistics {
        let ruleStats = await ruleEngine.getStatistics()
        let geoStats = await geoIPProvider.getStatistics()

        return GeoIPRuleEngineStatistics(
            ruleEngineStats: ruleStats,
            geoIPStats: geoStats,
            geoCacheSize: geoCache.count
        )
    }

    public func resetStatistics() async {
        await ruleEngine.resetStatistics()
        await geoIPProvider.resetStatistics()
    }

    // MARK: - Convenience Methods

    /// Create GeoIP rules for China routing
    public static func createChinaRoutingRules() -> RuleGroup {
        let rules = [
            // Direct for China IPs
            ProxyRule.geoIPRule(
                name: "Direct China",
                countryCode: "CN",
                action: .direct,
                priority: 90
            ),

            // Proxy for US/EU/JP
            ProxyRule.geoIPRule(
                name: "Proxy International",
                countryCode: "US,GB,JP,DE,FR",
                action: .proxy,
                priority: 80
            )
        ]

        return RuleGroup(
            name: "GeoIP China Routing",
            description: "Route based on geographic location",
            rules: rules
        )
    }

    /// Create GeoIP rules for regional split
    public static func createRegionalRules() -> RuleGroup {
        let rules = [
            // Direct for Asian countries
            ProxyRule.geoIPRule(
                name: "Direct Asia",
                countryCode: CountryList.asian.joined(separator: ","),
                action: .direct,
                priority: 85
            ),

            // Proxy for European countries
            ProxyRule.geoIPRule(
                name: "Proxy Europe",
                countryCode: CountryList.european.joined(separator: ","),
                action: .proxy,
                priority: 80
            ),

            // Proxy for North America
            ProxyRule.geoIPRule(
                name: "Proxy North America",
                countryCode: "US,CA,MX",
                action: .proxy,
                priority: 80
            )
        ]

        return RuleGroup(
            name: "Regional Routing",
            description: "Route based on continent/region",
            rules: rules
        )
    }
}

// MARK: - GeoIP Rule Engine Statistics

public struct GeoIPRuleEngineStatistics: Codable {
    public let ruleEngineStats: RuleEngineStatistics
    public let geoIPStats: GeoIPStatistics
    public let geoCacheSize: Int
}

// MARK: - Example Usage

extension GeoIPRuleEngine {
    /// Create example GeoIP rule engine
    public static func createExample() -> GeoIPRuleEngine {
        let engine = GeoIPRuleEngine()

        Task {
            // Add China routing rules
            await engine.addRuleGroup(createChinaRoutingRules())

            // Add regional rules
            await engine.addRuleGroup(createRegionalRules())

            // Add standard domain rules
            await engine.addRuleGroup(RuleGroup.presets[1]) // Smart Routing

            // Set default to proxy
            await engine.setDefaultAction(.proxy)
        }

        return engine
    }
}
