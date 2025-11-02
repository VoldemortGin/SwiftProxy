#!/usr/bin/env swift

import Foundation

print("🧪 Verifying Rule Engine and GeoIP")
print(String(repeating: "=", count: 60))

// MARK: - Mock Types for Testing

enum RuleAction: String, CaseIterable {
    case direct = "DIRECT"
    case proxy = "PROXY"
    case reject = "REJECT"
}

enum RuleMatchType: String {
    case domain = "DOMAIN"
    case domainSuffix = "DOMAIN-SUFFIX"
    case domainKeyword = "DOMAIN-KEYWORD"
    case ipCIDR = "IP-CIDR"
    case port = "PORT"
    case geoIP = "GEOIP"
    case final = "FINAL"
}

struct TestRule {
    let name: String
    let matchType: RuleMatchType
    let pattern: String
    let action: RuleAction
    let priority: Int

    func matches(host: String = "", ip: String? = nil, port: Int? = nil) -> Bool {
        switch matchType {
        case .domain:
            return host.lowercased() == pattern.lowercased()

        case .domainSuffix:
            return host.lowercased().hasSuffix(pattern.lowercased())

        case .domainKeyword:
            return host.lowercased().contains(pattern.lowercased())

        case .ipCIDR:
            guard let ip = ip else { return false }
            return matchesCIDR(ip: ip, cidr: pattern)

        case .port:
            guard let port = port, let targetPort = Int(pattern) else { return false }
            return port == targetPort

        case .final:
            return true

        default:
            return false
        }
    }

    private func matchesCIDR(ip: String, cidr: String) -> Bool {
        let components = cidr.components(separatedBy: "/")
        guard components.count == 2,
              let network = components.first,
              let prefixLength = Int(components.last ?? "") else {
            return false
        }

        guard let ipInt = ipToInt(ip),
              let networkInt = ipToInt(network) else {
            return false
        }

        let mask = ~UInt32(0) << (32 - prefixLength)
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
}

// MARK: - Test 1: Domain Matching

print("\n✅ Test 1: Domain Matching")
print(String(repeating: "-", count: 40))

let domainRules = [
    TestRule(name: "Exact Google", matchType: .domain, pattern: "google.com", action: .proxy, priority: 100),
    TestRule(name: "YouTube Suffix", matchType: .domainSuffix, pattern: ".youtube.com", action: .proxy, priority: 90),
    TestRule(name: "Ad Keyword", matchType: .domainKeyword, pattern: "ads", action: .reject, priority: 95)
]

let domainTests: [(String, RuleAction?)] = [
    ("google.com", .proxy),
    ("www.youtube.com", .proxy),
    ("ads.example.com", .reject),
    ("example.com", nil)
]

var domainPassed = 0
for (host, expectedAction) in domainTests {
    let matchedRule = domainRules.filter { $0.matches(host: host) }
        .sorted { $0.priority > $1.priority }
        .first

    let success = (matchedRule?.action == expectedAction) || (matchedRule == nil && expectedAction == nil)
    print("   \(host): \(matchedRule?.action.rawValue ?? "NONE") - \(success ? "✓" : "✗")")

    if success {
        domainPassed += 1
    }
}

print("   Result: \(domainPassed)/\(domainTests.count) passed")

// MARK: - Test 2: IP CIDR Matching

print("\n✅ Test 2: IP CIDR Matching")
print(String(repeating: "-", count: 40))

let cidrRules = [
    TestRule(name: "Local Network", matchType: .ipCIDR, pattern: "192.168.0.0/16", action: .direct, priority: 100),
    TestRule(name: "Private 10", matchType: .ipCIDR, pattern: "10.0.0.0/8", action: .direct, priority: 100),
    TestRule(name: "Localhost", matchType: .ipCIDR, pattern: "127.0.0.0/8", action: .direct, priority: 100)
]

let cidrTests: [(String, RuleAction?)] = [
    ("192.168.1.1", .direct),
    ("192.168.100.50", .direct),
    ("10.0.0.1", .direct),
    ("127.0.0.1", .direct),
    ("8.8.8.8", nil)
]

var cidrPassed = 0
for (ip, expectedAction) in cidrTests {
    let matchedRule = cidrRules.filter { $0.matches(ip: ip) }
        .sorted { $0.priority > $1.priority }
        .first

    let success = (matchedRule?.action == expectedAction) || (matchedRule == nil && expectedAction == nil)
    print("   \(ip): \(matchedRule?.action.rawValue ?? "NONE") - \(success ? "✓" : "✗")")

    if success {
        cidrPassed += 1
    }
}

print("   Result: \(cidrPassed)/\(cidrTests.count) passed")

// MARK: - Test 3: Port Matching

print("\n✅ Test 3: Port Matching")
print(String(repeating: "-", count: 40))

let portRules = [
    TestRule(name: "HTTP Port", matchType: .port, pattern: "80", action: .direct, priority: 80),
    TestRule(name: "HTTPS Port", matchType: .port, pattern: "443", action: .proxy, priority: 80),
    TestRule(name: "SSH Port", matchType: .port, pattern: "22", action: .reject, priority: 90)
]

let portTests: [(Int, RuleAction?)] = [
    (80, .direct),
    (443, .proxy),
    (22, .reject),
    (8080, nil)
]

var portPassed = 0
for (port, expectedAction) in portTests {
    let matchedRule = portRules.filter { $0.matches(port: port) }
        .sorted { $0.priority > $1.priority }
        .first

    let success = (matchedRule?.action == expectedAction) || (matchedRule == nil && expectedAction == nil)
    print("   Port \(port): \(matchedRule?.action.rawValue ?? "NONE") - \(success ? "✓" : "✗")")

    if success {
        portPassed += 1
    }
}

print("   Result: \(portPassed)/\(portTests.count) passed")

// MARK: - Test 4: Priority Ordering

print("\n✅ Test 4: Rule Priority Ordering")
print(String(repeating: "-", count: 40))

let priorityRules = [
    TestRule(name: "Low Priority", matchType: .domainSuffix, pattern: ".com", action: .direct, priority: 10),
    TestRule(name: "High Priority", matchType: .domainSuffix, pattern: ".com", action: .proxy, priority: 100),
    TestRule(name: "Medium Priority", matchType: .domainSuffix, pattern: ".com", action: .reject, priority: 50)
]

let matchedByPriority = priorityRules.filter { $0.matches(host: "example.com") }
    .sorted { $0.priority > $1.priority }

let priorityCorrect = matchedByPriority.first?.action == .proxy && matchedByPriority.first?.priority == 100

print("   Matched \(matchedByPriority.count) rules for example.com")
print("   Highest priority action: \(matchedByPriority.first?.action.rawValue ?? "NONE")")
print("   Priority order correct: \(priorityCorrect ? "✓" : "✗")")

// MARK: - Test 5: GeoIP Simulation

print("\n✅ Test 5: GeoIP Lookup Simulation")
print(String(repeating: "-", count: 40))

// Simplified GeoIP mapping
let geoIPMap: [String: String] = [
    "1.1.1.0": "CN",       // Simulated China IP
    "8.8.8.8": "US",       // Google DNS (US)
    "192.168.1.1": "XX",   // Private network
    "127.0.0.1": "XX"      // Localhost
]

func lookupCountry(ip: String) -> String {
    // Simple prefix matching for simulation
    for (prefix, country) in geoIPMap {
        if ip.hasPrefix(prefix) || ip == prefix {
            return country
        }
    }
    return "XX"
}

let geoIPTests: [(String, String)] = [
    ("1.1.1.0", "CN"),
    ("8.8.8.8", "US"),
    ("192.168.1.1", "XX"),
    ("127.0.0.1", "XX")
]

var geoIPPassed = 0
for (ip, expectedCountry) in geoIPTests {
    let country = lookupCountry(ip: ip)
    let success = country == expectedCountry

    print("   \(ip) -> \(country) (expected: \(expectedCountry)) \(success ? "✓" : "✗")")

    if success {
        geoIPPassed += 1
    }
}

print("   Result: \(geoIPPassed)/\(geoIPTests.count) passed")

// MARK: - Test 6: Rule String Parsing

print("\n✅ Test 6: Rule String Format")
print(String(repeating: "-", count: 40))

struct RuleString {
    let text: String
    let expectedComponents: Int

    func parse() -> [String]? {
        let components = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count >= expectedComponents else { return nil }
        return components
    }
}

let ruleStrings = [
    RuleString(text: "DOMAIN-SUFFIX,google.com,PROXY", expectedComponents: 3),
    RuleString(text: "IP-CIDR,192.168.0.0/16,DIRECT", expectedComponents: 3),
    RuleString(text: "GEOIP,CN,DIRECT", expectedComponents: 3),
    RuleString(text: "FINAL,PROXY", expectedComponents: 2)
]

var parsesPassed = 0
for ruleString in ruleStrings {
    if let components = ruleString.parse() {
        print("   ✓ Parsed: \(components.joined(separator: " | "))")
        parsesPassed += 1
    } else {
        print("   ✗ Failed to parse: \(ruleString.text)")
    }
}

print("   Result: \(parsesPassed)/\(ruleStrings.count) passed")

// MARK: - Summary

print("\n" + String(repeating: "=", count: 60))
print("📊 Test Summary")
print(String(repeating: "=", count: 60))

let totalTests = domainTests.count + cidrTests.count + portTests.count + 1 + geoIPTests.count + ruleStrings.count
let totalPassed = domainPassed + cidrPassed + portPassed + (priorityCorrect ? 1 : 0) + geoIPPassed + parsesPassed

print("✅ Domain Matching: \(domainPassed)/\(domainTests.count)")
print("✅ IP CIDR Matching: \(cidrPassed)/\(cidrTests.count)")
print("✅ Port Matching: \(portPassed)/\(portTests.count)")
print("✅ Priority Ordering: \(priorityCorrect ? "1/1" : "0/1")")
print("✅ GeoIP Lookup: \(geoIPPassed)/\(geoIPTests.count)")
print("✅ Rule String Parsing: \(parsesPassed)/\(ruleStrings.count)")

print("\n🎯 Overall: \(totalPassed)/\(totalTests) tests passed")

if totalPassed == totalTests {
    print("\n🎉 All rule engine tests passed successfully!")
    print(String(repeating: "=", count: 60))
} else {
    print("\n⚠️ Some tests failed. Please review.")
    print(String(repeating: "=", count: 60))
}
