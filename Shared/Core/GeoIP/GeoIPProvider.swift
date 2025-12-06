import Foundation
import OSLog

// MARK: - GeoIP Information

/// Geographic information for an IP address
public struct GeoIPInfo: Codable {
    public let ipAddress: String
    public let countryCode: String      // ISO 3166-1 alpha-2 code (e.g., "US", "CN")
    public let countryName: String
    public let continent: String
    public let region: String?
    public let city: String?
    public let latitude: Double?
    public let longitude: Double?
    public let timezone: String?

    public init(
        ipAddress: String,
        countryCode: String,
        countryName: String,
        continent: String,
        region: String? = nil,
        city: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        timezone: String? = nil
    ) {
        self.ipAddress = ipAddress
        self.countryCode = countryCode
        self.countryName = countryName
        self.continent = continent
        self.region = region
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
    }
}

// MARK: - GeoIP Provider Protocol

/// Protocol for GeoIP providers
public protocol GeoIPProvider {
    /// Lookup geographic information for an IP address
    func lookup(ip: String) async throws -> GeoIPInfo

    /// Check if IP belongs to a specific country
    func isCountry(ip: String, countryCode: String) async -> Bool

    /// Check if IP belongs to a specific continent
    func isContinent(ip: String, continent: String) async -> Bool
}

// MARK: - Local GeoIP Database

/// Local GeoIP database using simplified IP range lookup
@available(macOS 12.0, *)
public actor LocalGeoIPProvider: GeoIPProvider {
    // MARK: - Properties

    private var ipRanges: [IPRange] = []
    private var cache: [String: GeoIPInfo] = [:]
    private let maxCacheSize: Int = 10000
    private let logger: OSLog

    // Statistics
    private var lookupCount: Int = 0
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0

    // MARK: - Initialization

    public init(logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "GeoIP")) {
        self.logger = logger
        // Use nonisolated wrapper to avoid calling actor-isolated method from init
        initializeBuiltInRanges()
    }

    /// Nonisolated wrapper to initialize built-in ranges asynchronously
    nonisolated private func initializeBuiltInRanges() {
        Task { await loadBuiltInRanges() }
    }

    // MARK: - GeoIP Provider

    public func lookup(ip: String) async throws -> GeoIPInfo {
        lookupCount += 1

        // Check cache
        if let cached = cache[ip] {
            cacheHits += 1
            return cached
        }

        cacheMisses += 1

        // Convert IP to integer for comparison
        guard let ipInt = ipToInt(ip) else {
            throw GeoIPError.invalidIP
        }

        // Binary search for matching range
        if let range = findRange(for: ipInt) {
            let info = GeoIPInfo(
                ipAddress: ip,
                countryCode: range.countryCode,
                countryName: range.countryName,
                continent: range.continent
            )

            // Cache result
            cacheResult(ip: ip, info: info)

            return info
        }

        // No match found - return unknown
        let info = GeoIPInfo(
            ipAddress: ip,
            countryCode: "XX",
            countryName: "Unknown",
            continent: "Unknown"
        )

        cacheResult(ip: ip, info: info)

        return info
    }

    public func isCountry(ip: String, countryCode: String) async -> Bool {
        guard let info = try? await lookup(ip: ip) else {
            return false
        }
        return info.countryCode.uppercased() == countryCode.uppercased()
    }

    public func isContinent(ip: String, continent: String) async -> Bool {
        guard let info = try? await lookup(ip: ip) else {
            return false
        }
        return info.continent.uppercased() == continent.uppercased()
    }

    // MARK: - Helper Methods

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

    private func findRange(for ipInt: UInt32) -> IPRange? {
        // Binary search
        var left = 0
        var right = ipRanges.count - 1

        while left <= right {
            let mid = (left + right) / 2
            let range = ipRanges[mid]

            if ipInt >= range.startIP && ipInt <= range.endIP {
                return range
            } else if ipInt < range.startIP {
                right = mid - 1
            } else {
                left = mid + 1
            }
        }

        return nil
    }

    private func cacheResult(ip: String, info: GeoIPInfo) {
        // Limit cache size
        if cache.count >= maxCacheSize {
            // Remove oldest entries (simple FIFO)
            let keysToRemove = Array(cache.keys.prefix(maxCacheSize / 4))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }

        cache[ip] = info
    }

    // MARK: - Database Management

    /// Load built-in IP ranges (simplified dataset)
    private func loadBuiltInRanges() {
        // Load simplified built-in ranges for common countries
        // In production, this would load from a GeoIP database file
        ipRanges = IPRange.builtInRanges
        ipRanges.sort { $0.startIP < $1.startIP }

        os_log(.info, log: logger, "Loaded %d built-in GeoIP ranges", ipRanges.count)
    }

    /// Load IP ranges from file
    public func loadRanges(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let ranges = try decoder.decode([IPRange].self, from: data)

        ipRanges = ranges.sorted { $0.startIP < $1.startIP }
        cache.removeAll()

        os_log(.info, log: logger, "Loaded %d GeoIP ranges from file", ranges.count)
    }

    /// Clear cache
    public func clearCache() {
        cache.removeAll()
        os_log(.debug, log: logger, "Cleared GeoIP cache")
    }

    // MARK: - Statistics

    public func getStatistics() -> GeoIPStatistics {
        let hitRate = lookupCount > 0 ? Double(cacheHits) / Double(lookupCount) * 100.0 : 0.0

        return GeoIPStatistics(
            totalLookups: lookupCount,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            cacheHitRate: hitRate,
            cacheSize: cache.count,
            databaseSize: ipRanges.count
        )
    }

    public func resetStatistics() {
        lookupCount = 0
        cacheHits = 0
        cacheMisses = 0
    }
}

// MARK: - IP Range

/// Represents an IP address range with geographic information
public struct IPRange: Codable {
    public let startIP: UInt32
    public let endIP: UInt32
    public let countryCode: String
    public let countryName: String
    public let continent: String

    public init(startIP: UInt32, endIP: UInt32, countryCode: String, countryName: String, continent: String) {
        self.startIP = startIP
        self.endIP = endIP
        self.countryCode = countryCode
        self.countryName = countryName
        self.continent = continent
    }

    /// Create IP range from string representations
    public init?(startIPString: String, endIPString: String, countryCode: String, countryName: String, continent: String) {
        guard let start = LocalGeoIPProvider.ipStringToInt(startIPString),
              let end = LocalGeoIPProvider.ipStringToInt(endIPString) else {
            return nil
        }

        self.startIP = start
        self.endIP = end
        self.countryCode = countryCode
        self.countryName = countryName
        self.continent = continent
    }

    // Built-in simplified ranges for common countries
    static let builtInRanges: [IPRange] = [
        // China (CN) - Sample ranges
        IPRange(startIP: 0x01010100, endIP: 0x01FFFFFF, countryCode: "CN", countryName: "China", continent: "AS"),
        IPRange(startIP: 0x0E000000, endIP: 0x0EFFFFFF, countryCode: "CN", countryName: "China", continent: "AS"),
        IPRange(startIP: 0x24000000, endIP: 0x24FFFFFF, countryCode: "CN", countryName: "China", continent: "AS"),

        // United States (US) - Sample ranges
        IPRange(startIP: 0x03000000, endIP: 0x03FFFFFF, countryCode: "US", countryName: "United States", continent: "NA"),
        IPRange(startIP: 0x08000000, endIP: 0x08FFFFFF, countryCode: "US", countryName: "United States", continent: "NA"),
        IPRange(startIP: 0x0C000000, endIP: 0x0CFFFFFF, countryCode: "US", countryName: "United States", continent: "NA"),

        // Japan (JP) - Sample ranges
        IPRange(startIP: 0x0B000000, endIP: 0x0BFFFFFF, countryCode: "JP", countryName: "Japan", continent: "AS"),
        IPRange(startIP: 0x31000000, endIP: 0x31FFFFFF, countryCode: "JP", countryName: "Japan", continent: "AS"),

        // United Kingdom (GB) - Sample ranges
        IPRange(startIP: 0x05000000, endIP: 0x05FFFFFF, countryCode: "GB", countryName: "United Kingdom", continent: "EU"),
        IPRange(startIP: 0x50000000, endIP: 0x50FFFFFF, countryCode: "GB", countryName: "United Kingdom", continent: "EU"),

        // Germany (DE) - Sample ranges
        IPRange(startIP: 0x02000000, endIP: 0x02FFFFFF, countryCode: "DE", countryName: "Germany", continent: "EU"),
        IPRange(startIP: 0x52000000, endIP: 0x52FFFFFF, countryCode: "DE", countryName: "Germany", continent: "EU"),

        // Private/Reserved ranges
        IPRange(startIP: 0x0A000000, endIP: 0x0AFFFFFF, countryCode: "XX", countryName: "Private Network", continent: "XX"),
        IPRange(startIP: 0xAC100000, endIP: 0xAC1FFFFF, countryCode: "XX", countryName: "Private Network", continent: "XX"),
        IPRange(startIP: 0xC0A80000, endIP: 0xC0A8FFFF, countryCode: "XX", countryName: "Private Network", continent: "XX"),
        IPRange(startIP: 0x7F000000, endIP: 0x7FFFFFFF, countryCode: "XX", countryName: "Localhost", continent: "XX")
    ]
}

// Helper for IP conversion
extension LocalGeoIPProvider {
    static func ipStringToInt(_ ip: String) -> UInt32? {
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

// MARK: - GeoIP Statistics

public struct GeoIPStatistics: Codable {
    public let totalLookups: Int
    public let cacheHits: Int
    public let cacheMisses: Int
    public let cacheHitRate: Double
    public let cacheSize: Int
    public let databaseSize: Int
}

// MARK: - GeoIP Error

public enum GeoIPError: Error {
    case invalidIP
    case databaseNotLoaded
    case lookupFailed
    case networkError
}

// MARK: - Country Lists

/// Common country groupings for routing rules
public enum CountryList {
    /// Countries that typically require proxy (Great Firewall affected)
    public static let chinaFirewallAffected = [
        "CN"  // China
    ]

    /// Western countries (typically direct)
    public static let western = [
        "US",  // United States
        "CA",  // Canada
        "GB",  // United Kingdom
        "FR",  // France
        "DE",  // Germany
        "IT",  // Italy
        "ES",  // Spain
        "AU",  // Australia
        "NZ"   // New Zealand
    ]

    /// Asian countries
    public static let asian = [
        "CN",  // China
        "JP",  // Japan
        "KR",  // South Korea
        "TW",  // Taiwan
        "HK",  // Hong Kong
        "SG",  // Singapore
        "TH",  // Thailand
        "VN",  // Vietnam
        "IN"   // India
    ]

    /// European countries
    public static let european = [
        "GB",  // United Kingdom
        "FR",  // France
        "DE",  // Germany
        "IT",  // Italy
        "ES",  // Spain
        "NL",  // Netherlands
        "BE",  // Belgium
        "SE",  // Sweden
        "NO",  // Norway
        "DK"   // Denmark
    ]

    /// All continents
    public static let continents = [
        "AF",  // Africa
        "AN",  // Antarctica
        "AS",  // Asia
        "EU",  // Europe
        "NA",  // North America
        "OC",  // Oceania
        "SA"   // South America
    ]
}

// MARK: - GeoIP Rule Extensions

extension ProxyRule {
    /// Create a GeoIP-based rule
    public static func geoIPRule(
        name: String,
        countryCode: String,
        action: RuleAction,
        priority: Int = 50
    ) -> ProxyRule {
        return ProxyRule(
            name: name,
            matchType: .geoIP,
            pattern: countryCode,
            action: action,
            priority: priority
        )
    }

    /// Create rules for country list
    public static func geoIPRules(
        name: String,
        countryCodes: [String],
        action: RuleAction,
        priority: Int = 50
    ) -> [ProxyRule] {
        return countryCodes.map { code in
            geoIPRule(name: "\(name) - \(code)", countryCode: code, action: action, priority: priority)
        }
    }
}
