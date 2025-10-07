import Foundation

/// Comprehensive statistics tracking for proxy operations
/// Includes real-time metrics and historical aggregations
public struct Statistics: Codable, Equatable {
    // MARK: - Properties

    /// Current session statistics
    public var session: SessionStatistics

    /// Historical statistics aggregated by time period
    public var historical: HistoricalStatistics

    /// Per-process statistics
    public var processes: [String: ProcessStatistics]

    /// Per-domain statistics
    public var domains: [String: DomainStatistics]

    /// Rule matching statistics
    public var rules: [UUID: RuleStatistics]

    /// Last updated timestamp
    public var lastUpdated: Date

    // MARK: - Initialization

    public init(
        session: SessionStatistics = SessionStatistics(),
        historical: HistoricalStatistics = HistoricalStatistics(),
        processes: [String: ProcessStatistics] = [:],
        domains: [String: DomainStatistics] = [:],
        rules: [UUID: RuleStatistics] = [:],
        lastUpdated: Date = Date()
    ) {
        self.session = session
        self.historical = historical
        self.processes = processes
        self.domains = domains
        self.rules = rules
        self.lastUpdated = lastUpdated
    }

    // MARK: - Methods

    /// Record a new connection
    public mutating func recordConnection(_ connection: Connection) {
        session.recordConnection(connection)
        lastUpdated = Date()

        // Update process statistics
        if let processName = connection.processName {
            var stats = processes[processName, default: ProcessStatistics(processName: processName)]
            stats.recordConnection(connection)
            processes[processName] = stats
        }

        // Update domain statistics
        var domainStats = domains[connection.host, default: DomainStatistics(domain: connection.host)]
        domainStats.recordConnection(connection)
        domains[connection.host] = domainStats

        // Update rule statistics
        if let ruleID = connection.matchedRuleID {
            var ruleStats = rules[ruleID, default: RuleStatistics(ruleID: ruleID)]
            ruleStats.recordConnection(connection)
            rules[ruleID] = ruleStats
        }
    }

    /// Update existing connection statistics
    public mutating func updateConnection(_ connection: Connection) {
        session.updateConnection(connection)
        lastUpdated = Date()

        // Update process statistics
        if let processName = connection.processName {
            processes[processName]?.updateConnection(connection)
        }

        // Update domain statistics
        domains[connection.host]?.updateConnection(connection)

        // Update rule statistics
        if let ruleID = connection.matchedRuleID {
            rules[ruleID]?.updateConnection(connection)
        }
    }

    /// Reset session statistics (keeps historical data)
    public mutating func resetSession() {
        // Archive current session to historical before resetting
        historical.archiveSession(session)
        session = SessionStatistics()
        lastUpdated = Date()
    }

    /// Clear all statistics
    public mutating func clearAll() {
        session = SessionStatistics()
        historical = HistoricalStatistics()
        processes.removeAll()
        domains.removeAll()
        rules.removeAll()
        lastUpdated = Date()
    }

    /// Get top domains by connection count
    public func topDomains(limit: Int = 10) -> [(domain: String, stats: DomainStatistics)] {
        domains
            .sorted { $0.value.connectionCount > $1.value.connectionCount }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    /// Get top processes by data transfer
    public func topProcesses(limit: Int = 10) -> [(process: String, stats: ProcessStatistics)] {
        processes
            .sorted { $0.value.totalBytes > $1.value.totalBytes }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
}

// MARK: - Session Statistics

/// Statistics for the current proxy session
public struct SessionStatistics: Codable, Equatable {
    public var startTime: Date
    public var connectionCount: Int
    public var activeConnections: Int
    public var successfulConnections: Int
    public var failedConnections: Int
    public var rejectedConnections: Int

    // Data transfer
    public var bytesReceived: UInt64
    public var bytesSent: UInt64
    public var totalBytes: UInt64 { bytesReceived + bytesSent }

    // Performance metrics
    public var averageConnectionDuration: TimeInterval
    public var averageDataRate: Double

    public init(
        startTime: Date = Date(),
        connectionCount: Int = 0,
        activeConnections: Int = 0,
        successfulConnections: Int = 0,
        failedConnections: Int = 0,
        rejectedConnections: Int = 0,
        bytesReceived: UInt64 = 0,
        bytesSent: UInt64 = 0,
        averageConnectionDuration: TimeInterval = 0,
        averageDataRate: Double = 0
    ) {
        self.startTime = startTime
        self.connectionCount = connectionCount
        self.activeConnections = activeConnections
        self.successfulConnections = successfulConnections
        self.failedConnections = failedConnections
        self.rejectedConnections = rejectedConnections
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.averageConnectionDuration = averageConnectionDuration
        self.averageDataRate = averageDataRate
    }

    public var uptime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    public var successRate: Double {
        guard connectionCount > 0 else { return 0 }
        return Double(successfulConnections) / Double(connectionCount)
    }

    mutating func recordConnection(_ connection: Connection) {
        connectionCount += 1

        if connection.isActive {
            activeConnections += 1
        }

        switch connection.state {
        case .closed:
            successfulConnections += 1
        case .failed:
            failedConnections += 1
        case .rejected:
            rejectedConnections += 1
        default:
            break
        }

        bytesReceived += connection.bytesReceived
        bytesSent += connection.bytesSent

        // Update averages
        updateAverages()
    }

    mutating func updateConnection(_ connection: Connection) {
        // This is called when an existing connection is updated
        // We need to recalculate based on all connections
        updateAverages()
    }

    private mutating func updateAverages() {
        // These would ideally be calculated from all tracked connections
        // For now, we'll keep them as running averages
        // In a real implementation, the statistics service would maintain connection history
    }
}

// MARK: - Historical Statistics

/// Aggregated historical statistics
public struct HistoricalStatistics: Codable, Equatable {
    public var dailyStats: [DailyStatistics]
    public var weeklyStats: [WeeklyStatistics]
    public var monthlyStats: [MonthlyStatistics]

    public init(
        dailyStats: [DailyStatistics] = [],
        weeklyStats: [WeeklyStatistics] = [],
        monthlyStats: [MonthlyStatistics] = []
    ) {
        self.dailyStats = dailyStats
        self.weeklyStats = weeklyStats
        self.monthlyStats = monthlyStats
    }

    mutating func archiveSession(_ session: SessionStatistics) {
        let today = Calendar.current.startOfDay(for: Date())

        // Update or create daily stats
        if let index = dailyStats.firstIndex(where: { $0.date == today }) {
            dailyStats[index].merge(session: session)
        } else {
            let dailyStat = DailyStatistics(date: today, session: session)
            dailyStats.append(dailyStat)
        }

        // Keep only last 90 days
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        dailyStats.removeAll { $0.date < ninetyDaysAgo }

        // Aggregate weekly and monthly stats
        aggregateWeeklyStats()
        aggregateMonthlyStats()
    }

    private mutating func aggregateWeeklyStats() {
        // Group daily stats by week and aggregate
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: dailyStats) { stat in
            calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: stat.date)
        }

        weeklyStats = grouped.map { _, stats in
            WeeklyStatistics(dailyStats: stats)
        }.sorted { $0.startDate > $1.startDate }

        // Keep only last 12 weeks
        weeklyStats = Array(weeklyStats.prefix(12))
    }

    private mutating func aggregateMonthlyStats() {
        // Group daily stats by month and aggregate
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: dailyStats) { stat in
            calendar.dateComponents([.year, .month], from: stat.date)
        }

        monthlyStats = grouped.map { _, stats in
            MonthlyStatistics(dailyStats: stats)
        }.sorted { $0.startDate > $1.startDate }

        // Keep only last 12 months
        monthlyStats = Array(monthlyStats.prefix(12))
    }
}

// MARK: - Time Period Statistics

public struct DailyStatistics: Codable, Equatable {
    public var date: Date
    public var connectionCount: Int
    public var bytesTransferred: UInt64
    public var successRate: Double

    init(date: Date, session: SessionStatistics) {
        self.date = date
        self.connectionCount = session.connectionCount
        self.bytesTransferred = session.totalBytes
        self.successRate = session.successRate
    }

    mutating func merge(session: SessionStatistics) {
        connectionCount += session.connectionCount
        bytesTransferred += session.totalBytes
        // Recalculate success rate as weighted average
        successRate = (successRate + session.successRate) / 2
    }
}

public struct WeeklyStatistics: Codable, Equatable {
    public var startDate: Date
    public var endDate: Date
    public var connectionCount: Int
    public var bytesTransferred: UInt64
    public var averageSuccessRate: Double

    init(dailyStats: [DailyStatistics]) {
        let sorted = dailyStats.sorted { $0.date < $1.date }
        self.startDate = sorted.first?.date ?? Date()
        self.endDate = sorted.last?.date ?? Date()
        self.connectionCount = dailyStats.reduce(0) { $0 + $1.connectionCount }
        self.bytesTransferred = dailyStats.reduce(0) { $0 + $1.bytesTransferred }
        self.averageSuccessRate = dailyStats.reduce(0.0) { $0 + $1.successRate } / Double(max(dailyStats.count, 1))
    }
}

public struct MonthlyStatistics: Codable, Equatable {
    public var startDate: Date
    public var endDate: Date
    public var connectionCount: Int
    public var bytesTransferred: UInt64
    public var averageSuccessRate: Double

    init(dailyStats: [DailyStatistics]) {
        let sorted = dailyStats.sorted { $0.date < $1.date }
        self.startDate = sorted.first?.date ?? Date()
        self.endDate = sorted.last?.date ?? Date()
        self.connectionCount = dailyStats.reduce(0) { $0 + $1.connectionCount }
        self.bytesTransferred = dailyStats.reduce(0) { $0 + $1.bytesTransferred }
        self.averageSuccessRate = dailyStats.reduce(0.0) { $0 + $1.successRate } / Double(max(dailyStats.count, 1))
    }
}

// MARK: - Process Statistics

public struct ProcessStatistics: Codable, Equatable {
    public var processName: String
    public var connectionCount: Int
    public var bytesReceived: UInt64
    public var bytesSent: UInt64
    public var totalBytes: UInt64 { bytesReceived + bytesSent }
    public var lastActive: Date

    public init(
        processName: String,
        connectionCount: Int = 0,
        bytesReceived: UInt64 = 0,
        bytesSent: UInt64 = 0,
        lastActive: Date = Date()
    ) {
        self.processName = processName
        self.connectionCount = connectionCount
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.lastActive = lastActive
    }

    mutating func recordConnection(_ connection: Connection) {
        connectionCount += 1
        bytesReceived += connection.bytesReceived
        bytesSent += connection.bytesSent
        lastActive = Date()
    }

    mutating func updateConnection(_ connection: Connection) {
        // Update would recalculate based on connection changes
        lastActive = Date()
    }
}

// MARK: - Domain Statistics

public struct DomainStatistics: Codable, Equatable {
    public var domain: String
    public var connectionCount: Int
    public var bytesReceived: UInt64
    public var bytesSent: UInt64
    public var totalBytes: UInt64 { bytesReceived + bytesSent }
    public var lastAccessed: Date
    public var averageResponseTime: TimeInterval

    public init(
        domain: String,
        connectionCount: Int = 0,
        bytesReceived: UInt64 = 0,
        bytesSent: UInt64 = 0,
        lastAccessed: Date = Date(),
        averageResponseTime: TimeInterval = 0
    ) {
        self.domain = domain
        self.connectionCount = connectionCount
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.lastAccessed = lastAccessed
        self.averageResponseTime = averageResponseTime
    }

    mutating func recordConnection(_ connection: Connection) {
        connectionCount += 1
        bytesReceived += connection.bytesReceived
        bytesSent += connection.bytesSent
        lastAccessed = Date()

        // Update average response time
        if connection.state.isTerminalState {
            let currentTotal = averageResponseTime * Double(connectionCount - 1)
            averageResponseTime = (currentTotal + connection.duration) / Double(connectionCount)
        }
    }

    mutating func updateConnection(_ connection: Connection) {
        lastAccessed = Date()
    }
}

// MARK: - Rule Statistics

public struct RuleStatistics: Codable, Equatable {
    public var ruleID: UUID
    public var matchCount: Int
    public var bytesTransferred: UInt64
    public var lastMatched: Date?

    public init(
        ruleID: UUID,
        matchCount: Int = 0,
        bytesTransferred: UInt64 = 0,
        lastMatched: Date? = nil
    ) {
        self.ruleID = ruleID
        self.matchCount = matchCount
        self.bytesTransferred = bytesTransferred
        self.lastMatched = lastMatched
    }

    mutating func recordConnection(_ connection: Connection) {
        matchCount += 1
        bytesTransferred += connection.totalBytes
        lastMatched = Date()
    }

    mutating func updateConnection(_ connection: Connection) {
        lastMatched = Date()
    }
}

// MARK: - Formatting Extensions

extension Statistics {
    public func formattedBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    public func formattedDataRate(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    public func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: duration) ?? "0s"
    }

    public func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }
}
