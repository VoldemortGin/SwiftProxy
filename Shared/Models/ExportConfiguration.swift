import Foundation

/// Configuration for exporting statistics data
/// Defines format, date range, filters, and template options
public struct ExportConfiguration: Codable, Equatable {
    // MARK: - Properties

    /// Export format
    public var format: ExportFormat

    /// Date range for export
    public var dateRange: DateRange

    /// Custom date range (if dateRange is .custom)
    public var customStartDate: Date?
    public var customEndDate: Date?

    /// Filters to apply
    public var filters: ExportFilters

    /// Template to use
    public var template: ExportTemplate

    /// Include metadata in export
    public var includeMetadata: Bool

    /// Pretty print JSON (JSON format only)
    public var prettyPrintJSON: Bool

    // MARK: - Initialization

    public init(
        format: ExportFormat = .csv,
        dateRange: DateRange = .today,
        customStartDate: Date? = nil,
        customEndDate: Date? = nil,
        filters: ExportFilters = ExportFilters(),
        template: ExportTemplate = .full,
        includeMetadata: Bool = true,
        prettyPrintJSON: Bool = true
    ) {
        self.format = format
        self.dateRange = dateRange
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
        self.filters = filters
        self.template = template
        self.includeMetadata = includeMetadata
        self.prettyPrintJSON = prettyPrintJSON
    }

    // MARK: - Computed Properties

    /// Get the actual start and end dates based on dateRange
    public var effectiveStartDate: Date {
        switch dateRange {
        case .custom:
            return customStartDate ?? Date().addingTimeInterval(-86400)
        case .today:
            return Calendar.current.startOfDay(for: Date())
        case .yesterday:
            let today = Calendar.current.startOfDay(for: Date())
            return Calendar.current.date(byAdding: .day, value: -1, to: today)!
        case .thisWeek:
            let now = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            return calendar.date(from: components)!
        case .thisMonth:
            let now = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: now)
            return calendar.date(from: components)!
        case .last7Days:
            return Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        case .last30Days:
            return Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        case .allTime:
            return Date.distantPast
        }
    }

    public var effectiveEndDate: Date {
        switch dateRange {
        case .custom:
            return customEndDate ?? Date()
        case .yesterday:
            let today = Calendar.current.startOfDay(for: Date())
            return today.addingTimeInterval(-1) // End of yesterday
        default:
            return Date()
        }
    }
}

// MARK: - Export Format

public enum ExportFormat: String, Codable, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }

    public var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        }
    }
}

// MARK: - Date Range

public enum DateRange: String, Codable, CaseIterable, Identifiable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case allTime = "All Time"
    case custom = "Custom Range"

    public var id: String { rawValue }
}

// MARK: - Export Filters

public struct ExportFilters: Codable, Equatable {
    /// Filter by domain (nil or empty = all)
    public var domains: Set<String>?

    /// Filter by protocol
    public var protocols: Set<ConnectionProtocol>?

    /// Filter by connection state
    public var states: Set<ConnectionState>?

    /// Filter by HTTP method
    public var httpMethods: Set<String>?

    /// Filter by response status code ranges
    public var statusCodeRanges: [StatusCodeRange]?

    /// Minimum bytes transferred
    public var minBytesTransferred: UInt64?

    /// Maximum bytes transferred
    public var maxBytesTransferred: UInt64?

    public init(
        domains: Set<String>? = nil,
        protocols: Set<ConnectionProtocol>? = nil,
        states: Set<ConnectionState>? = nil,
        httpMethods: Set<String>? = nil,
        statusCodeRanges: [StatusCodeRange]? = nil,
        minBytesTransferred: UInt64? = nil,
        maxBytesTransferred: UInt64? = nil
    ) {
        self.domains = domains
        self.protocols = protocols
        self.states = states
        self.httpMethods = httpMethods
        self.statusCodeRanges = statusCodeRanges
        self.minBytesTransferred = minBytesTransferred
        self.maxBytesTransferred = maxBytesTransferred
    }

    /// Check if filters have any active constraints
    public var isActive: Bool {
        domains?.isEmpty == false ||
        protocols?.isEmpty == false ||
        states?.isEmpty == false ||
        httpMethods?.isEmpty == false ||
        statusCodeRanges?.isEmpty == false ||
        minBytesTransferred != nil ||
        maxBytesTransferred != nil
    }
}

public enum StatusCodeRange: String, Codable, CaseIterable {
    case success = "2xx Success"
    case redirect = "3xx Redirect"
    case clientError = "4xx Client Error"
    case serverError = "5xx Server Error"

    public func contains(_ statusCode: Int) -> Bool {
        switch self {
        case .success: return (200...299).contains(statusCode)
        case .redirect: return (300...399).contains(statusCode)
        case .clientError: return (400...499).contains(statusCode)
        case .serverError: return (500...599).contains(statusCode)
        }
    }
}

// MARK: - Export Template

public enum ExportTemplate: String, Codable, CaseIterable, Identifiable {
    case full = "Full Details"
    case basic = "Basic Info"
    case performance = "Performance Metrics"
    case security = "Security Analysis"
    case custom = "Custom Fields"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .full:
            return "All available fields including metadata, timing, and performance data"
        case .basic:
            return "Essential fields: timestamp, host, protocol, status, data transferred"
        case .performance:
            return "Performance-focused: timing, data rates, latency, throughput"
        case .security:
            return "Security-focused: protocols, ports, status codes, errors"
        case .custom:
            return "User-defined custom field selection"
        }
    }

    /// Fields to include in the export
    public var fields: [ExportField] {
        switch self {
        case .full:
            return ExportField.allCases
        case .basic:
            return [.timestamp, .host, .port, .protocol, .state, .bytesReceived, .bytesSent, .totalBytes]
        case .performance:
            return [.timestamp, .host, .duration, .bytesReceived, .bytesSent, .totalBytes, .dataRate, .averageLatency]
        case .security:
            return [.timestamp, .host, .port, .protocol, .state, .requestMethod, .statusCode, .error]
        case .custom:
            return [] // User selects
        }
    }
}

// MARK: - Export Field

public enum ExportField: String, Codable, CaseIterable, Identifiable {
    // Connection info
    case id = "ID"
    case timestamp = "Timestamp"
    case host = "Host"
    case port = "Port"
    case address = "Address"
    case `protocol` = "Protocol"
    case state = "State"

    // Timing
    case startTime = "Start Time"
    case endTime = "End Time"
    case duration = "Duration"

    // Data transfer
    case bytesReceived = "Bytes Received"
    case bytesSent = "Bytes Sent"
    case totalBytes = "Total Bytes"
    case dataRate = "Data Rate"

    // Request/Response
    case requestURL = "Request URL"
    case requestMethod = "HTTP Method"
    case statusCode = "Status Code"
    case contentType = "Content Type"

    // Process info
    case processName = "Process Name"
    case processID = "Process ID"

    // Rule matching
    case matchedRuleID = "Matched Rule ID"
    case ruleAction = "Rule Action"

    // Performance
    case averageLatency = "Average Latency"

    // Error
    case error = "Error"

    public var id: String { rawValue }

    public var category: FieldCategory {
        switch self {
        case .id, .timestamp, .host, .port, .address, .`protocol`, .state:
            return .connection
        case .startTime, .endTime, .duration:
            return .timing
        case .bytesReceived, .bytesSent, .totalBytes, .dataRate:
            return .dataTransfer
        case .requestURL, .requestMethod, .statusCode, .contentType:
            return .httpDetails
        case .processName, .processID:
            return .process
        case .matchedRuleID, .ruleAction:
            return .ruleMatching
        case .averageLatency:
            return .performance
        case .error:
            return .error
        }
    }
}

public enum FieldCategory: String, CaseIterable {
    case connection = "Connection"
    case timing = "Timing"
    case dataTransfer = "Data Transfer"
    case httpDetails = "HTTP Details"
    case process = "Process"
    case ruleMatching = "Rule Matching"
    case performance = "Performance"
    case error = "Error"
}

// MARK: - Scheduled Export

public struct ScheduledExportConfiguration: Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var configuration: ExportConfiguration
    public var schedule: ExportSchedule
    public var destinationPath: String
    public var isEnabled: Bool
    public var lastExportDate: Date?
    public var nextExportDate: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        configuration: ExportConfiguration,
        schedule: ExportSchedule,
        destinationPath: String,
        isEnabled: Bool = true,
        lastExportDate: Date? = nil,
        nextExportDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.configuration = configuration
        self.schedule = schedule
        self.destinationPath = destinationPath
        self.isEnabled = isEnabled
        self.lastExportDate = lastExportDate
        self.nextExportDate = nextExportDate
    }
}

public enum ExportSchedule: Codable, Equatable {
    case daily(hour: Int) // 0-23
    case weekly(weekday: Int, hour: Int) // weekday: 1=Sunday, 7=Saturday
    case monthly(day: Int, hour: Int) // day: 1-28
    case custom(intervalSeconds: TimeInterval)

    public var displayName: String {
        switch self {
        case .daily(let hour):
            return "Daily at \(String(format: "%02d:00", hour))"
        case .weekly(let weekday, let hour):
            let weekdayName = Calendar.current.weekdaySymbols[weekday - 1]
            return "Weekly on \(weekdayName) at \(String(format: "%02d:00", hour))"
        case .monthly(let day, let hour):
            return "Monthly on day \(day) at \(String(format: "%02d:00", hour))"
        case .custom(let interval):
            let hours = Int(interval / 3600)
            return "Every \(hours) hours"
        }
    }
}
