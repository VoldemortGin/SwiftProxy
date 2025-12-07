import SwiftUI
import SwiftProxyCore

/// View for creating and editing proxy rules
/// Provides comprehensive rule configuration with validation
struct RuleEditorView: View {
    // MARK: - Properties
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RuleEditorViewModel

    let onSave: (ProxyRule) -> Void

    // MARK: - Initialization
    init(rule: ProxyRule? = nil, onSave: @escaping (ProxyRule) -> Void) {
        _viewModel = StateObject(wrappedValue: RuleEditorViewModel(rule: rule))
        self.onSave = onSave
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    basicInfoSection
                    matchTypeSection
                    actionSection
                    advancedSection
                    validationSection
                }
                .padding(24)
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 600, height: 700)
    }

    // MARK: - Subviews
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.isEditing ? "Edit Rule" : "New Rule")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Configure proxy routing rule")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Basic Information")

            VStack(alignment: .leading, spacing: 12) {
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rule Name")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("e.g., Block Ads", text: $viewModel.name)
                        .textFieldStyle(.roundedBorder)
                }

                // Priority
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Priority")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text("Higher values match first")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        Slider(value: $viewModel.priorityValue, in: 0...100, step: 1)

                        Text("\(Int(viewModel.priorityValue))")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 40)
                    }
                }

                // Enabled toggle
                Toggle("Rule Enabled", isOn: $viewModel.enabled)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    private var matchTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Match Criteria")

            VStack(alignment: .leading, spacing: 12) {
                // Match type picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Match Type")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Match Type", selection: $viewModel.matchType) {
                        Text("Domain").tag(RuleMatchType.domain)
                        Text("Domain Suffix").tag(RuleMatchType.domainSuffix)
                        Text("Domain Keyword").tag(RuleMatchType.domainKeyword)
                        Text("Domain Regex").tag(RuleMatchType.domainRegex)
                        Text("IP Address").tag(RuleMatchType.ipAddress)
                        Text("IP CIDR").tag(RuleMatchType.ipCIDR)
                        Text("Port").tag(RuleMatchType.port)
                        Text("Port Range").tag(RuleMatchType.portRange)
                        Text("User Agent").tag(RuleMatchType.userAgent)
                        Text("GeoIP").tag(RuleMatchType.geoIP)
                        Text("Final (Catch All)").tag(RuleMatchType.final)
                    }
                    .pickerStyle(.menu)
                }

                // Pattern input
                if viewModel.matchType != .final {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pattern")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField(viewModel.patternPlaceholder, text: $viewModel.pattern)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))

                        Text(viewModel.patternHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Action")

            VStack(alignment: .leading, spacing: 12) {
                // Action picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("When rule matches")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Action", selection: $viewModel.action) {
                        Label("Direct (No proxy)", systemImage: "arrow.right")
                            .tag(RuleAction.direct)
                        Label("Proxy", systemImage: "arrow.triangle.branch")
                            .tag(RuleAction.proxy)
                        Label("Reject", systemImage: "xmark.circle")
                            .tag(RuleAction.reject)
                    }
                    .pickerStyle(.radioGroup)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Advanced")

            VStack(alignment: .leading, spacing: 12) {
                // Notes
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextEditor(text: $viewModel.notes)
                        .font(.body)
                        .frame(height: 80)
                        .border(Color.gray.opacity(0.2), width: 1)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    private var validationSection: some View {
        Group {
            if let error = viewModel.validationError {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Validation Error")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
            } else if viewModel.isValid {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text("Rule is valid")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Save Rule") {
                if let rule = viewModel.createRule() {
                    onSave(rule)
                    dismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.isValid)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Helper Methods
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

// MARK: - View Model
@MainActor
final class RuleEditorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var name: String = ""
    @Published var matchType: RuleMatchType = .domainSuffix
    @Published var pattern: String = ""
    @Published var action: RuleAction = .proxy
    @Published var priorityValue: Double = 50
    @Published var enabled: Bool = true
    @Published var notes: String = ""

    // MARK: - Computed Properties
    var isEditing: Bool { originalRule != nil }

    var isValid: Bool {
        validationError == nil && !name.isEmpty && (matchType == .final || !pattern.isEmpty)
    }

    var validationError: String? {
        if name.isEmpty {
            return "Rule name is required"
        }

        if matchType != .final && pattern.isEmpty {
            return "Pattern is required"
        }

        // Validate regex
        if matchType == .domainRegex {
            guard (try? NSRegularExpression(pattern: pattern)) != nil else {
                return "Invalid regular expression"
            }
        }

        // Validate CIDR
        if matchType == .ipCIDR {
            let components = pattern.components(separatedBy: "/")
            guard components.count == 2,
                  let prefix = Int(components[1]),
                  prefix >= 0 && prefix <= 32 else {
                return "Invalid CIDR format (e.g., 192.168.0.0/16)"
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
                return "Invalid port range (e.g., 80-443)"
            }
        }

        // Validate port
        if matchType == .port {
            guard let port = Int(pattern),
                  port > 0 && port <= 65535 else {
                return "Invalid port number (1-65535)"
            }
        }

        return nil
    }

    var patternPlaceholder: String {
        switch matchType {
        case .domain:
            return "example.com"
        case .domainSuffix:
            return ".example.com"
        case .domainKeyword:
            return "google"
        case .domainRegex:
            return ".*\\.example\\.com"
        case .ipAddress:
            return "192.168.1.1"
        case .ipCIDR:
            return "192.168.0.0/16"
        case .port:
            return "80"
        case .portRange:
            return "80-443"
        case .userAgent:
            return "Mozilla/5.0"
        case .geoIP:
            return "CN"
        case .final:
            return ""
        default:
            return ""
        }
    }

    var patternHint: String {
        switch matchType {
        case .domain:
            return "Matches exact domain (e.g., example.com)"
        case .domainSuffix:
            return "Matches domain and all subdomains (e.g., .example.com)"
        case .domainKeyword:
            return "Matches if domain contains keyword"
        case .domainRegex:
            return "Regular expression pattern for domain matching"
        case .ipAddress:
            return "Matches exact IP address"
        case .ipCIDR:
            return "Matches IP range in CIDR notation (e.g., 192.168.0.0/16)"
        case .port:
            return "Matches port number (1-65535)"
        case .portRange:
            return "Matches port range (e.g., 80-443)"
        case .userAgent:
            return "Matches User-Agent header"
        case .geoIP:
            return "Matches by country code (e.g., CN, US)"
        case .final:
            return "Catch-all rule (matches everything)"
        default:
            return ""
        }
    }

    // MARK: - Private Properties
    private let originalRule: ProxyRule?

    // MARK: - Initialization
    init(rule: ProxyRule?) {
        self.originalRule = rule

        if let rule = rule {
            self.name = rule.name
            self.matchType = rule.matchType
            self.pattern = rule.pattern
            self.action = rule.action
            self.priorityValue = Double(rule.priority)
            self.enabled = rule.enabled
            self.notes = rule.notes ?? ""
        }
    }

    // MARK: - Methods
    func createRule() -> ProxyRule? {
        guard isValid else { return nil }

        return ProxyRule(
            id: originalRule?.id ?? UUID(),
            name: name,
            matchType: matchType,
            pattern: pattern,
            action: action,
            priority: Int(priorityValue),
            enabled: enabled,
            notes: notes.isEmpty ? nil : notes
        )
    }
}

// MARK: - Preview
#Preview("New Rule") {
    RuleEditorView { _ in
        // Preview callback
    }
}

#Preview("Edit Rule") {
    RuleEditorView(rule: ProxyRule(
        name: "Block Ads",
        matchType: .domainSuffix,
        pattern: ".doubleclick.net",
        action: .reject,
        priority: 90,
        notes: "Block advertising domains"
    )) { _ in
        // Preview callback
    }
}
