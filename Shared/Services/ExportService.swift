import Foundation
import OSLog

/// Service for exporting statistics data to various formats
/// Handles CSV and JSON export with filtering and templating
public protocol ExportServiceProtocol: Sendable {
    func exportStatistics(
        statistics: Statistics,
        connections: [Connection],
        configuration: ExportConfiguration
    ) async throws -> Data

    func estimateRecordCount(
        connections: [Connection],
        configuration: ExportConfiguration
    ) -> Int

    func validateConfiguration(_ configuration: ExportConfiguration) -> [String]
}

/// Export service implementation
public final class ExportService: ExportServiceProtocol, @unchecked Sendable {
    // MARK: - Properties

    private let logger = OSLog(subsystem: "com.swiftproxy.app", category: "ExportService")

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    public func exportStatistics(
        statistics: Statistics,
        connections: [Connection],
        configuration: ExportConfiguration
    ) async throws -> Data {
        os_log(.info, log: logger, "Starting export with format: %@", configuration.format.rawValue)

        // Filter connections based on configuration
        let filteredConnections = await filterConnections(connections, configuration: configuration)

        os_log(.info, log: logger, "Filtered to %d connections", filteredConnections.count)

        // Export based on format
        let data: Data
        switch configuration.format {
        case .csv:
            data = try await exportToCSV(
                statistics: statistics,
                connections: filteredConnections,
                configuration: configuration
            )
        case .json:
            data = try await exportToJSON(
                statistics: statistics,
                connections: filteredConnections,
                configuration: configuration
            )
        }

        os_log(.info, log: logger, "Export completed: %d bytes", data.count)
        return data
    }

    public func estimateRecordCount(
        connections: [Connection],
        configuration: ExportConfiguration
    ) -> Int {
        let startDate = configuration.effectiveStartDate
        let endDate = configuration.effectiveEndDate

        var count = 0
        for connection in connections {
            if connection.startTime >= startDate && connection.startTime <= endDate {
                if matchesFilters(connection, filters: configuration.filters) {
                    count += 1
                }
            }
        }

        return count
    }

    public func validateConfiguration(_ configuration: ExportConfiguration) -> [String] {
        var errors: [String] = []

        // Validate date range
        if configuration.dateRange == .custom {
            guard let start = configuration.customStartDate,
                  let end = configuration.customEndDate else {
                errors.append("Custom date range requires both start and end dates")
                return errors
            }

            if start > end {
                errors.append("Start date must be before end date")
            }

            if start > Date() {
                errors.append("Start date cannot be in the future")
            }
        }

        // Validate custom template
        if configuration.template == .custom {
            // In a real implementation, would validate custom field selection
        }

        return errors
    }

    // MARK: - Private Methods - Filtering

    private func filterConnections(
        _ connections: [Connection],
        configuration: ExportConfiguration
    ) async -> [Connection] {
        let startDate = configuration.effectiveStartDate
        let endDate = configuration.effectiveEndDate

        return connections.filter { connection in
            // Date range filter
            guard connection.startTime >= startDate && connection.startTime <= endDate else {
                return false
            }

            // Apply other filters
            return matchesFilters(connection, filters: configuration.filters)
        }
    }

    private func matchesFilters(_ connection: Connection, filters: ExportFilters) -> Bool {
        // Domain filter
        if let domains = filters.domains, !domains.isEmpty {
            guard domains.contains(connection.host) else { return false }
        }

        // Protocol filter
        if let protocols = filters.protocols, !protocols.isEmpty {
            guard protocols.contains(connection.protocol) else { return false }
        }

        // State filter
        if let states = filters.states, !states.isEmpty {
            guard states.contains(connection.state) else { return false }
        }

        // HTTP method filter
        if let methods = filters.httpMethods, !methods.isEmpty {
            guard let method = connection.requestMethod, methods.contains(method) else {
                return false
            }
        }

        // Status code filter
        if let ranges = filters.statusCodeRanges, !ranges.isEmpty {
            guard let statusCode = connection.responseStatusCode,
                  ranges.contains(where: { $0.contains(statusCode) }) else {
                return false
            }
        }

        // Bytes transferred filter
        if let minBytes = filters.minBytesTransferred {
            guard connection.totalBytes >= minBytes else { return false }
        }

        if let maxBytes = filters.maxBytesTransferred {
            guard connection.totalBytes <= maxBytes else { return false }
        }

        return true
    }

    // MARK: - Private Methods - CSV Export

    private func exportToCSV(
        statistics: Statistics,
        connections: [Connection],
        configuration: ExportConfiguration
    ) async throws -> Data {
        var csv = ""

        // Add metadata if requested
        if configuration.includeMetadata {
            csv += "# SwiftProxy Statistics Export\n"
            csv += "# Generated: \(ISO8601DateFormatter().string(from: Date()))\n"
            csv += "# Date Range: \(formatDate(configuration.effectiveStartDate)) to \(formatDate(configuration.effectiveEndDate))\n"
            csv += "# Total Records: \(connections.count)\n"
            csv += "# Template: \(configuration.template.rawValue)\n"
            csv += "\n"
        }

        // Get fields to export
        let fields = configuration.template.fields

        // CSV header
        csv += fields.map { $0.rawValue }.joined(separator: ",")
        csv += "\n"

        // CSV rows
        for connection in connections {
            let values = fields.map { field in
                escapeCSVValue(getFieldValue(field, from: connection))
            }
            csv += values.joined(separator: ",")
            csv += "\n"
        }

        guard let data = csv.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }

        return data
    }

    private func escapeCSVValue(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    private func getFieldValue(_ field: ExportField, from connection: Connection) -> String {
        switch field {
        case .id:
            return connection.id.uuidString
        case .timestamp:
            return ISO8601DateFormatter().string(from: connection.startTime)
        case .host:
            return connection.host
        case .port:
            return String(connection.port)
        case .address:
            return connection.address
        case .`protocol`:
            return connection.protocol.rawValue
        case .state:
            return connection.state.rawValue
        case .startTime:
            return ISO8601DateFormatter().string(from: connection.startTime)
        case .endTime:
            return connection.endTime.map { ISO8601DateFormatter().string(from: $0) } ?? ""
        case .duration:
            return String(format: "%.3f", connection.duration)
        case .bytesReceived:
            return String(connection.bytesReceived)
        case .bytesSent:
            return String(connection.bytesSent)
        case .totalBytes:
            return String(connection.totalBytes)
        case .dataRate:
            return String(format: "%.2f", connection.averageDataRate)
        case .requestURL:
            return connection.requestURL?.absoluteString ?? ""
        case .requestMethod:
            return connection.requestMethod ?? ""
        case .statusCode:
            return connection.responseStatusCode.map { String($0) } ?? ""
        case .contentType:
            return connection.contentType ?? ""
        case .processName:
            return connection.processName ?? ""
        case .processID:
            return connection.processID.map { String($0) } ?? ""
        case .matchedRuleID:
            return connection.matchedRuleID?.uuidString ?? ""
        case .ruleAction:
            return connection.ruleAction?.rawValue ?? ""
        case .averageLatency:
            return String(format: "%.3f", connection.duration)
        case .error:
            return connection.error ?? ""
        }
    }

    // MARK: - Private Methods - JSON Export

    private func exportToJSON(
        statistics: Statistics,
        connections: [Connection],
        configuration: ExportConfiguration
    ) async throws -> Data {
        var json: [String: Any] = [:]

        // Add metadata if requested
        if configuration.includeMetadata {
            json["metadata"] = [
                "exportedAt": ISO8601DateFormatter().string(from: Date()),
                "version": "1.0.0",
                "application": "SwiftProxy",
                "dateRange": [
                    "start": ISO8601DateFormatter().string(from: configuration.effectiveStartDate),
                    "end": ISO8601DateFormatter().string(from: configuration.effectiveEndDate)
                ],
                "recordCount": connections.count,
                "template": configuration.template.rawValue,
                "filters": configuration.filters.isActive ? "Applied" : "None"
            ]

            // Add summary statistics
            json["summary"] = [
                "sessionStart": ISO8601DateFormatter().string(from: statistics.session.startTime),
                "totalConnections": statistics.session.connectionCount,
                "activeConnections": statistics.session.activeConnections,
                "successfulConnections": statistics.session.successfulConnections,
                "failedConnections": statistics.session.failedConnections,
                "totalBytesReceived": statistics.session.bytesReceived,
                "totalBytesSent": statistics.session.bytesSent,
                "totalBytes": statistics.session.totalBytes,
                "successRate": statistics.session.successRate,
                "uptime": statistics.session.uptime
            ]
        }

        // Add connections data
        let fields = configuration.template.fields
        let connectionsData = connections.map { connection -> [String: Any] in
            var record: [String: Any] = [:]
            for field in fields {
                let value = getFieldValue(field, from: connection)
                // Try to parse numbers for better JSON structure
                if let intValue = Int64(value) {
                    record[field.rawValue] = intValue
                } else if let doubleValue = Double(value) {
                    record[field.rawValue] = doubleValue
                } else {
                    record[field.rawValue] = value.isEmpty ? nil : value
                }
            }
            return record
        }

        json["connections"] = connectionsData

        // Serialize to JSON
        let options: JSONSerialization.WritingOptions = configuration.prettyPrintJSON
            ? [.prettyPrinted, .sortedKeys]
            : [.sortedKeys]

        let data = try JSONSerialization.data(withJSONObject: json, options: options)
        return data
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Export Error

public enum ExportError: Error, LocalizedError {
    case encodingFailed
    case invalidConfiguration
    case noDataToExport
    case writeError(Error)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode export data"
        case .invalidConfiguration:
            return "Invalid export configuration"
        case .noDataToExport:
            return "No data available to export"
        case .writeError(let error):
            return "Failed to write export file: \(error.localizedDescription)"
        }
    }
}

// MARK: - Default Implementation

extension ExportService {
    public static let shared = ExportService()
}
