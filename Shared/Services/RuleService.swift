import Foundation
import Combine
import OSLog

/// Service for managing proxy routing rules
/// Provides rule evaluation, persistence, and conflict detection
/// Thread-safe implementation for concurrent rule matching
public protocol RuleServiceProtocol: AnyObject {
    // Publishers
    var rules: AnyPublisher<[ProxyRule], Never> { get }
    var enabledRules: AnyPublisher<[ProxyRule], Never> { get }

    // CRUD operations
    func loadRules() async throws -> [ProxyRule]
    func saveRule(_ rule: ProxyRule) async throws
    func updateRule(_ rule: ProxyRule) async throws
    func deleteRule(id: UUID) async throws
    func getRule(id: UUID) async -> ProxyRule?

    // Rule evaluation
    func evaluateRequest(_ request: NetworkRequest) async -> RuleMatch?
    func evaluateURL(_ url: URL) async -> RuleMatch?

    // Rule management
    func reorderRules(_ rules: [ProxyRule]) async throws
    func toggleRule(id: UUID) async throws
    func duplicateRule(id: UUID) async throws -> ProxyRule

    // Import/Export
    func exportRules() async throws -> Data
    func importRules(from data: Data, merge: Bool) async throws
    func exportRule(id: UUID) async throws -> Data

    // Validation
    func validateRule(_ rule: ProxyRule) async -> ProxyRule.ValidationResult
    func detectConflicts(for rule: ProxyRule) async -> [RuleConflict]
}

public final class RuleService: RuleServiceProtocol {
    // MARK: - Publishers

    private let rulesSubject = CurrentValueSubject<[ProxyRule], Never>([])
    private let enabledRulesSubject = CurrentValueSubject<[ProxyRule], Never>([])

    public var rules: AnyPublisher<[ProxyRule], Never> {
        rulesSubject.eraseToAnyPublisher()
    }

    public var enabledRules: AnyPublisher<[ProxyRule], Never> {
        enabledRulesSubject.eraseToAnyPublisher()
    }

    // MARK: - Properties

    private let logger: OSLog
    private let fileManager: FileManager
    private let storageURL: URL
    private let stateQueue = DispatchQueue(label: "com.swiftproxy.ruleservice", qos: .userInitiated)

    // In-memory cache for fast rule matching
    private var cachedRules: [UUID: ProxyRule] = [:]
    private var sortedEnabledRules: [ProxyRule] = []

    // MARK: - Initialization

    public init(
        fileManager: FileManager = .default,
        logger: OSLog = Logger.rulesLog
    ) throws {
        self.fileManager = fileManager
        self.logger = logger

        // Setup storage directory
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        self.storageURL = appSupport.appendingPathComponent("SwiftProxy", isDirectory: true)

        try createStorageDirectoryIfNeeded()

        // Load initial data
        Task {
            await loadInitialData()
        }
    }

    // MARK: - CRUD Operations

    public func loadRules() async throws -> [ProxyRule] {
        try await stateQueue.sync {
            try self.loadRulesSync()
        }
    }

    public func saveRule(_ rule: ProxyRule) async throws {
        os_log(.info, log: logger, "Saving rule: %@", rule.name)

        // Validate rule
        let validation = await validateRule(rule)
        guard validation.isValid else {
            throw AppError.ruleValidationFailed(validation.errorMessage ?? "Validation failed")
        }

        // Check for conflicts
        let conflicts = await detectConflicts(for: rule)
        if !conflicts.isEmpty {
            os_log(.default, log: logger, "Rule has %d conflicts", conflicts.count)
        }

        try await stateQueue.sync {
            // Add or update in cache
            self.cachedRules[rule.id] = rule

            // Persist to disk
            try self.persistRules()

            // Update publishers
            self.updatePublishers()

            os_log(.debug, log: self.logger, "Rule saved: %@", rule.id.uuidString)
        }
    }

    public func updateRule(_ rule: ProxyRule) async throws {
        os_log(.info, log: logger, "Updating rule: %@", rule.name)

        // Ensure rule exists
        guard cachedRules[rule.id] != nil else {
            throw AppError.ruleNotFound(rule.id)
        }

        // Save uses same logic as update
        try await saveRule(rule)
    }

    public func deleteRule(id: UUID) async throws {
        os_log(.info, log: logger, "Deleting rule: %@", id.uuidString)

        try await stateQueue.sync {
            // Remove from cache
            guard self.cachedRules.removeValue(forKey: id) != nil else {
                throw AppError.ruleNotFound(id)
            }

            // Persist changes
            try self.persistRules()

            // Update publishers
            self.updatePublishers()

            os_log(.debug, log: self.logger, "Rule deleted: %@", id.uuidString)
        }
    }

    public func getRule(id: UUID) async -> ProxyRule? {
        cachedRules[id]
    }

    // MARK: - Rule Evaluation

    public func evaluateRequest(_ request: NetworkRequest) async -> RuleMatch? {
        // Use cached sorted enabled rules for fast matching
        let rules = sortedEnabledRules

        // Find first matching rule (rules are sorted by priority)
        for rule in rules {
            let host = request.url.host ?? ""
            let port = request.url.port

            if rule.matches(host: host, ip: nil, port: port) {
                os_log(.debug, log: logger, "Request matched rule: %@ -> %@",
                       request.url.absoluteString, rule.name)

                return RuleMatch(
                    rule: rule,
                    request: request,
                    action: rule.action,
                    matchedAt: Date()
                )
            }
        }

        os_log(.debug, log: logger, "No rule matched for request: %@", request.url.absoluteString)
        return nil
    }

    public func evaluateURL(_ url: URL) async -> RuleMatch? {
        // Create a minimal request for URL evaluation
        let request = NetworkRequest(
            method: .GET,
            url: url,
            headers: [:]
        )

        return await evaluateRequest(request)
    }

    // MARK: - Rule Management

    public func reorderRules(_ rules: [ProxyRule]) async throws {
        os_log(.info, log: logger, "Reordering %d rules", rules.count)

        try await stateQueue.sync {
            // Update priorities based on new order
            var updatedRules = rules
            for (index, _) in updatedRules.enumerated() {
                updatedRules[index].priority = rules.count - index
            }

            // Update cache
            for rule in updatedRules {
                self.cachedRules[rule.id] = rule
            }

            // Persist changes
            try self.persistRules()

            // Update publishers
            self.updatePublishers()
        }
    }

    public func toggleRule(id: UUID) async throws {
        guard var rule = cachedRules[id] else {
            throw AppError.ruleNotFound(id)
        }

        os_log(.info, log: logger, "Toggling rule: %@ (enabled: %@)", rule.name, (!rule.enabled).description)

        rule.enabled.toggle()
        try await saveRule(rule)
    }

    public func duplicateRule(id: UUID) async throws -> ProxyRule {
        guard let original = cachedRules[id] else {
            throw AppError.ruleNotFound(id)
        }

        os_log(.info, log: logger, "Duplicating rule: %@", original.name)

        // Create a copy with new ID and modified name
        let duplicate = ProxyRule(
            id: UUID(),
            name: "\(original.name) Copy",
            matchType: original.matchType,
            pattern: original.pattern,
            action: original.action,
            priority: original.priority - 1,
            enabled: original.enabled,
            proxyServer: original.proxyServer,
            modifyHeaders: original.modifyHeaders,
            notes: original.notes
        )

        try await saveRule(duplicate)
        return duplicate
    }

    // MARK: - Import/Export

    public func exportRules() async throws -> Data {
        let rules = Array(cachedRules.values).sorted()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(rules)

        os_log(.info, log: logger, "Exported %d rules", rules.count)
        return data
    }

    public func importRules(from data: Data, merge: Bool) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let rules = try decoder.decode([ProxyRule].self, from: data)

        if !merge {
            // Clear existing rules
            cachedRules.removeAll()
        }

        // Import rules
        for rule in rules {
            cachedRules[rule.id] = rule
        }

        try persistRules()
        updatePublishers()

        os_log(.info, log: logger, "Imported %d rules (merge: %@)", rules.count, merge ? "yes" : "no")
    }

    public func exportRule(id: UUID) async throws -> Data {
        guard let rule = cachedRules[id] else {
            throw AppError.ruleNotFound(id)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(rule)
    }

    // MARK: - Validation

    public func validateRule(_ rule: ProxyRule) async -> ProxyRule.ValidationResult {
        // Use built-in validation
        return rule.validate()
    }

    public func detectConflicts(for rule: ProxyRule) async -> [RuleConflict] {
        var conflicts: [RuleConflict] = []

        // Check for identical patterns with different actions
        for existingRule in cachedRules.values where existingRule.id != rule.id {
            if existingRule.pattern == rule.pattern &&
               existingRule.matchType == rule.matchType &&
               existingRule.action != rule.action {

                conflicts.append(RuleConflict(
                    type: .identicalPatternDifferentAction,
                    conflictingRule: existingRule,
                    description: "Same pattern with different action: \(existingRule.name)"
                ))
            }

            // Check for duplicate patterns (even with same action)
            if existingRule.pattern == rule.pattern &&
               existingRule.matchType == rule.matchType &&
               existingRule.enabled &&
               rule.enabled {

                conflicts.append(RuleConflict(
                    type: .duplicatePattern,
                    conflictingRule: existingRule,
                    description: "Duplicate pattern: \(existingRule.name)"
                ))
            }
        }

        return conflicts
    }

    // MARK: - Private Methods

    private func createStorageDirectoryIfNeeded() throws {
        if !fileManager.fileExists(atPath: storageURL.path) {
            try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
            os_log(.info, log: logger, "Created storage directory")
        }
    }

    private func loadInitialData() async {
        do {
            let rules = try await loadRules()

            await MainActor.run {
                rulesSubject.send(rules)
                updateEnabledRules(from: rules)
            }

            os_log(.info, log: logger, "Loaded %d rules", rules.count)
        } catch {
            os_log(.error, log: logger, "Failed to load rules: %@", error.localizedDescription)
        }
    }

    private func loadRulesSync() throws -> [ProxyRule] {
        let fileURL = storageURL.appendingPathComponent("rules.json")

        // If file doesn't exist, return default rules
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return defaultRules()
        }

        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let rules = try decoder.decode([ProxyRule].self, from: data)

        // Update cache
        cachedRules = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })

        // Update sorted enabled rules
        sortedEnabledRules = rules.filter { $0.enabled }.sorted()

        return rules.sorted()
    }

    private func persistRules() throws {
        let rules = Array(cachedRules.values)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(rules)

        let fileURL = storageURL.appendingPathComponent("rules.json")
        try data.write(to: fileURL, options: [.atomic])

        os_log(.debug, log: logger, "Persisted %d rules to disk", rules.count)
    }

    private func updatePublishers() {
        let allRules = Array(cachedRules.values).sorted()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.rulesSubject.send(allRules)
            self.updateEnabledRules(from: allRules)
        }
    }

    private func updateEnabledRules(from rules: [ProxyRule]) {
        sortedEnabledRules = rules.filter { $0.enabled }.sorted()
        enabledRulesSubject.send(sortedEnabledRules)
    }

    private func defaultRules() -> [ProxyRule] {
        [
            ProxyRule(
                name: "Local Networks",
                matchType: .ipCIDR,
                pattern: "192.168.0.0/16",
                action: .direct,
                priority: 100,
                notes: "Bypass proxy for local network"
            ),
            ProxyRule(
                name: "Localhost",
                matchType: .ipAddress,
                pattern: "127.0.0.1",
                action: .direct,
                priority: 99,
                notes: "Bypass proxy for localhost"
            ),
            ProxyRule(
                name: "Default Proxy",
                matchType: .domainRegex,
                pattern: ".*",
                action: .proxy,
                priority: 0,
                notes: "Default rule: use proxy for all traffic"
            )
        ]
    }
}

// MARK: - Supporting Types

/// Result of rule matching
public struct RuleMatch {
    public let rule: ProxyRule
    public let request: NetworkRequest
    public let action: RuleAction
    public let matchedAt: Date

    public init(rule: ProxyRule, request: NetworkRequest, action: RuleAction, matchedAt: Date) {
        self.rule = rule
        self.request = request
        self.action = action
        self.matchedAt = matchedAt
    }
}

/// Rule conflict detection
public struct RuleConflict {
    public let type: ConflictType
    public let conflictingRule: ProxyRule
    public let description: String

    public enum ConflictType {
        case duplicatePattern
        case identicalPatternDifferentAction
        case overlappingPattern
    }

    public init(type: ConflictType, conflictingRule: ProxyRule, description: String) {
        self.type = type
        self.conflictingRule = conflictingRule
        self.description = description
    }
}
