import SwiftUI
import SwiftProxyCore
import UniformTypeIdentifiers

/// View for configuring statistics export
/// Provides options for format, date range, filters, and templates
struct ExportConfigurationView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Binding var configuration: ExportConfiguration
    let connections: [Connection]
    let statistics: Statistics
    let onExport: (ExportConfiguration) -> Void

    @State private var showingCustomFieldSelection = false
    @State private var selectedCustomFields: Set<ExportField> = []
    @State private var estimatedRecords: Int = 0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Configuration content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Format selection
                    formatSection

                    Divider()

                    // Date range selection
                    dateRangeSection

                    Divider()

                    // Template selection
                    templateSection

                    Divider()

                    // Filters
                    filtersSection

                    Divider()

                    // Options
                    optionsSection

                    Divider()

                    // Preview
                    previewSection
                }
                .padding()
            }

            Divider()

            // Footer with actions
            footerView
        }
        .frame(width: 600, height: 700)
        .onChange(of: configuration) { _ in
            updateEstimate()
        }
        .onAppear {
            updateEstimate()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export Statistics")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Configure export settings and filters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
        }
        .padding()
    }

    // MARK: - Format Section

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Format")
                .font(.headline)

            Picker("Format", selection: $configuration.format) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)

            Text(formatDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var formatDescription: String {
        switch configuration.format {
        case .csv:
            return "Comma-separated values, compatible with Excel and other spreadsheet applications"
        case .json:
            return "Structured JSON format, ideal for programmatic processing and analysis"
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date Range")
                .font(.headline)

            Picker("Range", selection: $configuration.dateRange) {
                ForEach(DateRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.menu)

            if configuration.dateRange == .custom {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker(
                        "Start Date",
                        selection: Binding(
                            get: { configuration.customStartDate ?? Date() },
                            set: { configuration.customStartDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    DatePicker(
                        "End Date",
                        selection: Binding(
                            get: { configuration.customEndDate ?? Date() },
                            set: { configuration.customEndDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                .padding(.leading)
            }

            Text("Export data from: \(formatDate(configuration.effectiveStartDate)) to \(formatDate(configuration.effectiveEndDate))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Template Section

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Template")
                .font(.headline)

            Picker("Template", selection: $configuration.template) {
                ForEach(ExportTemplate.allCases) { template in
                    Text(template.rawValue).tag(template)
                }
            }
            .pickerStyle(.menu)

            Text(configuration.template.description)
                .font(.caption)
                .foregroundColor(.secondary)

            if configuration.template == .custom {
                Button("Select Fields...") {
                    showingCustomFieldSelection = true
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showingCustomFieldSelection) {
            CustomFieldSelectionView(
                selectedFields: $selectedCustomFields,
                onDone: { dismiss() }
            )
        }
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filters")
                    .font(.headline)

                Spacer()

                if configuration.filters.isActive {
                    Button("Clear All") {
                        configuration.filters = ExportFilters()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }

            // Protocol filter
            if !availableProtocols.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protocols")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(Array(availableProtocols), id: \.self) { proto in
                            FilterToggle(
                                title: proto.rawValue,
                                isSelected: configuration.filters.protocols?.contains(proto) ?? false
                            ) {
                                toggleProtocol(proto)
                            }
                        }
                    }
                }
            }

            // State filter
            VStack(alignment: .leading, spacing: 4) {
                Text("Connection States")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(ConnectionState.allCases, id: \.self) { state in
                        FilterToggle(
                            title: state.rawValue,
                            isSelected: configuration.filters.states?.contains(state) ?? false
                        ) {
                            toggleState(state)
                        }
                    }
                }
            }

            // Status code filter (if HTTP/HTTPS connections exist)
            if hasHTTPConnections {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HTTP Status Codes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(StatusCodeRange.allCases, id: \.self) { range in
                            FilterToggle(
                                title: range.rawValue,
                                isSelected: configuration.filters.statusCodeRanges?.contains(range) ?? false
                            ) {
                                toggleStatusCodeRange(range)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)

            Toggle("Include Metadata", isOn: $configuration.includeMetadata)
                .toggleStyle(.switch)

            if configuration.format == .json {
                Toggle("Pretty Print JSON", isOn: $configuration.prettyPrintJSON)
                    .toggleStyle(.switch)
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Records")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(estimatedRecords)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(estimatedRecords > 0 ? .primary : .red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("File Type")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(".\(configuration.format.fileExtension)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            if estimatedRecords == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text("No records match the current filters. Try adjusting your date range or filters.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Export...") {
                onExport(configuration)
            }
            .buttonStyle(.borderedProminent)
            .disabled(estimatedRecords == 0)
        }
        .padding()
    }

    // MARK: - Helper Methods

    private func updateEstimate() {
        estimatedRecords = ExportService.shared.estimateRecordCount(
            connections: connections,
            configuration: configuration
        )
    }

    private func toggleProtocol(_ protocol: ConnectionProtocol) {
        if configuration.filters.protocols == nil {
            configuration.filters.protocols = Set()
        }

        if configuration.filters.protocols!.contains(`protocol`) {
            configuration.filters.protocols!.remove(`protocol`)
            if configuration.filters.protocols!.isEmpty {
                configuration.filters.protocols = nil
            }
        } else {
            configuration.filters.protocols!.insert(`protocol`)
        }
    }

    private func toggleState(_ state: ConnectionState) {
        if configuration.filters.states == nil {
            configuration.filters.states = Set()
        }

        if configuration.filters.states!.contains(state) {
            configuration.filters.states!.remove(state)
            if configuration.filters.states!.isEmpty {
                configuration.filters.states = nil
            }
        } else {
            configuration.filters.states!.insert(state)
        }
    }

    private func toggleStatusCodeRange(_ range: StatusCodeRange) {
        if configuration.filters.statusCodeRanges == nil {
            configuration.filters.statusCodeRanges = []
        }

        if configuration.filters.statusCodeRanges!.contains(range) {
            configuration.filters.statusCodeRanges!.removeAll { $0 == range }
            if configuration.filters.statusCodeRanges!.isEmpty {
                configuration.filters.statusCodeRanges = nil
            }
        } else {
            configuration.filters.statusCodeRanges!.append(range)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Computed Properties

    private var availableProtocols: Set<ConnectionProtocol> {
        Set(connections.map { $0.protocol })
    }

    private var hasHTTPConnections: Bool {
        connections.contains { $0.protocol == .http || $0.protocol == .https }
    }
}

// MARK: - Filter Toggle

private struct FilterToggle: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowLayoutResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowLayoutResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowLayoutResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Custom Field Selection View

private struct CustomFieldSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFields: Set<ExportField>

    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Fields")
                    .font(.headline)

                Spacer()

                Button("Done") {
                    onDone()
                    dismiss()
                }
            }
            .padding()

            Divider()

            // Field selection by category
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(FieldCategory.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(fieldsInCategory(category), id: \.self) { field in
                                    Toggle(field.rawValue, isOn: Binding(
                                        get: { selectedFields.contains(field) },
                                        set: { isOn in
                                            if isOn {
                                                selectedFields.insert(field)
                                            } else {
                                                selectedFields.remove(field)
                                            }
                                        }
                                    ))
                                }
                            }
                            .padding(.leading)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 500)
    }

    private func fieldsInCategory(_ category: FieldCategory) -> [ExportField] {
        ExportField.allCases.filter { $0.category == category }
    }
}

// MARK: - Preview

#Preview {
    ExportConfigurationView(
        configuration: .constant(ExportConfiguration()),
        connections: [],
        statistics: Statistics()
    ) { _ in }
}
