import XCTest
@testable import SwiftProxy

/// Comprehensive unit tests for ProxyRule model
final class ProxyRuleTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        // Given & When
        let rule = ProxyRule(
            name: "Test Rule",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy
        )

        // Then
        XCTAssertNotNil(rule.id)
        XCTAssertEqual(rule.name, "Test Rule")
        XCTAssertEqual(rule.pattern, "example.com")
        XCTAssertEqual(rule.matchType, .domain)
        XCTAssertEqual(rule.action, .proxy)
        XCTAssertEqual(rule.priority, 0)
        XCTAssertTrue(rule.isEnabled)
        XCTAssertFalse(rule.caseSensitive)
        XCTAssertNil(rule.processFilter)
    }

    func testInitializationWithOptions() {
        // Given & When
        let processFilter = ProcessFilter(
            processNames: ["Safari", "Chrome"],
            matchMode: .include
        )

        let rule = ProxyRule(
            name: "Advanced Rule",
            pattern: ".*\\.example\\.com",
            matchType: .regex,
            action: .direct,
            priority: 100,
            isEnabled: false,
            description: "Test description",
            caseSensitive: true,
            processFilter: processFilter
        )

        // Then
        XCTAssertEqual(rule.priority, 100)
        XCTAssertFalse(rule.isEnabled)
        XCTAssertTrue(rule.caseSensitive)
        XCTAssertNotNil(rule.processFilter)
        XCTAssertEqual(rule.processFilter?.processNames.count, 2)
    }

    // MARK: - Match Type Tests

    func testDomainMatching() {
        // Given
        let rule = ProxyRule(
            name: "Domain Rule",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy
        )

        let request1 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com/path")!
        )

        let request2 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://sub.example.com")!
        )

        // When & Then
        XCTAssertTrue(rule.matches(request1))
        XCTAssertFalse(rule.matches(request2)) // Subdomain shouldn't match
    }

    func testDomainSuffixMatching() {
        // Given
        let rule = ProxyRule(
            name: "Suffix Rule",
            pattern: ".example.com",
            matchType: .domainSuffix,
            action: .proxy
        )

        let request1 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com")!
        )

        let request2 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://sub.example.com")!
        )

        let request3 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://notexample.com")!
        )

        // When & Then
        XCTAssertTrue(rule.matches(request1))
        XCTAssertTrue(rule.matches(request2))
        XCTAssertFalse(rule.matches(request3))
    }

    func testDomainKeywordMatching() {
        // Given
        let rule = ProxyRule(
            name: "Keyword Rule",
            pattern: "example",
            matchType: .domainKeyword,
            action: .proxy
        )

        let request1 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com")!
        )

        let request2 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://myexample.org")!
        )

        let request3 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://test.com")!
        )

        // When & Then
        XCTAssertTrue(rule.matches(request1))
        XCTAssertTrue(rule.matches(request2))
        XCTAssertFalse(rule.matches(request3))
    }

    func testURLPatternMatching() {
        // Given
        let rule = ProxyRule(
            name: "URL Pattern",
            pattern: "*.example.com/api/*",
            matchType: .urlPattern,
            action: .proxy
        )

        let request1 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://api.example.com/api/v1/users")!
        )

        let request2 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com/other")!
        )

        // When & Then
        XCTAssertTrue(rule.matches(request1))
        XCTAssertFalse(rule.matches(request2))
    }

    func testIPAddressMatching() {
        // Given
        let rule = ProxyRule(
            name: "IP Rule",
            pattern: "192.168.1.1",
            matchType: .ipAddress,
            action: .direct
        )

        let request1 = NetworkRequest(
            method: .GET,
            url: URL(string: "http://192.168.1.1")!
        )

        let request2 = NetworkRequest(
            method: .GET,
            url: URL(string: "http://192.168.1.2")!
        )

        // When & Then
        XCTAssertTrue(rule.matches(request1))
        XCTAssertFalse(rule.matches(request2))
    }

    func testIPCIDRMatching() {
        // Given
        let rule = ProxyRule(
            name: "CIDR Rule",
            pattern: "192.168.1.0/24",
            matchType: .ipCIDR,
            action: .direct
        )

        let request1 = NetworkRequest(
            method: .GET,
            url: URL(string: "http://192.168.1.1")!
        )

        let request2 = NetworkRequest(
            method: .GET,
            url: URL(string: "http://192.168.1.255")!
        )

        let request3 = NetworkRequest(
            method: .GET,
            url: URL(string: "http://192.168.2.1")!
        )

        // When & Then
        XCTAssertTrue(rule.matches(request1))
        XCTAssertTrue(rule.matches(request2))
        XCTAssertFalse(rule.matches(request3))
    }

    func testRegexMatching() {
        // Given
        let rule = ProxyRule(
            name: "Regex Rule",
            pattern: "^https://.*\\.example\\.com/api/.*$",
            matchType: .regex,
            action: .proxy
        )

        let request1 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://api.example.com/api/users")!
        )

        let request2 = NetworkRequest(
            method: .GET,
            url: URL(string: "http://api.example.com/api/users")!
        )

        // When & Then
        XCTAssertTrue(rule.matches(request1))
        XCTAssertFalse(rule.matches(request2)) // Wrong scheme
    }

    func testCaseSensitiveMatching() {
        // Given
        let caseSensitiveRule = ProxyRule(
            name: "Case Sensitive",
            pattern: "Example.com",
            matchType: .domain,
            action: .proxy,
            caseSensitive: true
        )

        let caseInsensitiveRule = ProxyRule(
            name: "Case Insensitive",
            pattern: "Example.com",
            matchType: .domain,
            action: .proxy,
            caseSensitive: false
        )

        let request = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com")!
        )

        // When & Then
        XCTAssertFalse(caseSensitiveRule.matches(request))
        XCTAssertTrue(caseInsensitiveRule.matches(request))
    }

    // MARK: - Process Filter Tests

    func testProcessFilterInclude() {
        // Given
        let filter = ProcessFilter(
            processNames: ["Safari", "Chrome"],
            matchMode: .include
        )

        let rule = ProxyRule(
            name: "Process Rule",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy,
            processFilter: filter
        )

        let safariRequest = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com")!,
            processName: "Safari"
        )

        let firefoxRequest = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com")!,
            processName: "Firefox"
        )

        // When & Then
        XCTAssertTrue(rule.matches(safariRequest))
        XCTAssertFalse(rule.matches(firefoxRequest))
    }

    func testProcessFilterExclude() {
        // Given
        let filter = ProcessFilter(
            processNames: ["Safari"],
            matchMode: .exclude
        )

        let rule = ProxyRule(
            name: "Exclude Rule",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy,
            processFilter: filter
        )

        let safariRequest = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com")!,
            processName: "Safari"
        )

        let chromeRequest = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com")!,
            processName: "Chrome"
        )

        // When & Then
        XCTAssertFalse(rule.matches(safariRequest))
        XCTAssertTrue(rule.matches(chromeRequest))
    }

    // MARK: - Disabled Rule Tests

    func testDisabledRuleDontMatch() {
        // Given
        let rule = ProxyRule(
            name: "Disabled",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy,
            isEnabled: false
        )

        let request = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com")!
        )

        // When & Then
        XCTAssertFalse(rule.matches(request))
    }

    // MARK: - Validation Tests

    func testValidDomainPattern() {
        // Given
        let rule = ProxyRule(
            name: "Valid",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy
        )

        // When
        let result = rule.validate()

        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testInvalidEmptyPattern() {
        // Given
        let rule = ProxyRule(
            name: "Invalid",
            pattern: "",
            matchType: .domain,
            action: .proxy
        )

        // When
        let result = rule.validate()

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Pattern cannot be empty")
    }

    func testInvalidIPAddress() {
        // Given
        let rule = ProxyRule(
            name: "Invalid IP",
            pattern: "999.999.999.999",
            matchType: .ipAddress,
            action: .direct
        )

        // When
        let result = rule.validate()

        // Then
        XCTAssertFalse(result.isValid)
    }

    func testInvalidCIDR() {
        // Given
        let rule = ProxyRule(
            name: "Invalid CIDR",
            pattern: "192.168.1.0/99",
            matchType: .ipCIDR,
            action: .direct
        )

        // When
        let result = rule.validate()

        // Then
        XCTAssertFalse(result.isValid)
    }

    func testInvalidRegex() {
        // Given
        let rule = ProxyRule(
            name: "Invalid Regex",
            pattern: "[invalid(regex",
            matchType: .regex,
            action: .proxy
        )

        // When
        let result = rule.validate()

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }

    // MARK: - RuleAction Tests

    func testRuleActionDisplayNames() {
        XCTAssertEqual(RuleAction.direct.displayName, "Direct")
        XCTAssertEqual(RuleAction.proxy.displayName, "Proxy")
        XCTAssertEqual(RuleAction.reject.displayName, "Reject")
    }

    // MARK: - MatchType Tests

    func testMatchTypeDisplayNames() {
        XCTAssertEqual(MatchType.domain.displayName, "Domain")
        XCTAssertEqual(MatchType.domainSuffix.displayName, "Domain Suffix")
        XCTAssertEqual(MatchType.domainKeyword.displayName, "Domain Keyword")
        XCTAssertEqual(MatchType.urlPattern.displayName, "URL Pattern")
        XCTAssertEqual(MatchType.ipAddress.displayName, "IP Address")
        XCTAssertEqual(MatchType.ipCIDR.displayName, "IP CIDR")
        XCTAssertEqual(MatchType.regex.displayName, "Regular Expression")
    }

    func testMatchTypeExamples() {
        XCTAssertEqual(MatchType.domain.examplePattern, "example.com")
        XCTAssertEqual(MatchType.domainSuffix.examplePattern, ".example.com")
        XCTAssertEqual(MatchType.ipAddress.examplePattern, "192.168.1.1")
        XCTAssertEqual(MatchType.ipCIDR.examplePattern, "192.168.1.0/24")
    }

    // MARK: - Comparable Tests

    func testRuleSortingByPriority() {
        // Given
        let rule1 = ProxyRule(
            name: "Low Priority",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy,
            priority: 1
        )

        let rule2 = ProxyRule(
            name: "High Priority",
            pattern: "test.com",
            matchType: .domain,
            action: .proxy,
            priority: 10
        )

        // When
        let sorted = [rule1, rule2].sorted()

        // Then
        XCTAssertEqual(sorted[0].name, "High Priority") // Higher priority first
        XCTAssertEqual(sorted[1].name, "Low Priority")
    }

    func testRuleSortingByCreationDate() {
        // Given
        let rule1 = ProxyRule(
            name: "First",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy,
            priority: 5
        )

        Thread.sleep(forTimeInterval: 0.01)

        let rule2 = ProxyRule(
            name: "Second",
            pattern: "test.com",
            matchType: .domain,
            action: .proxy,
            priority: 5
        )

        // When
        let sorted = [rule2, rule1].sorted()

        // Then - same priority, so sorted by creation date
        XCTAssertEqual(sorted[0].name, "First")
        XCTAssertEqual(sorted[1].name, "Second")
    }

    // MARK: - Codable Tests

    func testEncodingDecoding() throws {
        // Given
        let original = ProxyRule(
            name: "Test Rule",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy,
            priority: 10,
            isEnabled: true,
            description: "Test description",
            caseSensitive: false
        )

        // When - encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        // Then - decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProxyRule.self, from: data)

        // Verify
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.pattern, original.pattern)
        XCTAssertEqual(decoded.matchType, original.matchType)
        XCTAssertEqual(decoded.action, original.action)
        XCTAssertEqual(decoded.priority, original.priority)
        XCTAssertEqual(decoded.isEnabled, original.isEnabled)
        XCTAssertEqual(decoded.caseSensitive, original.caseSensitive)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        // Given
        let id = UUID()
        let rule1 = ProxyRule(
            id: id,
            name: "Test",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy
        )

        let rule2 = ProxyRule(
            id: id,
            name: "Test",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy
        )

        let rule3 = ProxyRule(
            name: "Different",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy
        )

        // Then
        XCTAssertEqual(rule1, rule2)
        XCTAssertNotEqual(rule1, rule3)
    }

    // MARK: - Hashable Tests

    func testHashability() {
        // Given
        let rule1 = ProxyRule(
            name: "Rule1",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy
        )

        let rule2 = ProxyRule(
            name: "Rule2",
            pattern: "test.com",
            matchType: .domain,
            action: .proxy
        )

        // When
        var set = Set<ProxyRule>()
        set.insert(rule1)
        set.insert(rule2)
        set.insert(rule1) // Duplicate

        // Then
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - CustomStringConvertible Tests

    func testDescription() {
        // Given
        let rule = ProxyRule(
            name: "Test Rule",
            pattern: "example.com",
            matchType: .domain,
            action: .proxy
        )

        // When
        let description = rule.description

        // Then
        XCTAssertEqual(description, "DOMAIN,example.com,PROXY")
    }

    // MARK: - Edge Cases

    func testIPv4EdgeCases() {
        // Test minimum IP
        let minRule = ProxyRule(
            name: "Min IP",
            pattern: "0.0.0.0",
            matchType: .ipAddress,
            action: .direct
        )
        XCTAssertTrue(minRule.validate().isValid)

        // Test maximum IP
        let maxRule = ProxyRule(
            name: "Max IP",
            pattern: "255.255.255.255",
            matchType: .ipAddress,
            action: .direct
        )
        XCTAssertTrue(maxRule.validate().isValid)
    }

    func testCIDREdgeCases() {
        // Test /0 (all IPs)
        let allRule = ProxyRule(
            name: "All IPs",
            pattern: "0.0.0.0/0",
            matchType: .ipCIDR,
            action: .direct
        )
        XCTAssertTrue(allRule.validate().isValid)

        // Test /32 (single IP)
        let singleRule = ProxyRule(
            name: "Single IP",
            pattern: "192.168.1.1/32",
            matchType: .ipCIDR,
            action: .direct
        )
        XCTAssertTrue(singleRule.validate().isValid)
    }

    func testComplexRegexPatterns() {
        // Given
        let rule = ProxyRule(
            name: "Complex Regex",
            pattern: "^https?://([a-z0-9]+\\.)*example\\.(com|org|net)/.*$",
            matchType: .regex,
            action: .proxy
        )

        let request1 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://api.example.com/v1/users")!
        )

        let request2 = NetworkRequest(
            method: .GET,
            url: URL(string: "http://example.org/path")!
        )

        let request3 = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.info")!
        )

        // When & Then
        XCTAssertTrue(rule.matches(request1))
        XCTAssertTrue(rule.matches(request2))
        XCTAssertFalse(rule.matches(request3))
    }

    // MARK: - Performance Tests

    func testRegexMatchingPerformance() {
        // Given
        let rule = ProxyRule(
            name: "Regex",
            pattern: "^https://.*\\.example\\.com/.*$",
            matchType: .regex,
            action: .proxy
        )

        let request = NetworkRequest(
            method: .GET,
            url: URL(string: "https://api.example.com/v1/users")!
        )

        // Measure
        measure {
            for _ in 0..<1000 {
                _ = rule.matches(request)
            }
        }
    }
}
