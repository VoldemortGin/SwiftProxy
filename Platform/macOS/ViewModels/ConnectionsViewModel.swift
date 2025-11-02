import Foundation
import SwiftProxyCore
import Combine
import SwiftUI
import OSLog

/// View model for managing and displaying active and historical connections
/// Provides filtering, sorting, and search functionality
@MainActor
public final class ConnectionsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var connections: [Connection] = []
    @Published public private(set) var filteredConnections: [Connection] = []
    @Published public private(set) var activeConnections: [Connection] = []
    @Published public private(set) var selectedConnection: Connection?
    @Published public var searchText: String = ""
    @Published public var filter: ConnectionFilter = .all
    @Published public var sortOrder: SortOrder = .startTimeDescending
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: AppError?

    // Statistics
    @Published public private(set) var activeConnectionCount: Int = 0
    @Published public private(set) var totalConnectionCount: Int = 0
    @Published public private(set) var totalBytesTransferred: UInt64 = 0

    // MARK: - Dependencies
    private let statisticsService: StatisticsServiceProtocol
    private let ruleService: RuleServiceProtocol
    private let logger: OSLog
    private var cancellables = Set<AnyCancellable>()

    // Connection storage
    private var allConnections: [UUID: Connection] = [:]
    private let maxStoredConnections = 10000 // Limit to prevent memory issues

    // MARK: - Initialization
    public init(
        statisticsService: StatisticsServiceProtocol,
        ruleService: RuleServiceProtocol,
        logger: OSLog = Logger.networkLog
    ) {
        self.statisticsService = statisticsService
        self.ruleService = ruleService
        self.logger = logger
        setupBindings()
        loadData()
    }

    // MARK: - Public Methods
    /// Add or update a connection
    public func updateConnection(_ connection: Connection) {
        allConnections[connection.id] = connection

        // Limit stored connections
        if allConnections.count > maxStoredConnections {
            pruneOldConnections()
        }

        // Update statistics service
        Task {
            if connection.state == .connecting {
                await statisticsService.recordConnection(connection)
            } else {
                await statisticsService.updateConnection(connection)
            }
        }

        refreshConnections()
        updateStatistics()
    }

    /// Remove a connection
    public func removeConnection(id: UUID) {
        allConnections.removeValue(forKey: id)
        Task {
            await statisticsService.removeConnection(id: id)
        }
        refreshConnections()
        updateStatistics()
    }

    /// Clear all connections
    public func clearAllConnections() {
        os_log(.info, log: logger, "Clearing all connections")
        allConnections.removeAll()
        refreshConnections()
        updateStatistics()
    }

    /// Clear completed connections
    public func clearCompletedConnections() {
        os_log(.info, log: logger, "Clearing completed connections")
        allConnections = allConnections.filter { !$0.value.state.isTerminalState }
        refreshConnections()
        updateStatistics()
    }

    /// Select a connection for detail view
    public func selectConnection(_ connection: Connection) {
        selectedConnection = connection
    }

    /// Deselect current connection
    public func deselectConnection() {
        selectedConnection = nil
    }

    /// Export connections to JSON
    public func exportConnections() async throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let connectionsArray = Array(allConnections.values).sorted()
        return try encoder.encode(connectionsArray)
    }

    /// Refresh connection list
    public func refresh() {
        refreshConnections()
        updateStatistics()
    }

    // MARK: - Private Methods
    private func setupBindings() {
        // Auto-refresh when search text or filter changes
        Publishers.CombineLatest3($searchText, $filter, $sortOrder)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.refreshConnections()
            }
            .store(in: &cancellables)
    }

    private func loadData() {
        isLoading = true
        // In a real implementation, we would load persisted connections
        // For now, we start with an empty state
        isLoading = false
    }

    private func refreshConnections() {
        let allConnectionsArray = Array(allConnections.values)

        // Apply filter
        let filtered = allConnectionsArray.filter { connection in
            // Apply custom filter
            guard connection.matches(filter: filter) else {
                return false
            }

            // Apply search text filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let matchesHost = connection.host.lowercased().contains(searchLower)
                let matchesProcess = connection.processName?.lowercased().contains(searchLower) ?? false
                let matchesURL = connection.requestURL?.absoluteString.lowercased().contains(searchLower) ?? false
                return matchesHost || matchesProcess || matchesURL
            }

            return true
        }

        // Apply sorting
        let sorted = sortConnections(filtered, by: sortOrder)

        connections = allConnectionsArray.sorted()
        filteredConnections = sorted
        activeConnections = allConnectionsArray.filter { $0.isActive }.sorted()
    }

    private func sortConnections(_ connections: [Connection], by order: SortOrder) -> [Connection] {
        switch order {
        case .startTimeAscending:
            return connections.sorted { $0.startTime < $1.startTime }
        case .startTimeDescending:
            return connections.sorted { $0.startTime > $1.startTime }
        case .bytesAscending:
            return connections.sorted { $0.totalBytes < $1.totalBytes }
        case .bytesDescending:
            return connections.sorted { $0.totalBytes > $1.totalBytes }
        case .hostAscending:
            return connections.sorted { $0.host < $1.host }
        case .hostDescending:
            return connections.sorted { $0.host > $1.host }
        case .durationAscending:
            return connections.sorted { $0.duration < $1.duration }
        case .durationDescending:
            return connections.sorted { $0.duration > $1.duration }
        }
    }

    private func updateStatistics() {
        let allConnectionsArray = Array(allConnections.values)
        activeConnectionCount = allConnectionsArray.filter { $0.isActive }.count
        totalConnectionCount = allConnectionsArray.count
        totalBytesTransferred = allConnectionsArray.reduce(0) { $0 + $1.totalBytes }
    }

    private func pruneOldConnections() {
        // Remove oldest completed connections to stay under limit
        let completedConnections = allConnections.values
            .filter { $0.state.isTerminalState }
            .sorted { $0.startTime < $1.startTime }

        let toRemove = completedConnections.count - (maxStoredConnections / 2)
        if toRemove > 0 {
            for connection in completedConnections.prefix(toRemove) {
                allConnections.removeValue(forKey: connection.id)
            }
            os_log(.info, log: logger, "Pruned %d old connections", toRemove)
        }
    }
}

// MARK: - Supporting Types
extension ConnectionsViewModel {
    public enum SortOrder: String, CaseIterable, Identifiable {
        case startTimeDescending = "Newest First"
        case startTimeAscending = "Oldest First"
        case bytesDescending = "Most Data"
        case bytesAscending = "Least Data"
        case hostAscending = "Host A-Z"
        case hostDescending = "Host Z-A"
        case durationDescending = "Longest Duration"
        case durationAscending = "Shortest Duration"

        public var id: String { rawValue }
    }
}

// MARK: - Computed Properties
extension ConnectionsViewModel {
    /// Format bytes for display
    public func formattedBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// Total bytes transferred (formatted)
    public var formattedTotalBytes: String {
        formattedBytes(totalBytesTransferred)
    }

    /// Whether there are any connections
    public var hasConnections: Bool {
        !connections.isEmpty
    }

    /// Whether there are filtered results
    public var hasFilteredConnections: Bool {
        !filteredConnections.isEmpty
    }

    /// Number of filtered connections
    public var filteredConnectionCount: Int {
        filteredConnections.count
    }
}

// MARK: - Filter Presets
extension ConnectionsViewModel {
    /// Apply active connections filter
    public func showActiveOnly() {
        filter = .activeOnly
    }

    /// Apply completed connections filter
    public func showCompletedOnly() {
        filter = .completedOnly
    }

    /// Show all connections
    public func showAll() {
        filter = .all
    }

    /// Filter by specific process
    public func filterByProcess(_ processName: String) {
        filter = ConnectionFilter(processName: processName)
    }

    /// Filter by specific host
    public func filterByHost(_ host: String) {
        filter = ConnectionFilter(host: host)
    }

    /// Filter by protocol
    public func filterByProtocol(_ protocol: ConnectionProtocol) {
        filter = ConnectionFilter(protocols: [`protocol`])
    }

    /// Filter by state
    public func filterByState(_ state: ConnectionState) {
        filter = ConnectionFilter(states: [state])
    }

    /// Filter by time range
    public func filterByTimeRange(start: Date, end: Date) {
        filter = ConnectionFilter(startDate: start, endDate: end)
    }
}

// MARK: - Batch Operations
extension ConnectionsViewModel {
    /// Get connections grouped by host
    public func connectionsByHost() -> [String: [Connection]] {
        Dictionary(grouping: filteredConnections) { $0.host }
    }

    /// Get connections grouped by process
    public func connectionsByProcess() -> [String: [Connection]] {
        Dictionary(grouping: filteredConnections) { $0.processName ?? "Unknown" }
    }

    /// Get connections grouped by protocol
    public func connectionsByProtocol() -> [ConnectionProtocol: [Connection]] {
        Dictionary(grouping: filteredConnections) { $0.protocol }
    }

    /// Get top hosts by connection count
    public func topHosts(limit: Int = 10) -> [(host: String, count: Int)] {
        let grouped = connectionsByHost()
        return grouped
            .map { (host: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }

    /// Get top processes by data transfer
    public func topProcesses(limit: Int = 10) -> [(process: String, bytes: UInt64)] {
        let grouped = connectionsByProcess()
        return grouped
            .map { (process: $0.key, bytes: $0.value.reduce(0) { $0 + $1.totalBytes }) }
            .sorted { $0.bytes > $1.bytes }
            .prefix(limit)
            .map { $0 }
    }
}
