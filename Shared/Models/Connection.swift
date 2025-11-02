import Foundation

/// Represents an active or historical network connection through the proxy
/// Tracks connection state, data transfer, and timing information
public struct Connection: Identifiable, Codable, Equatable, Hashable {
    // MARK: - Properties

    public let id: UUID
    public var processName: String?
    public var processID: Int?
    public var host: String
    public var port: Int
    public var `protocol`: ConnectionProtocol
    public var state: ConnectionState

    // Timing information
    public var startTime: Date
    public var endTime: Date?
    public var duration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        }
        return Date().timeIntervalSince(startTime)
    }

    // Data transfer statistics
    public var bytesReceived: UInt64
    public var bytesSent: UInt64
    public var totalBytes: UInt64 {
        bytesReceived + bytesSent
    }

    // Request/Response metadata
    public var requestURL: URL?
    public var requestMethod: String?
    public var responseStatusCode: Int?
    public var contentType: String?

    // Rule matching
    public var matchedRuleID: UUID?
    public var ruleAction: RuleAction?

    // Error tracking
    public var error: String?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        processName: String? = nil,
        processID: Int? = nil,
        host: String,
        port: Int,
        protocol: ConnectionProtocol = .tcp,
        state: ConnectionState = .connecting,
        startTime: Date = Date(),
        endTime: Date? = nil,
        bytesReceived: UInt64 = 0,
        bytesSent: UInt64 = 0,
        requestURL: URL? = nil,
        requestMethod: String? = nil,
        responseStatusCode: Int? = nil,
        contentType: String? = nil,
        matchedRuleID: UUID? = nil,
        ruleAction: RuleAction? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.processName = processName
        self.processID = processID
        self.host = host
        self.port = port
        self.protocol = `protocol`  // Use backticks to escape Swift keyword
        self.state = state
        self.startTime = startTime
        self.endTime = endTime
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.requestURL = requestURL
        self.requestMethod = requestMethod
        self.responseStatusCode = responseStatusCode
        self.contentType = contentType
        self.matchedRuleID = matchedRuleID
        self.ruleAction = ruleAction
        self.error = error
    }

    // MARK: - Computed Properties

    /// Full address in format "host:port"
    public var address: String {
        "\(host):\(port)"
    }

    /// Human-readable connection status
    public var statusDescription: String {
        if let error = error {
            return "Error: \(error)"
        }
        return state.displayName
    }

    /// Average data transfer rate in bytes per second
    public var averageDataRate: Double {
        guard duration > 0 else { return 0 }
        return Double(totalBytes) / duration
    }

    /// Connection is currently active
    public var isActive: Bool {
        state == .connected || state == .connecting
    }

    // MARK: - Methods

    /// Update connection state
    public mutating func updateState(_ newState: ConnectionState) {
        state = newState

        if newState.isTerminalState {
            endTime = Date()
        }
    }

    /// Record data received
    public mutating func recordDataReceived(_ bytes: UInt64) {
        bytesReceived += bytes
    }

    /// Record data sent
    public mutating func recordDataSent(_ bytes: UInt64) {
        bytesSent += bytes
    }

    /// Mark connection as closed
    public mutating func close(error: String? = nil) {
        self.error = error
        endTime = Date()
        state = error != nil ? .failed : .closed
    }
}

// MARK: - Supporting Types

/// Connection protocol type
public enum ConnectionProtocol: String, Codable, CaseIterable {
    case tcp = "TCP"
    case udp = "UDP"
    case http = "HTTP"
    case https = "HTTPS"
    case websocket = "WebSocket"

    public var displayName: String {
        rawValue
    }

    public var systemImageName: String {
        switch self {
        case .tcp: return "network"
        case .udp: return "antenna.radiowaves.left.and.right"
        case .http: return "globe"
        case .https: return "lock.shield"
        case .websocket: return "arrow.left.arrow.right"
        }
    }
}

/// Connection lifecycle states
public enum ConnectionState: String, Codable, CaseIterable {
    case connecting = "Connecting"
    case connected = "Connected"
    case closing = "Closing"
    case closed = "Closed"
    case failed = "Failed"
    case rejected = "Rejected"

    public var displayName: String {
        rawValue
    }

    public var isTerminalState: Bool {
        switch self {
        case .closed, .failed, .rejected:
            return true
        case .connecting, .connected, .closing:
            return false
        }
    }

    public var systemImageName: String {
        switch self {
        case .connecting: return "arrow.clockwise"
        case .connected: return "checkmark.circle.fill"
        case .closing: return "arrow.down.circle"
        case .closed: return "circle"
        case .failed: return "exclamationmark.triangle.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }

    public var color: String {
        switch self {
        case .connecting: return "blue"
        case .connected: return "green"
        case .closing: return "orange"
        case .closed: return "gray"
        case .failed: return "red"
        case .rejected: return "red"
        }
    }
}

// MARK: - Formatting Extensions

extension Connection {
    /// Format bytes for display
    public func formattedBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// Format data rate for display
    public var formattedDataRate: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB]
        let bytesPerSecond = Int64(averageDataRate)
        return "\(formatter.string(fromByteCount: bytesPerSecond))/s"
    }

    /// Format duration for display
    public var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: duration) ?? "0s"
    }
}

// MARK: - Comparable

extension Connection: Comparable {
    /// Sort by start time, most recent first
    public static func < (lhs: Connection, rhs: Connection) -> Bool {
        lhs.startTime > rhs.startTime
    }
}

// MARK: - CustomStringConvertible

extension Connection: CustomStringConvertible {
    public var description: String {
        var parts = ["\(`protocol`.rawValue)://\(address)"]

        if let processName = processName {
            parts.append("[\(processName)]")
        }

        parts.append(state.displayName)

        if totalBytes > 0 {
            parts.append(formattedBytes(totalBytes))
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Filtering Helpers

extension Connection {
    /// Check if connection matches the given filter criteria
    public func matches(filter: ConnectionFilter) -> Bool {
        // Filter by state
        if let states = filter.states, !states.isEmpty {
            guard states.contains(state) else { return false }
        }

        // Filter by protocol
        if let protocols = filter.protocols, !protocols.isEmpty {
            guard protocols.contains(self.protocol) else { return false }
        }

        // Filter by process name
        if let processName = filter.processName, !processName.isEmpty {
            guard self.processName?.localizedCaseInsensitiveContains(processName) == true else {
                return false
            }
        }

        // Filter by host
        if let host = filter.host, !host.isEmpty {
            guard self.host.localizedCaseInsensitiveContains(host) else {
                return false
            }
        }

        // Filter by time range
        if let startDate = filter.startDate {
            guard startTime >= startDate else { return false }
        }

        if let endDate = filter.endDate {
            guard startTime <= endDate else { return false }
        }

        return true
    }
}

/// Filter criteria for connections
public struct ConnectionFilter: Codable, Equatable {
    public var states: Set<ConnectionState>?
    public var protocols: Set<ConnectionProtocol>?
    public var processName: String?
    public var host: String?
    public var startDate: Date?
    public var endDate: Date?

    public init(
        states: Set<ConnectionState>? = nil,
        protocols: Set<ConnectionProtocol>? = nil,
        processName: String? = nil,
        host: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.states = states
        self.protocols = protocols
        self.processName = processName
        self.host = host
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Empty filter that matches all connections
    public static var all: ConnectionFilter {
        ConnectionFilter()
    }

    /// Filter for active connections only
    public static var activeOnly: ConnectionFilter {
        ConnectionFilter(states: [.connecting, .connected])
    }

    /// Filter for completed connections only
    public static var completedOnly: ConnectionFilter {
        ConnectionFilter(states: [.closed, .failed, .rejected])
    }
}
