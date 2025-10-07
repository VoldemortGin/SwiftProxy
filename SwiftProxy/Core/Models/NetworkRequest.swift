import Foundation

/// Represents a single network request captured by the proxy system
/// This is the core data model for network monitoring and traffic analysis
public struct NetworkRequest: Identifiable, Codable, Equatable {
    // MARK: - Properties

    public let id: UUID
    public let timestamp: Date
    public let method: HTTPMethod
    public let url: URL
    public let host: String
    public let path: String

    // Request details
    public var headers: [String: String]
    public var requestBody: Data?
    public var requestSize: Int64

    // Response details
    public var statusCode: Int?
    public var responseHeaders: [String: String]?
    public var responseBody: Data?
    public var responseSize: Int64

    // Performance metrics
    public var latency: TimeInterval?
    public var startTime: Date
    public var endTime: Date?

    // Proxy information
    public var proxyType: ProxyType
    public var matchedRule: ProxyRule?
    public var ruleAction: RuleAction?

    // Connection details
    public var processName: String?
    public var processID: Int?
    public var connectionID: UUID

    // Status
    public var status: RequestStatus
    public var error: String?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        method: HTTPMethod,
        url: URL,
        headers: [String: String] = [:],
        processName: String? = nil,
        processID: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.url = url
        self.host = url.host ?? ""
        self.path = url.path
        self.headers = headers
        self.requestBody = nil
        self.requestSize = 0
        self.responseHeaders = nil
        self.responseBody = nil
        self.responseSize = 0
        self.latency = nil
        self.startTime = timestamp
        self.endTime = nil
        self.proxyType = .direct
        self.matchedRule = nil
        self.ruleAction = nil
        self.processName = processName
        self.processID = processID
        self.connectionID = UUID()
        self.status = .pending
        self.error = nil
    }

    // MARK: - Computed Properties

    /// Total size of request and response in bytes
    public var totalSize: Int64 {
        requestSize + responseSize
    }

    /// Whether the request was successful (2xx status code)
    public var isSuccessful: Bool {
        guard let code = statusCode else { return false }
        return (200...299).contains(code)
    }

    /// Whether the request went through a proxy
    public var isProxied: Bool {
        proxyType != .direct
    }

    /// Duration of the request in milliseconds
    public var durationMs: Int? {
        guard let latency = latency else { return nil }
        return Int(latency * 1000)
    }

    // MARK: - Methods

    /// Update request with response data
    public mutating func completeWithResponse(
        statusCode: Int,
        headers: [String: String],
        body: Data?,
        responseSize: Int64
    ) {
        self.statusCode = statusCode
        self.responseHeaders = headers
        self.responseBody = body
        self.responseSize = responseSize
        self.endTime = Date()
        self.latency = endTime!.timeIntervalSince(startTime)
        self.status = isSuccessful ? .completed : .failed
    }

    /// Mark request as failed with error
    public mutating func failWithError(_ error: String) {
        self.error = error
        self.status = .failed
        self.endTime = Date()
        self.latency = endTime!.timeIntervalSince(startTime)
    }

    /// Apply a proxy rule to this request
    public mutating func applyRule(_ rule: ProxyRule, action: RuleAction) {
        self.matchedRule = rule
        self.ruleAction = action

        switch action {
        case .direct:
            self.proxyType = .direct
        case .proxy:
            self.proxyType = .proxy
        case .reject:
            self.status = .rejected
        }
    }
}

// MARK: - Supporting Types

public enum HTTPMethod: String, Codable, CaseIterable {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH
    case HEAD
    case OPTIONS
    case CONNECT
    case TRACE
}

public enum ProxyType: String, Codable {
    case direct = "DIRECT"
    case proxy = "PROXY"
    case socks5 = "SOCKS5"
    case http = "HTTP"
    case https = "HTTPS"
}

public enum RequestStatus: String, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case rejected = "rejected"
    case timeout = "timeout"

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .rejected, .timeout:
            return true
        case .pending, .inProgress:
            return false
        }
    }
}

// MARK: - Extensions

extension NetworkRequest: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension NetworkRequest: CustomStringConvertible {
    public var description: String {
        let statusStr = statusCode.map { String($0) } ?? "N/A"
        let latencyStr = durationMs.map { "\($0)ms" } ?? "N/A"
        return "\(method.rawValue) \(url.absoluteString) - \(statusStr) [\(latencyStr)]"
    }
}

// MARK: - Traffic Statistics

/// Aggregated statistics for network traffic
public struct TrafficStatistics: Codable, Equatable {
    public var totalRequests: Int
    public var successfulRequests: Int
    public var failedRequests: Int
    public var rejectedRequests: Int

    public var totalBytesIn: Int64
    public var totalBytesOut: Int64

    public var averageLatency: TimeInterval
    public var minLatency: TimeInterval
    public var maxLatency: TimeInterval

    public var requestsByMethod: [HTTPMethod: Int]
    public var requestsByStatus: [Int: Int]
    public var requestsByHost: [String: Int]

    public var startTime: Date
    public var endTime: Date

    public init() {
        self.totalRequests = 0
        self.successfulRequests = 0
        self.failedRequests = 0
        self.rejectedRequests = 0
        self.totalBytesIn = 0
        self.totalBytesOut = 0
        self.averageLatency = 0
        self.minLatency = .infinity
        self.maxLatency = 0
        self.requestsByMethod = [:]
        self.requestsByStatus = [:]
        self.requestsByHost = [:]
        self.startTime = Date()
        self.endTime = Date()
    }

    /// Update statistics with a new request
    public mutating func update(with request: NetworkRequest) {
        totalRequests += 1

        switch request.status {
        case .completed:
            successfulRequests += 1
        case .failed, .timeout:
            failedRequests += 1
        case .rejected:
            rejectedRequests += 1
        default:
            break
        }

        totalBytesIn += request.responseSize
        totalBytesOut += request.requestSize

        if let latency = request.latency {
            let totalLatency = averageLatency * Double(totalRequests - 1)
            averageLatency = (totalLatency + latency) / Double(totalRequests)
            minLatency = min(minLatency, latency)
            maxLatency = max(maxLatency, latency)
        }

        requestsByMethod[request.method, default: 0] += 1

        if let status = request.statusCode {
            requestsByStatus[status, default: 0] += 1
        }

        requestsByHost[request.host, default: 0] += 1
        endTime = Date()
    }
}

/// Domain-specific statistics
public struct DomainStats: Identifiable, Codable {
    public let id: UUID
    public let domain: String
    public var requestCount: Int
    public var bytesIn: Int64
    public var bytesOut: Int64
    public var averageLatency: TimeInterval
    public var lastAccessed: Date

    public init(domain: String) {
        self.id = UUID()
        self.domain = domain
        self.requestCount = 0
        self.bytesIn = 0
        self.bytesOut = 0
        self.averageLatency = 0
        self.lastAccessed = Date()
    }
}

/// Hourly traffic aggregation
public struct HourlyTraffic: Identifiable, Codable {
    public let id: UUID
    public let hour: Date
    public var requests: Int
    public var bytesIn: Int64
    public var bytesOut: Int64

    public init(hour: Date) {
        self.id = UUID()
        self.hour = hour
        self.requests = 0
        self.bytesIn = 0
        self.bytesOut = 0
    }
}
