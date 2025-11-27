import XCTest
import Combine
@testable import SwiftProxyCore

/// Comprehensive unit tests for RuleService
final class RuleServiceTests: XCTestCase {

    var sut: RuleService!
    var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = Set<AnyCancellable>()
        sut = try RuleService(fileManager: .default)
    }

    override func tearDownWithError() throws {
        cancellables = nil
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func testInitialization() throws {
        XCTAssertNotNil(sut)
    }

    // MARK: - CRUD Tests

    func testSaveRule() async throws {
        // Given
        let rule = ProxyRule(
            name: "Test Rule",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )

        // When
        try await sut.saveRule(rule)
        let savedRule = await sut.getRule(id: rule.id)

        // Then
        XCTAssertNotNil(savedRule)
        XCTAssertEqual(savedRule?.name, "Test Rule")
    }

    func testUpdateRule() async throws {
        // Given
        var rule = ProxyRule(
            name: "Original Name",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )
        try await sut.saveRule(rule)

        // When
        rule.name = "Updated Name"
        try await sut.updateRule(rule)

        let updatedRule = await sut.getRule(id: rule.id)

        // Then
        XCTAssertEqual(updatedRule?.name, "Updated Name")
    }

    func testDeleteRule() async throws {
        // Given
        let rule = ProxyRule(
            name: "To Delete",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )
        try await sut.saveRule(rule)

        // When
        try await sut.deleteRule(id: rule.id)
        let deletedRule = await sut.getRule(id: rule.id)

        // Then
        XCTAssertNil(deletedRule)
    }

    func testLoadRules() async throws {
        // Given
        let rule1 = ProxyRule(
            name: "Rule 1",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )
        let rule2 = ProxyRule(
            name: "Rule 2",
            matchType: .domain,
            pattern: "test.com",
            action: .direct
        )

        try await sut.saveRule(rule1)
        try await sut.saveRule(rule2)

        // When
        let rules = try await sut.loadRules()

        // Then
        XCTAssertGreaterThanOrEqual(rules.count, 2)
    }

    // MARK: - Rule Evaluation Tests

    func testEvaluateRequest() async throws {
        // Given
        let rule = ProxyRule(
            name: "Test Rule",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )
        try await sut.saveRule(rule)

        let request = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com/path")!
        )

        // When
        let match = await sut.evaluateRequest(request)

        // Then
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.rule.id, rule.id)
        XCTAssertEqual(match?.action, .proxy)
    }

    func testEvaluateRequestNoMatch() async throws {
        // Given
        let rule = ProxyRule(
            name: "Test Rule",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )
        try await sut.saveRule(rule)

        let request = NetworkRequest(
            method: .GET,
            url: URL(string: "https://nomatch.com")!
        )

        // When
        let match = await sut.evaluateRequest(request)

        // Then
        XCTAssertNil(match)
    }

    func testEvaluateURL() async throws {
        // Given
        let rule = ProxyRule(
            name: "Test Rule",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )
        try await sut.saveRule(rule)

        let url = URL(string: "https://example.com")!

        // When
        let match = await sut.evaluateURL(url)

        // Then
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.action, .proxy)
    }

    func testRulePriorityEvaluation() async throws {
        // Given - two rules that could match, different priorities
        let lowPriorityRule = ProxyRule(
            name: "Low Priority",
            matchType: .domainRegex,
            pattern: ".*",
            action: .proxy,
            priority: 1
        )

        let highPriorityRule = ProxyRule(
            name: "High Priority",
            matchType: .domain,
            pattern: "example.com",
            action: .direct,
            priority: 10
        )

        try await sut.saveRule(lowPriorityRule)
        try await sut.saveRule(highPriorityRule)

        let request = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com")!
        )

        // When
        let match = await sut.evaluateRequest(request)

        // Then - should match high priority rule
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.rule.id, highPriorityRule.id)
        XCTAssertEqual(match?.action, .direct)
    }

    // MARK: - Rule Management Tests

    func testReorderRules() async throws {
        // Given
        let rule1 = ProxyRule(
            name: "Rule 1",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy,
            priority: 1
        )

        let rule2 = ProxyRule(
            name: "Rule 2",
            matchType: .domain,
            pattern: "test.com",
            action: .proxy,
            priority: 2
        )

        try await sut.saveRule(rule1)
        try await sut.saveRule(rule2)

        // When - reorder (reverse)
        try await sut.reorderRules([rule2, rule1])

        let rules = try await sut.loadRules()

        // Then - priorities should be updated
        let reorderedRule1 = rules.first { $0.id == rule1.id }
        let reorderedRule2 = rules.first { $0.id == rule2.id }

        XCTAssertNotNil(reorderedRule1)
        XCTAssertNotNil(reorderedRule2)
        XCTAssertGreaterThan(reorderedRule2!.priority, reorderedRule1!.priority)
    }

    func testToggleRule() async throws {
        // Given
        let rule = ProxyRule(
            name: "Toggle Test",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy,
            enabled: true
        )
        try await sut.saveRule(rule)

        // When
        try await sut.toggleRule(id: rule.id)

        let toggledRule = await sut.getRule(id: rule.id)

        // Then
        XCTAssertFalse(toggledRule?.enabled ?? true)

        // When - toggle again
        try await sut.toggleRule(id: rule.id)

        let reToggledRule = await sut.getRule(id: rule.id)

        // Then
        XCTAssertTrue(reToggledRule?.enabled ?? false)
    }

    func testDuplicateRule() async throws {
        // Given
        let original = ProxyRule(
            name: "Original",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )
        try await sut.saveRule(original)

        // When
        let duplicate = try await sut.duplicateRule(id: original.id)

        // Then
        XCTAssertNotEqual(duplicate.id, original.id)
        XCTAssertTrue(duplicate.name.contains("Copy"))
        XCTAssertEqual(duplicate.pattern, original.pattern)
        XCTAssertEqual(duplicate.matchType, original.matchType)
        XCTAssertEqual(duplicate.action, original.action)
    }

    // MARK: - Validation Tests

    func testValidateRule() async {
        // Given - valid rule
        let validRule = ProxyRule(
            name: "Valid",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )

        // When
        let result = await sut.validateRule(validRule)

        // Then
        XCTAssertTrue(result.isValid)
    }

    func testValidateInvalidRule() async {
        // Given - invalid rule (empty pattern)
        let invalidRule = ProxyRule(
            name: "Invalid",
            matchType: .domain,
            pattern: "",
            action: .proxy
        )

        // When
        let result = await sut.validateRule(invalidRule)

        // Then
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Conflict Detection Tests

    func testDetectIdenticalPatternConflict() async throws {
        // Given
        let rule1 = ProxyRule(
            name: "Rule 1",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )

        let rule2 = ProxyRule(
            name: "Rule 2",
            matchType: .domain,
            pattern: "example.com",
            action: .direct // Different action
        )

        try await sut.saveRule(rule1)

        // When
        let conflicts = await sut.detectConflicts(for: rule2)

        // Then
        XCTAssertFalse(conflicts.isEmpty)
        XCTAssertEqual(conflicts[0].type, RuleConflict.ConflictType.identicalPatternDifferentAction)
    }

    func testDetectDuplicatePatternConflict() async throws {
        // Given
        let rule1 = ProxyRule(
            name: "Rule 1",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy,
            enabled: true
        )

        let rule2 = ProxyRule(
            name: "Rule 2",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy, // Same action
            enabled: true
        )

        try await sut.saveRule(rule1)

        // When
        let conflicts = await sut.detectConflicts(for: rule2)

        // Then
        XCTAssertFalse(conflicts.isEmpty)
    }

    func testNoConflicts() async throws {
        // Given
        let rule1 = ProxyRule(
            name: "Rule 1",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )

        let rule2 = ProxyRule(
            name: "Rule 2",
            matchType: .domain,
            pattern: "different.com",
            action: .proxy
        )

        try await sut.saveRule(rule1)

        // When
        let conflicts = await sut.detectConflicts(for: rule2)

        // Then
        XCTAssertTrue(conflicts.isEmpty)
    }

    // MARK: - Import/Export Tests

    func testExportRules() async throws {
        // Given
        let rule1 = ProxyRule(
            name: "Rule 1",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )

        let rule2 = ProxyRule(
            name: "Rule 2",
            matchType: .domain,
            pattern: "test.com",
            action: .direct
        )

        try await sut.saveRule(rule1)
        try await sut.saveRule(rule2)

        // When
        let data = try await sut.exportRules()

        // Then
        XCTAssertFalse(data.isEmpty)

        // Verify it's valid JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rules = try decoder.decode([ProxyRule].self, from: data)
        XCTAssertGreaterThanOrEqual(rules.count, 2)
    }

    func testImportRules() async throws {
        // Given
        let rules = [
            ProxyRule(
                name: "Imported Rule 1",
                matchType: .domain,
                pattern: "import1.com",
                action: .proxy
            ),
            ProxyRule(
                name: "Imported Rule 2",
                matchType: .domain,
                pattern: "import2.com",
                action: .direct
            )
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(rules)

        // When
        try await sut.importRules(from: data, merge: false)

        let loadedRules = try await sut.loadRules()

        // Then
        let importedRule1 = loadedRules.first { $0.name == "Imported Rule 1" }
        let importedRule2 = loadedRules.first { $0.name == "Imported Rule 2" }

        XCTAssertNotNil(importedRule1)
        XCTAssertNotNil(importedRule2)
    }

    func testExportSingleRule() async throws {
        // Given
        let rule = ProxyRule(
            name: "Export Test",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )
        try await sut.saveRule(rule)

        // When
        let data = try await sut.exportRule(id: rule.id)

        // Then
        XCTAssertFalse(data.isEmpty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportedRule = try decoder.decode(ProxyRule.self, from: data)
        XCTAssertEqual(exportedRule.id, rule.id)
    }

    // MARK: - Publisher Tests

    func testRulesPublisher() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Rules updated")
        var receivedRules: [ProxyRule]?

        sut.rules
            .dropFirst() // Skip initial value
            .sink { rules in
                receivedRules = rules
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        let rule = ProxyRule(
            name: "Test",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )
        try await sut.saveRule(rule)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedRules)
    }

    func testEnabledRulesPublisher() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Enabled rules updated")
        var receivedRules: [ProxyRule]?

        sut.enabledRules
            .dropFirst()
            .sink { rules in
                receivedRules = rules
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        let rule = ProxyRule(
            name: "Enabled Test",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy,
            enabled: true
        )
        try await sut.saveRule(rule)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedRules)
    }

    // MARK: - Error Handling Tests

    func testSaveInvalidRule() async {
        // Given
        let invalidRule = ProxyRule(
            name: "Invalid",
            matchType: .domain,
            pattern: "",
            action: .proxy
        )

        // When & Then
        do {
            try await sut.saveRule(invalidRule)
            XCTFail("Should throw error for invalid rule")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }

    func testUpdateNonExistentRule() async {
        // Given
        let rule = ProxyRule(
            name: "Non-existent",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy
        )

        // When & Then
        do {
            try await sut.updateRule(rule)
            XCTFail("Should throw error for non-existent rule")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }

    func testDeleteNonExistentRule() async {
        // Given
        let nonExistentID = UUID()

        // When & Then
        do {
            try await sut.deleteRule(id: nonExistentID)
            XCTFail("Should throw error for non-existent rule")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }

    // MARK: - Performance Tests

    func testPerformanceEvaluateManyRules() async throws {
        // Given - create many rules
        for i in 0..<100 {
            let rule = ProxyRule(
                name: "Rule \(i)",
                matchType: .domain,
                pattern: "example\(i).com",
                action: .proxy
            )
            try await sut.saveRule(rule)
        }

        let request = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example50.com")!
        )

        // Measure
        measure {
            let expectation = XCTestExpectation(description: "Evaluate")

            Task {
                _ = await sut.evaluateRequest(request)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 1.0)
        }
    }

    // MARK: - Edge Cases

    func testDisabledRuleDontMatch() async throws {
        // Given
        let rule = ProxyRule(
            name: "Disabled",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy,
            enabled: false
        )
        try await sut.saveRule(rule)

        let request = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com")!
        )

        // When
        let match = await sut.evaluateRequest(request)

        // Then
        XCTAssertNil(match)
    }

    func testMultipleRulesWithSamePriority() async throws {
        // Given - rules with same priority
        let rule1 = ProxyRule(
            name: "Rule 1",
            matchType: .domain,
            pattern: "example.com",
            action: .proxy,
            priority: 5
        )

        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        let rule2 = ProxyRule(
            name: "Rule 2",
            matchType: .domainRegex,
            pattern: ".*example.*",
            action: .direct,
            priority: 5
        )

        try await sut.saveRule(rule1)
        try await sut.saveRule(rule2)

        let request = NetworkRequest(
            method: .GET,
            url: URL(string: "https://example.com")!
        )

        // When
        let match = await sut.evaluateRequest(request)

        // Then - should match the older rule (created first)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.rule.id, rule1.id)
    }
}
