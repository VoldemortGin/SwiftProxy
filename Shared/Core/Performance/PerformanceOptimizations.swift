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

        startFlushTimer()
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

// MARK: - Helper Extensions

extension Data {
    mutating func resetBytes(in range: Range<Int>) {
        for i in range {
            self[i] = 0
        }
    }
}
