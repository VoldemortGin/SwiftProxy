import Foundation
import OSLog

// MARK: - Buffer Pool

/// High-performance buffer pool for reducing memory allocations
/// Uses object pooling pattern to reuse Data buffers
public actor BufferPool {
    // MARK: - Properties

    private let bufferSize: Int
    private let maxPoolSize: Int
    private var availableBuffers: [Data] = []
    private var allocatedCount: Int = 0

    private let logger: OSLog

    // Statistics
    private var hits: Int = 0
    private var misses: Int = 0

    // MARK: - Initialization

    public init(
        bufferSize: Int = 65536, // 64KB default
        maxPoolSize: Int = 100,
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "BufferPool")
    ) {
        self.bufferSize = bufferSize
        self.maxPoolSize = maxPoolSize
        self.logger = logger
    }

    // MARK: - Buffer Management

    /// Acquire a buffer from the pool
    public func acquire() -> Data {
        if let buffer = availableBuffers.popLast() {
            hits += 1
            return buffer
        }

        misses += 1
        allocatedCount += 1

        if allocatedCount > maxPoolSize {
            os_log(.default, log: logger, "Buffer pool exceeded max size: %d", allocatedCount)
        }

        return Data(count: bufferSize)
    }

    /// Release a buffer back to the pool
    public func release(_ buffer: Data) {
        guard availableBuffers.count < maxPoolSize else {
            // Pool is full, let buffer be deallocated
            allocatedCount -= 1
            return
        }

        // Reset buffer and return to pool
        var mutableBuffer = buffer
        mutableBuffer.resetBytes(in: 0..<buffer.count)
        availableBuffers.append(mutableBuffer)
    }

    /// Get pool statistics
    public func getStatistics() -> BufferPoolStatistics {
        BufferPoolStatistics(
            bufferSize: bufferSize,
            availableCount: availableBuffers.count,
            allocatedCount: allocatedCount,
            hits: hits,
            misses: misses,
            hitRate: Double(hits) / Double(hits + misses)
        )
    }

    /// Clear all pooled buffers
    public func clear() {
        availableBuffers.removeAll()
        allocatedCount = 0
        hits = 0
        misses = 0
    }
}

public struct BufferPoolStatistics {
    public let bufferSize: Int
    public let availableCount: Int
    public let allocatedCount: Int
    public let hits: Int
    public let misses: Int
    public let hitRate: Double
}

// MARK: - Rate Limiter

/// Token bucket rate limiter for controlling request rates
public actor RateLimiter {
    // MARK: - Properties

    private let capacity: Int
    private let refillRate: Double // tokens per second
    private var availableTokens: Double
    private var lastRefillTime: Date

    private let logger: OSLog

    // MARK: - Initialization

    public init(
        capacity: Int = 100,
        refillRate: Double = 10.0,
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "RateLimiter")
    ) {
        self.capacity = capacity
        self.refillRate = refillRate
        self.availableTokens = Double(capacity)
        self.lastRefillTime = Date()
        self.logger = logger
    }

    // MARK: - Rate Limiting

    /// Check if request is allowed under rate limit
    public func checkRateLimit(tokens: Int = 1) async -> Bool {
        await refillTokens()

        guard availableTokens >= Double(tokens) else {
            os_log(.debug, log: logger, "Rate limit exceeded, available: %f, needed: %d", availableTokens, tokens)
            return false
        }

        availableTokens -= Double(tokens)
        return true
    }

    /// Wait until tokens are available (blocking)
    public func waitForTokens(tokens: Int = 1) async throws {
        while !(await checkRateLimit(tokens: tokens)) {
            let waitTime = calculateWaitTime(tokens: tokens)
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
    }

    // MARK: - Private Methods

    private func refillTokens() {
        let now = Date()
        let timePassed = now.timeIntervalSince(lastRefillTime)
        let tokensToAdd = timePassed * refillRate

        availableTokens = min(Double(capacity), availableTokens + tokensToAdd)
        lastRefillTime = now
    }

    private func calculateWaitTime(tokens: Int) -> TimeInterval {
        let tokensNeeded = Double(tokens) - availableTokens
        return tokensNeeded / refillRate
    }

    /// Reset rate limiter
    public func reset() {
        availableTokens = Double(capacity)
        lastRefillTime = Date()
    }
}

// MARK: - Memory Pressure Handler

/// Monitors system memory pressure and triggers cleanup actions
public class MemoryPressureHandler {
    // MARK: - Properties

    private var source: (any DispatchSourceMemoryPressure)?
    private let logger: OSLog
    private var cleanupHandlers: [(MemoryPressureLevel) -> Void] = []

    public enum MemoryPressureLevel {
        case normal
        case warning
        case critical
    }

    // MARK: - Initialization

    public init(logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "MemoryPressure")) {
        self.logger = logger
    }

    // MARK: - Monitoring

    public func startMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }

            let event = source.data
            let level: MemoryPressureLevel

            if event.contains(.critical) {
                level = .critical
                os_log(.fault, log: self.logger, "Critical memory pressure detected")
            } else if event.contains(.warning) {
                level = .warning
                os_log(.default, log: self.logger, "Memory pressure warning")
            } else {
                level = .normal
            }

            self.handleMemoryPressure(level: level)
        }

        source.resume()
        self.source = source

        os_log(.info, log: logger, "Memory pressure monitoring started")
    }

    public func stopMonitoring() {
        source?.cancel()
        source = nil
        os_log(.info, log: logger, "Memory pressure monitoring stopped")
    }

    // MARK: - Cleanup Handlers

    public func addCleanupHandler(_ handler: @escaping (MemoryPressureLevel) -> Void) {
        cleanupHandlers.append(handler)
    }

    private func handleMemoryPressure(level: MemoryPressureLevel) {
        os_log(.info, log: logger, "Handling memory pressure: %{public}@", String(describing: level))

        for handler in cleanupHandlers {
            handler(level)
        }
    }
}

// MARK: - Statistics Batcher

/// Batches statistics updates to reduce overhead
public actor StatisticsBatcher {
    // MARK: - Properties

    private var pendingUpdates: [StatisticsUpdate] = []
    private var flushTimer: Task<Void, Never>?
    private let flushInterval: TimeInterval
    private let batchSize: Int

    private let onFlush: ([StatisticsUpdate]) async -> Void
    private let logger: OSLog

    // MARK: - Initialization

    public init(
        flushInterval: TimeInterval = 1.0,
        batchSize: Int = 100,
        onFlush: @escaping ([StatisticsUpdate]) async -> Void,
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "StatisticsBatcher")
    ) {
        self.flushInterval = flushInterval
        self.batchSize = batchSize
        self.onFlush = onFlush
        self.logger = logger

        // Use nonisolated wrapper to avoid calling actor-isolated method from init
        initializeFlushTimer()
    }

    /// Nonisolated wrapper to start flush timer asynchronously
    nonisolated private func initializeFlushTimer() {
        Task { await startFlushTimer() }
    }

    // MARK: - Update Management

    public func queue(_ update: StatisticsUpdate) {
        pendingUpdates.append(update)

        if pendingUpdates.count >= batchSize {
            Task { await flush() }
        }
    }

    public func flush() async {
        guard !pendingUpdates.isEmpty else { return }

        let updates = pendingUpdates
        pendingUpdates.removeAll()

        os_log(.debug, log: logger, "Flushing %d statistics updates", updates.count)
        await onFlush(updates)
    }

    // MARK: - Timer Management

    private func startFlushTimer() {
        flushTimer?.cancel()

        flushTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
                await flush()
            }
        }
    }

    deinit {
        flushTimer?.cancel()
    }
}

public struct StatisticsUpdate {
    public let connectionID: UUID
    public let bytesReceived: Int64
    public let bytesSent: Int64
    public let timestamp: Date

    public init(connectionID: UUID, bytesReceived: Int64, bytesSent: Int64, timestamp: Date = Date()) {
        self.connectionID = connectionID
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.timestamp = timestamp
    }
}

// MARK: - Cache with LRU Eviction

/// Simple LRU cache for frequently accessed data
public actor LRUCache<Key: Hashable, Value> {
    // MARK: - Properties

    private struct CacheEntry {
        let value: Value
        var lastAccessed: Date
    }

    private var cache: [Key: CacheEntry] = [:]
    private let maxSize: Int
    private let ttl: TimeInterval?

    private var hits: Int = 0
    private var misses: Int = 0

    // MARK: - Initialization

    public init(maxSize: Int = 1000, ttl: TimeInterval? = nil) {
        self.maxSize = maxSize
        self.ttl = ttl
    }

    // MARK: - Cache Operations

    public func get(_ key: Key) -> Value? {
        guard var entry = cache[key] else {
            misses += 1
            return nil
        }

        // Check TTL
        if let ttl = ttl, Date().timeIntervalSince(entry.lastAccessed) > ttl {
            cache.removeValue(forKey: key)
            misses += 1
            return nil
        }

        // Update last accessed
        entry.lastAccessed = Date()
        cache[key] = entry

        hits += 1
        return entry.value
    }

    public func set(_ key: Key, value: Value) {
        // Evict if at capacity
        if cache.count >= maxSize && cache[key] == nil {
            evictLRU()
        }

        cache[key] = CacheEntry(value: value, lastAccessed: Date())
    }

    public func remove(_ key: Key) {
        cache.removeValue(forKey: key)
    }

    public func clear() {
        cache.removeAll()
        hits = 0
        misses = 0
    }

    // MARK: - Statistics

    public func getStatistics() -> CacheStatistics {
        CacheStatistics(
            size: cache.count,
            maxSize: maxSize,
            hits: hits,
            misses: misses,
            hitRate: Double(hits) / Double(hits + misses)
        )
    }

    // MARK: - Private Methods

    private func evictLRU() {
        guard let oldestKey = cache.min(by: { $0.value.lastAccessed < $1.value.lastAccessed })?.key else {
            return
        }

        cache.removeValue(forKey: oldestKey)
    }
}

public struct CacheStatistics {
    public let size: Int
    public let maxSize: Int
    public let hits: Int
    public let misses: Int
    public let hitRate: Double
}

// MARK: - Performance Metrics Collector

/// Collects and aggregates performance metrics
public actor PerformanceMetricsCollector {
    // MARK: - Properties

    private var metrics: [String: MetricData] = [:]
    private let logger: OSLog

    // MARK: - Initialization

    public init(logger: OSLog = Logger.performanceLog) {
        self.logger = logger
    }

    // MARK: - Metric Recording

    public func recordDuration(_ name: String, duration: TimeInterval) {
        var data = metrics[name, default: MetricData(name: name)]
        data.recordValue(duration)
        metrics[name] = data
    }

    public func recordValue(_ name: String, value: Double) {
        var data = metrics[name, default: MetricData(name: name)]
        data.recordValue(value)
        metrics[name] = data
    }

    public func increment(_ name: String, by value: Int = 1) {
        var data = metrics[name, default: MetricData(name: name)]
        data.recordValue(Double(value))
        metrics[name] = data
    }

    // MARK: - Metric Retrieval

    public func getMetric(_ name: String) -> MetricData? {
        metrics[name]
    }

    public func getAllMetrics() -> [String: MetricData] {
        metrics
    }

    public func reset() {
        metrics.removeAll()
    }

    // MARK: - Reporting

    public func generateReport() -> String {
        var report = "Performance Metrics Report\n"
        report += "==========================\n\n"

        for (name, data) in metrics.sorted(by: { $0.key < $1.key }) {
            report += "\(name):\n"
            report += "  Count: \(data.count)\n"
            report += "  Min: \(String(format: "%.3f", data.min))\n"
            report += "  Max: \(String(format: "%.3f", data.max))\n"
            report += "  Avg: \(String(format: "%.3f", data.average))\n"
            report += "  P50: \(String(format: "%.3f", data.p50))\n"
            report += "  P95: \(String(format: "%.3f", data.p95))\n"
            report += "  P99: \(String(format: "%.3f", data.p99))\n\n"
        }

        return report
    }
}

public struct MetricData {
    public let name: String
    public private(set) var count: Int = 0
    public private(set) var sum: Double = 0
    public private(set) var min: Double = .infinity
    public private(set) var max: Double = -.infinity
    private var values: [Double] = []

    public init(name: String) {
        self.name = name
    }

    public mutating func recordValue(_ value: Double) {
        count += 1
        sum += value
        min = Swift.min(min, value)
        max = Swift.max(max, value)
        values.append(value)

        // Keep only recent values to prevent unbounded growth
        if values.count > 10000 {
            values.removeFirst(values.count - 10000)
        }
    }

    public var average: Double {
        count > 0 ? sum / Double(count) : 0
    }

    public var p50: Double {
        percentile(0.5)
    }

    public var p95: Double {
        percentile(0.95)
    }

    public var p99: Double {
        percentile(0.99)
    }

    private func percentile(_ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }

        let sorted = values.sorted()
        let index = Int(Double(sorted.count) * p)
        return sorted[Swift.min(index, sorted.count - 1)]
    }
}

// MARK: - CPU and System Monitoring

/// Monitors system resource usage (CPU, memory)
public actor SystemResourceMonitor {
    // MARK: - Properties

    private let logger: OSLog
    private var monitoringTask: Task<Void, Never>?
    private let updateInterval: TimeInterval

    // Resource metrics
    private var cpuUsage: Double = 0
    private var memoryUsage: UInt64 = 0
    private var memoryPressure: MemoryPressureHandler.MemoryPressureLevel = .normal

    // History for trending
    private var cpuHistory: [ResourceSample] = []
    private var memoryHistory: [ResourceSample] = []
    private let maxHistorySize: Int = 300 // 5 minutes at 1s interval

    // MARK: - Initialization

    public init(
        updateInterval: TimeInterval = 1.0,
        logger: OSLog = Logger.performanceLog
    ) {
        self.updateInterval = updateInterval
        self.logger = logger
    }

    // MARK: - Monitoring

    public func startMonitoring() {
        stopMonitoring()

        monitoringTask = Task {
            while !Task.isCancelled {
                await updateMetrics()
                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
            }
        }

        os_log(.info, log: logger, "System resource monitoring started")
    }

    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        os_log(.info, log: logger, "System resource monitoring stopped")
    }

    private func updateMetrics() {
        let timestamp = Date()

        // Update CPU usage
        let cpu = getCPUUsage()
        cpuUsage = cpu
        cpuHistory.append(ResourceSample(timestamp: timestamp, value: cpu))

        // Update memory usage
        let memory = getMemoryUsage()
        memoryUsage = memory
        memoryHistory.append(ResourceSample(timestamp: timestamp, value: Double(memory)))

        // Trim history
        if cpuHistory.count > maxHistorySize {
            cpuHistory.removeFirst(cpuHistory.count - maxHistorySize)
        }
        if memoryHistory.count > maxHistorySize {
            memoryHistory.removeFirst(memoryHistory.count - maxHistorySize)
        }

        // Log warnings if needed
        if cpu > 80.0 {
            os_log(.default, log: logger, "⚠️ High CPU usage: %.1f%%", cpu)
        }
        if Double(memory) / Double(getSystemMemory()) > 0.8 {
            os_log(.default, log: logger, "⚠️ High memory usage: %lld MB", memory / 1024 / 1024)
        }
    }

    // MARK: - Metrics Retrieval

    public func getCurrentMetrics() -> SystemResourceMetrics {
        SystemResourceMetrics(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            memoryPressure: memoryPressure,
            timestamp: Date()
        )
    }

    public func getMetricsHistory() -> ResourceMetricsHistory {
        ResourceMetricsHistory(
            cpuHistory: cpuHistory,
            memoryHistory: memoryHistory
        )
    }

    public func getMetricsSummary() -> ResourceMetricsSummary {
        let cpuValues = cpuHistory.map { $0.value }
        let memoryValues = memoryHistory.map { $0.value }

        return ResourceMetricsSummary(
            cpu: MetricsSummaryData(
                current: cpuUsage,
                average: cpuValues.isEmpty ? 0 : cpuValues.reduce(0, +) / Double(cpuValues.count),
                min: cpuValues.min() ?? 0,
                max: cpuValues.max() ?? 0,
                p50: percentile(cpuValues, 0.5),
                p95: percentile(cpuValues, 0.95),
                p99: percentile(cpuValues, 0.99)
            ),
            memory: MetricsSummaryData(
                current: Double(memoryUsage),
                average: memoryValues.isEmpty ? 0 : memoryValues.reduce(0, +) / Double(memoryValues.count),
                min: memoryValues.min() ?? 0,
                max: memoryValues.max() ?? 0,
                p50: percentile(memoryValues, 0.5),
                p95: percentile(memoryValues, 0.95),
                p99: percentile(memoryValues, 0.99)
            ),
            systemMemory: getSystemMemory()
        )
    }

    // MARK: - System Metrics

    private func getCPUUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }

        guard threadsResult == KERN_SUCCESS, let threadsList = threadsList else {
            return 0.0
        }

        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }

        for index in 0..<Int(threadsCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threadsList[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }

            guard infoResult == KERN_SUCCESS else {
                continue
            }

            let threadBasicInfo = threadInfo
            if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsageOfCPU += (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
            }
        }

        return totalUsageOfCPU
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    private func getSystemMemory() -> UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    private func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int(Double(sorted.count) * p)
        return sorted[min(index, sorted.count - 1)]
    }
}

public struct ResourceSample {
    public let timestamp: Date
    public let value: Double
}

public struct SystemResourceMetrics {
    public let cpuUsage: Double
    public let memoryUsage: UInt64
    public let memoryPressure: MemoryPressureHandler.MemoryPressureLevel
    public let timestamp: Date

    public var memoryUsageMB: Double {
        Double(memoryUsage) / 1024.0 / 1024.0
    }
}

public struct ResourceMetricsHistory {
    public let cpuHistory: [ResourceSample]
    public let memoryHistory: [ResourceSample]
}

public struct MetricsSummaryData {
    public let current: Double
    public let average: Double
    public let min: Double
    public let max: Double
    public let p50: Double
    public let p95: Double
    public let p99: Double
}

public struct ResourceMetricsSummary {
    public let cpu: MetricsSummaryData
    public let memory: MetricsSummaryData
    public let systemMemory: UInt64

    public var memoryUsagePercentage: Double {
        (memory.current / Double(systemMemory)) * 100.0
    }
}

// MARK: - Comprehensive Performance Dashboard

/// Centralized performance dashboard that aggregates all metrics
public actor PerformanceDashboard {
    // MARK: - Properties

    private let metricsCollector: PerformanceMetricsCollector
    private let resourceMonitor: SystemResourceMonitor
    private let logger: OSLog

    // External components to monitor
    private weak var connectionPool: ConnectionPool?
    private var latencyTracker: LatencyTracker

    // MARK: - Initialization

    public init(
        connectionPool: ConnectionPool? = nil,
        logger: OSLog = Logger.performanceLog
    ) {
        self.metricsCollector = PerformanceMetricsCollector(logger: logger)
        self.resourceMonitor = SystemResourceMonitor(logger: logger)
        self.connectionPool = connectionPool
        self.latencyTracker = LatencyTracker()
        self.logger = logger
    }

    // MARK: - Lifecycle

    public func start() async {
        await resourceMonitor.startMonitoring()
        os_log(.info, log: logger, "Performance dashboard started")
    }

    public func stop() async {
        await resourceMonitor.stopMonitoring()
        os_log(.info, log: logger, "Performance dashboard stopped")
    }

    // MARK: - Metrics Recording

    public func recordLatency(_ latency: TimeInterval, operation: String) async {
        await metricsCollector.recordDuration("\(operation)_latency", duration: latency)
        latencyTracker.record(latency, operation: operation)
    }

    public func recordValue(_ name: String, value: Double) async {
        await metricsCollector.recordValue(name, value: value)
    }

    public func increment(_ name: String) async {
        await metricsCollector.increment(name)
    }

    // MARK: - Dashboard Data

    public func getDashboardData() async -> PerformanceDashboardData {
        let systemMetrics = await resourceMonitor.getCurrentMetrics()
        let resourceSummary = await resourceMonitor.getMetricsSummary()
        let allMetrics = await metricsCollector.getAllMetrics()

        // Get connection pool stats
        var poolHitRate: Double = 0
        var poolStats: PoolStatistics?
        if let pool = connectionPool {
            poolStats = await pool.getStatistics()
            poolHitRate = await pool.getHitRate()
        }

        // Get latency distribution
        let latencyDistribution = latencyTracker.getDistribution()

        return PerformanceDashboardData(
            systemMetrics: systemMetrics,
            resourceSummary: resourceSummary,
            connectionPoolHitRate: poolHitRate,
            connectionPoolStats: poolStats,
            latencyDistribution: latencyDistribution,
            customMetrics: allMetrics,
            timestamp: Date()
        )
    }

    // MARK: - Reporting

    public func generateReport() async -> String {
        let data = await getDashboardData()

        var report = "=== SwiftProxy Performance Report ===\n"
        report += "Generated: \(data.timestamp)\n\n"

        // System Resources
        report += "System Resources:\n"
        report += "  CPU Usage: \(String(format: "%.1f%%", data.systemMetrics.cpuUsage))\n"
        report += "  Memory: \(String(format: "%.1f MB", data.systemMetrics.memoryUsageMB))\n"
        report += "  Memory %: \(String(format: "%.1f%%", data.resourceSummary.memoryUsagePercentage))\n\n"

        // Connection Pool
        if let poolStats = data.connectionPoolStats {
            report += "Connection Pool:\n"
            report += "  Hit Rate: \(String(format: "%.1f%%", data.connectionPoolHitRate * 100))\n"
            report += "  Active: \(poolStats.activeConnections)\n"
            report += "  Available: \(poolStats.availableConnections)\n"
            report += "  Total Created: \(poolStats.totalCreated)\n\n"
        }

        // Latency Distribution
        report += "Request Latency:\n"
        report += "  P50: \(String(format: "%.2f ms", data.latencyDistribution.p50 * 1000))\n"
        report += "  P90: \(String(format: "%.2f ms", data.latencyDistribution.p90 * 1000))\n"
        report += "  P95: \(String(format: "%.2f ms", data.latencyDistribution.p95 * 1000))\n"
        report += "  P99: \(String(format: "%.2f ms", data.latencyDistribution.p99 * 1000))\n\n"

        // Custom Metrics
        if !data.customMetrics.isEmpty {
            report += "Custom Metrics:\n"
            for (name, metric) in data.customMetrics.sorted(by: { $0.key < $1.key }) {
                report += "  \(name):\n"
                report += "    Avg: \(String(format: "%.3f", metric.average))\n"
                report += "    P95: \(String(format: "%.3f", metric.p95))\n"
            }
        }

        return report
    }

    public func exportToJSON() async throws -> Data {
        let data = await getDashboardData()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(data)
    }

    public func exportToCSV() async -> String {
        let data = await getDashboardData()

        var csv = "Metric,Value,Unit\n"

        // System metrics
        csv += "CPU Usage,\(data.systemMetrics.cpuUsage),%\n"
        csv += "Memory Usage,\(data.systemMetrics.memoryUsageMB),MB\n"
        csv += "Memory Usage Percentage,\(data.resourceSummary.memoryUsagePercentage),%\n"

        // Pool metrics
        if let poolStats = data.connectionPoolStats {
            csv += "Connection Pool Hit Rate,\(data.connectionPoolHitRate * 100),%\n"
            csv += "Active Connections,\(poolStats.activeConnections),count\n"
            csv += "Available Connections,\(poolStats.availableConnections),count\n"
        }

        // Latency metrics
        csv += "Latency P50,\(data.latencyDistribution.p50 * 1000),ms\n"
        csv += "Latency P90,\(data.latencyDistribution.p90 * 1000),ms\n"
        csv += "Latency P95,\(data.latencyDistribution.p95 * 1000),ms\n"
        csv += "Latency P99,\(data.latencyDistribution.p99 * 1000),ms\n"

        return csv
    }
}

// MARK: - Latency Tracker

struct LatencyTracker {
    private var samples: [TimeInterval] = []
    private let maxSamples = 10000

    mutating func record(_ latency: TimeInterval, operation: String) {
        samples.append(latency)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    func getDistribution() -> LatencyDistribution {
        guard !samples.isEmpty else {
            return LatencyDistribution(p50: 0, p90: 0, p95: 0, p99: 0, average: 0, min: 0, max: 0)
        }

        let sorted = samples.sorted()
        let count = sorted.count

        return LatencyDistribution(
            p50: sorted[Int(Double(count) * 0.5)],
            p90: sorted[Int(Double(count) * 0.9)],
            p95: sorted[Int(Double(count) * 0.95)],
            p99: sorted[Int(Double(count) * 0.99)],
            average: samples.reduce(0, +) / Double(count),
            min: sorted.first ?? 0,
            max: sorted.last ?? 0
        )
    }
}

public struct LatencyDistribution: Codable {
    public let p50: TimeInterval
    public let p90: TimeInterval
    public let p95: TimeInterval
    public let p99: TimeInterval
    public let average: TimeInterval
    public let min: TimeInterval
    public let max: TimeInterval
}

public struct PerformanceDashboardData: Codable {
    public let systemMetrics: SystemResourceMetrics
    public let resourceSummary: ResourceMetricsSummary
    public let connectionPoolHitRate: Double
    public let connectionPoolStats: PoolStatistics?
    public let latencyDistribution: LatencyDistribution
    public let customMetrics: [String: MetricData]
    public let timestamp: Date
}

// Make types Codable
extension SystemResourceMetrics: Codable {
    enum CodingKeys: String, CodingKey {
        case cpuUsage, memoryUsage, timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cpuUsage = try container.decode(Double.self, forKey: .cpuUsage)
        memoryUsage = try container.decode(UInt64.self, forKey: .memoryUsage)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        memoryPressure = .normal
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cpuUsage, forKey: .cpuUsage)
        try container.encode(memoryUsage, forKey: .memoryUsage)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

extension MetricsSummaryData: Codable {}
extension ResourceMetricsSummary: Codable {}
extension MetricData: Codable {}

// MARK: - Helper Extensions

extension Data {
    mutating func resetBytes(in range: Range<Int>) {
        for i in range {
            self[i] = 0
        }
    }
}
