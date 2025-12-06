import Foundation
import SwiftProxyCore
import Combine
import OSLog
import AppKit

/// View model for managing proxy rules in the settings UI
/// Handles CRUD operations, import/export, and rule validation
@MainActor
final class RulesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var rules: [ProxyRule] = []
    @Published var selectedRule: ProxyRule?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isLoading = false
    @Published var showRuleEditor = false
    @Published var editingRule: ProxyRule?

    // MARK: - Dependencies
    private let ruleService: RuleServiceProtocol
    private let logger = Logger.rulesLog
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(ruleService: RuleServiceProtocol) {
        self.ruleService = ruleService
        setupBindings()
        loadRules()
    }

    // MARK: - Setup
    private func setupBindings() {
        ruleService.rules
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rules in
                self?.rules = rules
            }
            .store(in: &cancellables)
    }

    // MARK: - Rule Management
    func loadRules() {
        Task {
            isLoading = true
            do {
                rules = try await ruleService.loadRules()
                os_log(.info, log: logger, "Loaded %d rules", rules.count)
            } catch {
                handleError(error)
            }
            isLoading = false
        }
    }

    func saveRule(_ rule: ProxyRule) {
        Task {
            isLoading = true
            do {
                try await ruleService.saveRule(rule)
                successMessage = "Rule '\(rule.name)' saved successfully"
                os_log(.info, log: logger, "Rule saved: %@", rule.name)

                // Clear success message after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                successMessage = nil
            } catch {
                handleError(error)
            }
            isLoading = false
        }
    }

    func updateRule(_ rule: ProxyRule) {
        Task {
            isLoading = true
            do {
                try await ruleService.updateRule(rule)
                successMessage = "Rule '\(rule.name)' updated successfully"
                os_log(.info, log: logger, "Rule updated: %@", rule.name)

                // Clear success message after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                successMessage = nil
            } catch {
                handleError(error)
            }
            isLoading = false
        }
    }

    func deleteRule(_ rule: ProxyRule) {
        Task {
            isLoading = true
            do {
                try await ruleService.deleteRule(id: rule.id)
                successMessage = "Rule '\(rule.name)' deleted successfully"
                os_log(.info, log: logger, "Rule deleted: %@", rule.name)

                // Clear success message after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                successMessage = nil
            } catch {
                handleError(error)
            }
            isLoading = false
        }
    }

    func toggleRule(_ rule: ProxyRule) {
        Task {
            do {
                try await ruleService.toggleRule(id: rule.id)
                os_log(.info, log: logger, "Rule toggled: %@", rule.name)
            } catch {
                handleError(error)
            }
        }
    }

    func duplicateRule(_ rule: ProxyRule) {
        Task {
            isLoading = true
            do {
                let duplicate = try await ruleService.duplicateRule(id: rule.id)
                successMessage = "Rule '\(rule.name)' duplicated"
                os_log(.info, log: logger, "Rule duplicated: %@", rule.name)

                // Show editor for the duplicate
                editingRule = duplicate
                showRuleEditor = true

                // Clear success message after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                successMessage = nil
            } catch {
                handleError(error)
            }
            isLoading = false
        }
    }

    func reorderRules(_ rules: [ProxyRule]) {
        Task {
            do {
                try await ruleService.reorderRules(rules)
                os_log(.info, log: logger, "Rules reordered")
            } catch {
                handleError(error)
            }
        }
    }

    // MARK: - Import/Export
    func importRules(from url: URL) {
        Task {
            isLoading = true
            do {
                let data = try Data(contentsOf: url)

                // Try to parse as JSON array first
                if let jsonRules = try? JSONDecoder().decode([ProxyRule].self, from: data) {
                    // Import JSON rules
                    try await ruleService.importRules(from: data, merge: true)
                    successMessage = "Imported \(jsonRules.count) rules from JSON file"
                    os_log(.info, log: logger, "Imported %d JSON rules", jsonRules.count)
                } else {
                    // Try to parse as text file (Surge format)
                    let content = String(data: data, encoding: .utf8) ?? ""
                    let importedRules = try parseSurgeFormat(content)

                    for rule in importedRules {
                        try await ruleService.saveRule(rule)
                    }

                    successMessage = "Imported \(importedRules.count) rules from text file"
                    os_log(.info, log: logger, "Imported %d text rules", importedRules.count)
                }

                // Clear success message after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                successMessage = nil
            } catch {
                handleError(error)
            }
            isLoading = false
        }
    }

    func exportRules() {
        Task {
            do {
                let data = try await ruleService.exportRules()

                // Show save panel
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.json]
                savePanel.nameFieldStringValue = "swiftproxy-rules.json"
                savePanel.message = "Export proxy rules"

                let response = await savePanel.begin()
                if response == .OK, let url = savePanel.url {
                    try data.write(to: url)
                    successMessage = "Rules exported successfully"
                    os_log(.info, log: logger, "Rules exported to: %@", url.path)

                    // Clear success message after 3 seconds
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    successMessage = nil
                }
            } catch {
                handleError(error)
            }
        }
    }

    // MARK: - UI Actions
    func showNewRuleEditor() {
        editingRule = nil
        showRuleEditor = true
    }

    func showEditRuleEditor(for rule: ProxyRule) {
        editingRule = rule
        showRuleEditor = true
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    // MARK: - Private Methods
    private func parseSurgeFormat(_ content: String) throws -> [ProxyRule] {
        var rules: [ProxyRule] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("//") else {
                continue
            }

            // Try to parse as rule
            if let rule = ProxyRule.parse(from: trimmed) {
                rules.append(rule)
            }
        }

        return rules
    }

    private func handleError(_ error: Error) {
        let appError = error as? AppError ?? .unknown(error)
        errorMessage = appError.errorDescription
        os_log(.error, log: logger, "Error: %@", appError.errorDescription ?? "Unknown error")
    }
}

// MARK: - Preview Helpers
extension RulesViewModel {
    static var preview: RulesViewModel {
        let mockService = MockRuleService()
        return RulesViewModel(ruleService: mockService)
    }
}

// MARK: - Mock Service for Previews
final class MockRuleService: RuleServiceProtocol {
    private let rulesSubject = CurrentValueSubject<[ProxyRule], Never>(ProxyRule.presets)
    private let enabledRulesSubject = CurrentValueSubject<[ProxyRule], Never>(ProxyRule.presets.filter { $0.enabled })

    var rules: AnyPublisher<[ProxyRule], Never> {
        rulesSubject.eraseToAnyPublisher()
    }

    var enabledRules: AnyPublisher<[ProxyRule], Never> {
        enabledRulesSubject.eraseToAnyPublisher()
    }

    func loadRules() async throws -> [ProxyRule] {
        ProxyRule.presets
    }

    func saveRule(_ rule: ProxyRule) async throws {
        var current = rulesSubject.value
        current.append(rule)
        rulesSubject.send(current)
    }

    func updateRule(_ rule: ProxyRule) async throws {
        var current = rulesSubject.value
        if let index = current.firstIndex(where: { $0.id == rule.id }) {
            current[index] = rule
            rulesSubject.send(current)
        }
    }

    func deleteRule(id: UUID) async throws {
        var current = rulesSubject.value
        current.removeAll { $0.id == id }
        rulesSubject.send(current)
    }

    func getRule(id: UUID) async -> ProxyRule? {
        rulesSubject.value.first { $0.id == id }
    }

    func evaluateRequest(_ request: NetworkRequest) async -> RuleMatch? {
        nil
    }

    func evaluateURL(_ url: URL) async -> RuleMatch? {
        nil
    }

    func reorderRules(_ rules: [ProxyRule]) async throws {
        rulesSubject.send(rules)
    }

    func toggleRule(id: UUID) async throws {
        // Mock implementation
    }

    func duplicateRule(id: UUID) async throws -> ProxyRule {
        guard let original = rulesSubject.value.first(where: { $0.id == id }) else {
            throw AppError.ruleNotFound(id)
        }

        return ProxyRule(
            name: "\(original.name) Copy",
            matchType: original.matchType,
            pattern: original.pattern,
            action: original.action,
            priority: original.priority - 1
        )
    }

    func exportRules() async throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return try encoder.encode(rulesSubject.value)
    }

    func importRules(from data: Data, merge: Bool) async throws {
        let decoder = JSONDecoder()
        let rules = try decoder.decode([ProxyRule].self, from: data)

        if merge {
            var current = rulesSubject.value
            current.append(contentsOf: rules)
            rulesSubject.send(current)
        } else {
            rulesSubject.send(rules)
        }
    }

    func exportRule(id: UUID) async throws -> Data {
        guard let rule = rulesSubject.value.first(where: { $0.id == id }) else {
            throw AppError.ruleNotFound(id)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return try encoder.encode(rule)
    }

    func validateRule(_ rule: ProxyRule) async -> ProxyRule.ValidationResult {
        rule.validate()
    }

    func detectConflicts(for rule: ProxyRule) async -> [RuleConflict] {
        []
    }
}
