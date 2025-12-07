import Foundation
import Combine
import OSLog

/// Service for tracking and managing proxy statistics
/// Provides real-time statistics updates and historical data aggregation
/// Thread-safe implementation for concurrent access
public protocol StatisticsServiceProtocol: AnyObject {
    // Publishers
    var statistics: AnyPublisher<Statistics, Never> { get}
    var sessionStats: AnyPublisher<SessionStatistics, Never> { get }

    // Connection tracking
    func recordConnection(_ connection: Connection) async
    func updateConnection(_ connection: Connection) async
    func removeConnection(id: UUID) async

    // Session management
    func resetSession() async
    func getStatistics() async -> Statistics

    // Queries
    func getTopDomains(limit: Int) async -> [(domain: String, stats: DomainStatistics)]
    func getTopProcesses(limit: Int) async -> [(process: String, stats: ProcessStatistics)]
    func getRuleStatistics(ruleID: UUID) async -> RuleStatistics?

    // Persistence
    func saveStatistics() async throws
    func loadStatistics() async throws
    func exportStatistics() async throws -> Data
    func clearAllStatistics() async throws
}

public final class StatisticsService: StatisticsServiceProtocol {
    // MARK: - Publishers

    private let statisticsSubject = CurrentValueSubject<Statistics, Never>(Statistics())
    private let sessionStatsSubject = CurrentValueSubject<SessionStatistics, Never>(SessionStatistics())

    public var statistics: AnyPublisher<Statistics, Never> {
        statisticsSubject.eraseToAnyPublisher()
    }

    public var sessionStats: AnyPublisher<SessionStatistics, Never> {
        sessionStatsSubject.eraseToAnyPublisher()
    }

    // MARK: - Properties

    private let logger: OSLog
    private let fileManager: FileManager
    private let storageURL: URL
    private let stateQueue = DispatchQueue(label: "com.swiftproxy.statsservice", qos: .utility)

    // Active connections tracking
    private var activeConnections: [UUID: Connection] = [:]

    // Auto-save timer
    private var autoSaveTimer: Timer?
    private let autoSaveInterval: TimeInterval = 60.0 // Save every minute

    // MARK: - Initialization

    public init(
        fileManager: FileManager = .default,
        logger: OSLog = Logger.storageLog
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

        self.storageURL = appSupport.appendingPathComponent("SwiftProxy/Statistics", isDirectory: true)

        try createStorageDirectoryIfNeeded()

        // Load persisted statistics
        Task {
            try? await loadStatistics()
            await setupAutoSave()
        }
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    // MARK: - Connection Tracking

    public func recordConnection(_ connection: Connection) async {
        await stateQueue.sync { [self] in
            await Task { @MainActor in
                // Track active connection
                self.activeConnections[connection.id] = connection

                // Update statistics
                var stats = self.statisticsSubject.value
                stats.recordConnection(connection)
                self.statisticsSubject.send(stats)

                // Update session stats
                let session = stats.session
                self.sessionStatsSubject.send(session)

                os_log(.debug, log: self.logger, "Recorded connection: %@", connection.id.uuidString)
            }.value
        }
    }

    public func updateConnection(_ connection: Connection) async {
        await stateQueue.sync { [self] in
            await Task { @MainActor in
                // Update active connection
                self.activeConnections[connection.id] = connection

                // Update statistics
                var stats = self.statisticsSubject.value
                stats.updateConnection(connection)
                self.statisticsSubject.send(stats)

                // Update session stats
                self.sessionStatsSubject.send(stats.session)

                // If connection is closed, remove from active connections
                if connection.state.isTerminalState {
                    self.activeConnections.removeValue(forKey: connection.id)
                }
            }.value
        }
    }

    public func removeConnection(id: UUID) async {
        await stateQueue.sync { [self] in
            await Task { @MainActor in
                self.activeConnections.removeValue(forKey: id)

                // Recalculate active connection count
                var stats = self.statisticsSubject.value
                stats.session.activeConnections = self.activeConnections.count
                self.statisticsSubject.send(stats)
                self.sessionStatsSubject.send(stats.session)
            }.value
        }
    }

    // MARK: - Session Management

    public func resetSession() async {
        os_log(.info, log: logger, "Resetting session statistics")

        await stateQueue.sync { [self] in
            await Task { @MainActor in
                var stats = self.statisticsSubject.value
                stats.resetSession()
                self.statisticsSubject.send(stats)
                self.sessionStatsSubject.send(stats.session)

                // Clear active connections
                self.activeConnections.removeAll()
            }.value
        }

        // Save after reset
        try? await saveStatistics()
    }

    public func getStatistics() async -> Statistics {
        statisticsSubject.value
    }

    // MARK: - Queries

    public func getTopDomains(limit: Int = 10) async -> [(domain: String, stats: DomainStatistics)] {
        await stateQueue.sync { [self] in
            await Task { @MainActor in
                self.statisticsSubject.value.topDomains(limit: limit)
            }.value
        }
    }

    public func getTopProcesses(limit: Int = 10) async -> [(process: String, stats: ProcessStatistics)] {
        await stateQueue.sync { [self] in
            await Task { @MainActor in
                self.statisticsSubject.value.topProcesses(limit: limit)
            }.value
        }
    }

    public func getRuleStatistics(ruleID: UUID) async -> RuleStatistics? {
        await stateQueue.sync { [self] in
            await Task { @MainActor in
                self.statisticsSubject.value.rules[ruleID]
            }.value
        }
    }

    // MARK: - Persistence

    public func saveStatistics() async throws {
        let stats = await getStatistics()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(stats)

        let fileURL = self.storageURL.appendingPathComponent("statistics.json")
        try data.write(to: fileURL, options: [.atomic])

        os_log(.debug, log: self.logger, "Statistics saved to disk")
    }

    public func loadStatistics() async throws {
        let fileURL = self.storageURL.appendingPathComponent("statistics.json")

        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            os_log(.info, log: self.logger, "No saved statistics found")
            return
        }

        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let stats = try decoder.decode(Statistics.self, from: data)

        await MainActor.run {
            self.statisticsSubject.send(stats)
            self.sessionStatsSubject.send(stats.session)
        }

        os_log(.info, log: self.logger, "Statistics loaded from disk")
    }

    public func exportStatistics() async throws -> Data {
        let stats = await getStatistics()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(stats)

        os_log(.info, log: logger, "Statistics exported")
        return data
    }

    public func clearAllStatistics() async throws {
        os_log(.default, log: logger, "Clearing all statistics")

        await stateQueue.sync { [self] in
            await Task { @MainActor in
                let newStats = Statistics()
                self.statisticsSubject.send(newStats)
                self.sessionStatsSubject.send(newStats.session)
                self.activeConnections.removeAll()
            }.value
        }

        try await saveStatistics()
    }

    // MARK: - Private Methods

    private func createStorageDirectoryIfNeeded() throws {
        if !fileManager.fileExists(atPath: storageURL.path) {
            try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
            os_log(.info, log: logger, "Created statistics storage directory")
        }
    }

    private func setupAutoSave() async {
        // Create a sendable-safe wrapper for the service reference
        final class ServiceBox: @unchecked Sendable {
            weak var service: StatisticsService?
            init(_ service: StatisticsService) {
                self.service = service
            }
        }

        let box = ServiceBox(self)

        await MainActor.run { [self] in
            self.autoSaveTimer = Timer.scheduledTimer(withTimeInterval: self.autoSaveInterval, repeats: true) { _ in
                Task {
                    try? await box.service?.saveStatistics()
                }
            }

            os_log(.debug, log: self.logger, "Auto-save enabled (interval: %.0f seconds)", self.autoSaveInterval)
        }
    }
}

// MARK: - Statistics Report Generator

extension StatisticsService {
    /// Generate a comprehensive statistics report
    public func generateReport() async -> StatisticsReport {
        let stats = await getStatistics()

        return StatisticsReport(
            generatedAt: Date(),
            session: stats.session,
            topDomains: stats.topDomains(limit: 10),
            topProcesses: stats.topProcesses(limit: 10),
            activeConnectionCount: activeConnections.count,
            totalConnectionCount: stats.session.connectionCount,
            totalBytesTransferred: stats.session.totalBytes,
            successRate: stats.session.successRate,
            uptime: stats.session.uptime
        )
    }
}

/// Formatted statistics report
public struct StatisticsReport: Codable {
    public let generatedAt: Date
    public let session: SessionStatistics
    public let topDomains: [(domain: String, stats: DomainStatistics)]
    public let topProcesses: [(process: String, stats: ProcessStatistics)]
    public let activeConnectionCount: Int
    public let totalConnectionCount: Int
    public let totalBytesTransferred: UInt64
    public let successRate: Double
    public let uptime: TimeInterval

    enum CodingKeys: String, CodingKey {
        case generatedAt, session, topDomains, topProcesses
        case activeConnectionCount, totalConnectionCount
        case totalBytesTransferred, successRate, uptime
    }

    public init(
        generatedAt: Date,
        session: SessionStatistics,
        topDomains: [(domain: String, stats: DomainStatistics)],
        topProcesses: [(process: String, stats: ProcessStatistics)],
        activeConnectionCount: Int,
        totalConnectionCount: Int,
        totalBytesTransferred: UInt64,
        successRate: Double,
        uptime: TimeInterval
    ) {
        self.generatedAt = generatedAt
        self.session = session
        self.topDomains = topDomains
        self.topProcesses = topProcesses
        self.activeConnectionCount = activeConnectionCount
        self.totalConnectionCount = totalConnectionCount
        self.totalBytesTransferred = totalBytesTransferred
        self.successRate = successRate
        self.uptime = uptime
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(session, forKey: .session)

        // Encode tuples as dictionaries
        let domainsDict = Dictionary(uniqueKeysWithValues: topDomains)
        try container.encode(domainsDict, forKey: .topDomains)

        let processesDict = Dictionary(uniqueKeysWithValues: topProcesses)
        try container.encode(processesDict, forKey: .topProcesses)

        try container.encode(activeConnectionCount, forKey: .activeConnectionCount)
        try container.encode(totalConnectionCount, forKey: .totalConnectionCount)
        try container.encode(totalBytesTransferred, forKey: .totalBytesTransferred)
        try container.encode(successRate, forKey: .successRate)
        try container.encode(uptime, forKey: .uptime)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        session = try container.decode(SessionStatistics.self, forKey: .session)

        let domainsDict = try container.decode([String: DomainStatistics].self, forKey: .topDomains)
        topDomains = domainsDict.map { ($0.key, $0.value) }

        let processesDict = try container.decode([String: ProcessStatistics].self, forKey: .topProcesses)
        topProcesses = processesDict.map { ($0.key, $0.value) }

        activeConnectionCount = try container.decode(Int.self, forKey: .activeConnectionCount)
        totalConnectionCount = try container.decode(Int.self, forKey: .totalConnectionCount)
        totalBytesTransferred = try container.decode(UInt64.self, forKey: .totalBytesTransferred)
        successRate = try container.decode(Double.self, forKey: .successRate)
        uptime = try container.decode(TimeInterval.self, forKey: .uptime)
    }

    /// Generate a formatted text report
    public func formattedText() -> String {
        var lines: [String] = []

        lines.append("SwiftProxy Statistics Report")
        lines.append("Generated: \(generatedAt.formatted())")
        lines.append("")

        lines.append("Session Summary:")
        lines.append("  Uptime: \(formatDuration(uptime))")
        lines.append("  Total Connections: \(totalConnectionCount)")
        lines.append("  Active Connections: \(activeConnectionCount)")
        lines.append("  Success Rate: \(formatPercentage(successRate))")
        lines.append("  Data Transferred: \(formatBytes(totalBytesTransferred))")
        lines.append("")

        if !topDomains.isEmpty {
            lines.append("Top Domains:")
            for (index, item) in topDomains.enumerated() {
                lines.append("  \(index + 1). \(item.domain)")
                lines.append("     Connections: \(item.stats.connectionCount)")
                lines.append("     Data: \(formatBytes(item.stats.totalBytes))")
            }
            lines.append("")
        }

        if !topProcesses.isEmpty {
            lines.append("Top Processes:")
            for (index, item) in topProcesses.enumerated() {
                lines.append("  \(index + 1). \(item.process)")
                lines.append("     Connections: \(item.stats.connectionCount)")
                lines.append("     Data: \(formatBytes(item.stats.totalBytes))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }

    private func formatPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }
}

// NOTE: DispatchQueue extension moved to Shared/Core/Utils/DispatchQueueExtensions.swift
