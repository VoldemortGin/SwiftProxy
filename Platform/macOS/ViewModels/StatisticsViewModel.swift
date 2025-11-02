import Foundation
import SwiftProxyCore
import Combine
import SwiftUI
import OSLog

/// View model for statistics display and analysis
/// Provides formatted statistics data and charting support
@MainActor
public final class StatisticsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var statistics: Statistics = Statistics()
    @Published public private(set) var sessionStats: SessionStatistics = SessionStatistics()
    @Published public private(set) var topDomains: [(domain: String, stats: DomainStatistics)] = []
    @Published public private(set) var topProcesses: [(process: String, stats: ProcessStatistics)] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: AppError?
    @Published public var selectedTimePeriod: TimePeriod = .session
    @Published public var chartDataType: ChartDataType = .connections

    // MARK: - Dependencies
    private let statisticsService: StatisticsServiceProtocol
    private let logger: OSLog
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    // MARK: - Initialization
    public init(
        statisticsService: StatisticsServiceProtocol,
        logger: OSLog = Logger.storageLog
    ) {
        self.statisticsService = statisticsService
        self.logger = logger
        setupBindings()
        loadData()
        startAutoRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Public Methods
    /// Reset session statistics
    public func resetSession() async {
        os_log(.info, log: logger, "Resetting session statistics")
        await statisticsService.resetSession()
        // Reload data
        await loadStatistics()
    }

    /// Clear all statistics
    public func clearAll() async {
        os_log(.warning, log: logger, "Clearing all statistics")
        isLoading = true
        do {
            try await statisticsService.clearAllStatistics()
            await loadStatistics()
        } catch let appError as AppError {
            error = appError
        } catch {
            error = .unknown(error)
        }
        isLoading = false
    }

    /// Export statistics
    public func exportStatistics() async -> Data? {
        do {
            return try await statisticsService.exportStatistics()
        } catch {
            os_log(.error, log: logger, "Failed to export statistics: %@", error.localizedDescription)
            self.error = .dataEncodingFailed
            return nil
        }
    }

    /// Generate statistics report
    public func generateReport() async -> StatisticsReport? {
        // This would typically be provided by a service
        // For now, we'll create it from current statistics
        return StatisticsReport(
            generatedAt: Date(),
            session: sessionStats,
            topDomains: topDomains,
            topProcesses: topProcesses,
            activeConnectionCount: sessionStats.activeConnections,
            totalConnectionCount: sessionStats.connectionCount,
            totalBytesTransferred: sessionStats.totalBytes,
            successRate: sessionStats.successRate,
            uptime: sessionStats.uptime
        )
    }

    /// Refresh all statistics
    public func refresh() async {
        await loadStatistics()
    }

    // MARK: - Private Methods
    private func setupBindings() {
        // Bind statistics service
        statisticsService.statistics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.statistics = stats
                self?.updateDerivedData()
            }
            .store(in: &cancellables)

        statisticsService.sessionStats
            .assign(to: &$sessionStats)

        // Auto-update when time period or chart type changes
        Publishers.CombineLatest($selectedTimePeriod, $chartDataType)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.loadData()
            }
            .store(in: &cancellables)
    }

    private func loadData() {
        Task {
            await loadStatistics()
        }
    }

    private func loadStatistics() async {
        let stats = await statisticsService.getStatistics()
        statistics = stats
        sessionStats = stats.session

        // Load top domains and processes
        topDomains = await statisticsService.getTopDomains(limit: 10)
        topProcesses = await statisticsService.getTopProcesses(limit: 10)

        updateDerivedData()
    }

    private func updateDerivedData() {
        topDomains = statistics.topDomains(limit: 10)
        topProcesses = statistics.topProcesses(limit: 10)
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.loadStatistics()
            }
        }
    }
}

// MARK: - Supporting Types
extension StatisticsViewModel {
    public enum TimePeriod: String, CaseIterable, Identifiable {
        case session = "Session"
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"

        public var id: String { rawValue }
    }

    public enum ChartDataType: String, CaseIterable, Identifiable {
        case connections = "Connections"
        case dataTransfer = "Data Transfer"
        case successRate = "Success Rate"

        public var id: String { rawValue }
    }
}

// MARK: - Formatted Properties
extension StatisticsViewModel {
    /// Format bytes for display
    public func formattedBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// Format data rate for display
    public func formattedDataRate(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    /// Format duration for display
    public func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: duration) ?? "0s"
    }

    /// Format percentage for display
    public func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }

    /// Formatted session uptime
    public var formattedUptime: String {
        formattedDuration(sessionStats.uptime)
    }

    /// Formatted total bytes
    public var formattedTotalBytes: String {
        formattedBytes(sessionStats.totalBytes)
    }

    /// Formatted success rate
    public var formattedSuccessRate: String {
        formattedPercentage(sessionStats.successRate)
    }

    /// Formatted average connection duration
    public var formattedAvgDuration: String {
        formattedDuration(sessionStats.averageConnectionDuration)
    }

    /// Formatted average data rate
    public var formattedAvgDataRate: String {
        formattedDataRate(sessionStats.averageDataRate)
    }
}

// MARK: - Chart Data
extension StatisticsViewModel {
    /// Get chart data for the selected period and type
    public func getChartData() -> [ChartDataPoint] {
        switch selectedTimePeriod {
        case .session:
            return getSessionChartData()
        case .day:
            return getDailyChartData()
        case .week:
            return getWeeklyChartData()
        case .month:
            return getMonthlyChartData()
        case .all:
            return getAllTimeChartData()
        }
    }

    private func getSessionChartData() -> [ChartDataPoint] {
        // For session, we show current stats as a single point
        let value: Double
        switch chartDataType {
        case .connections:
            value = Double(sessionStats.connectionCount)
        case .dataTransfer:
            value = Double(sessionStats.totalBytes)
        case .successRate:
            value = sessionStats.successRate * 100
        }

        return [ChartDataPoint(date: sessionStats.startTime, value: value)]
    }

    private func getDailyChartData() -> [ChartDataPoint] {
        let dailyStats = statistics.historical.dailyStats
            .filter { Calendar.current.isDateInToday($0.date) }

        return dailyStats.map { stat in
            let value: Double
            switch chartDataType {
            case .connections:
                value = Double(stat.connectionCount)
            case .dataTransfer:
                value = Double(stat.bytesTransferred)
            case .successRate:
                value = stat.successRate * 100
            }
            return ChartDataPoint(date: stat.date, value: value)
        }
    }

    private func getWeeklyChartData() -> [ChartDataPoint] {
        // Get last 7 days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        let weekStats = statistics.historical.dailyStats
            .filter { $0.date >= weekAgo }
            .sorted { $0.date < $1.date }

        return weekStats.map { stat in
            let value: Double
            switch chartDataType {
            case .connections:
                value = Double(stat.connectionCount)
            case .dataTransfer:
                value = Double(stat.bytesTransferred)
            case .successRate:
                value = stat.successRate * 100
            }
            return ChartDataPoint(date: stat.date, value: value)
        }
    }

    private func getMonthlyChartData() -> [ChartDataPoint] {
        // Get last 30 days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: today)!

        let monthStats = statistics.historical.dailyStats
            .filter { $0.date >= monthAgo }
            .sorted { $0.date < $1.date }

        return monthStats.map { stat in
            let value: Double
            switch chartDataType {
            case .connections:
                value = Double(stat.connectionCount)
            case .dataTransfer:
                value = Double(stat.bytesTransferred)
            case .successRate:
                value = stat.successRate * 100
            }
            return ChartDataPoint(date: stat.date, value: value)
        }
    }

    private func getAllTimeChartData() -> [ChartDataPoint] {
        let allStats = statistics.historical.dailyStats.sorted { $0.date < $1.date }

        return allStats.map { stat in
            let value: Double
            switch chartDataType {
            case .connections:
                value = Double(stat.connectionCount)
            case .dataTransfer:
                value = Double(stat.bytesTransferred)
            case .successRate:
                value = stat.successRate * 100
            }
            return ChartDataPoint(date: stat.date, value: value)
        }
    }

    /// Get a summary of key metrics
    public var summary: StatisticsSummary {
        StatisticsSummary(
            totalConnections: sessionStats.connectionCount,
            activeConnections: sessionStats.activeConnections,
            successfulConnections: sessionStats.successfulConnections,
            failedConnections: sessionStats.failedConnections,
            totalBytesReceived: sessionStats.bytesReceived,
            totalBytesSent: sessionStats.bytesSent,
            successRate: sessionStats.successRate,
            uptime: sessionStats.uptime,
            averageConnectionDuration: sessionStats.averageConnectionDuration,
            averageDataRate: sessionStats.averageDataRate
        )
    }
}

/// Data point for charting
public struct ChartDataPoint: Identifiable {
    public let id = UUID()
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// Summary statistics for overview
public struct StatisticsSummary {
    public let totalConnections: Int
    public let activeConnections: Int
    public let successfulConnections: Int
    public let failedConnections: Int
    public let totalBytesReceived: UInt64
    public let totalBytesSent: UInt64
    public let successRate: Double
    public let uptime: TimeInterval
    public let averageConnectionDuration: TimeInterval
    public let averageDataRate: Double

    public var totalBytes: UInt64 {
        totalBytesReceived + totalBytesSent
    }
}
