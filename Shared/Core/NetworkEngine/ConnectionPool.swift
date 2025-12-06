import Foundation
import Network
import OSLog

/// Connection pool that maintains and reuses TCP connections to improve performance
/// Implements connection lifecycle management, health checks, and automatic cleanup
@available(macOS 12.0, *)
public actor ConnectionPool {
    // MARK: - Properties

    private let logger: OSLog
    private let maxConnections: Int
    private let maxIdleTime: TimeInterval
    private let healthCheckInterval: TimeInterval

    // Connection storage
    private var availableConnections: [ConnectionKey: [PooledConnection]] = [:]
    private var activeConnections: Set<UUID> = []

    // Statistics
    private var statistics: PoolStatistics = PoolStatistics()

    // Background cleanup task
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(
        maxConnections: Int = 100,
        maxIdleTime: TimeInterval = 300, // 5 minutes
        healthCheckInterval: TimeInterval = 60, // 1 minute
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "ConnectionPool")
    ) {
        self.maxConnections = maxConnections
        self.maxIdleTime = maxIdleTime
        self.healthCheckInterval = healthCheckInterval
        self.logger = logger

        // Use nonisolated wrapper to avoid calling actor-isolated method from init
        initializeCleanupTask()
    }

    /// Nonisolated wrapper to start cleanup task asynchronously
    nonisolated private func initializeCleanupTask() {
        Task { await startCleanupTask() }
    }

    // MARK: - Connection Management

    /// Get a connection from the pool or create a new one
    public func getConnection(
        host: String,
        port: Int,
        useTLS: Bool
    ) async throws -> NWConnection {
        let key = ConnectionKey(host: host, port: port, useTLS: useTLS)

        // Try to get an existing connection
        if var pooledConnections = availableConnections[key], !pooledConnections.isEmpty {
            // Find a healthy connection
            for (index, var pooled) in pooledConnections.enumerated() {
                if await isConnectionHealthy(pooled.connection) {
                    // Remove from available and mark as active
                    pooledConnections.remove(at: index)
                    availableConnections[key] = pooledConnections

                    pooled.markUsed()
                    activeConnections.insert(pooled.id)

                    statistics.poolHits += 1
                    statistics.activeConnections = activeConnections.count

                    os_log(.debug, log: logger, "Reusing connection to \(host):\(port) (use count: \(pooled.useCount))")

                    return pooled.connection
                } else {
                    // Connection is not healthy, close it
                    os_log(.debug, log: logger, "Removing unhealthy connection to \(host):\(port)")
                    pooled.connection.cancel()
                    pooledConnections.remove(at: index)
                }
            }

            availableConnections[key] = pooledConnections
        }

        // No available connection, create a new one
        statistics.poolMisses += 1

        let connection = try createNewConnection(host: host, port: port, useTLS: useTLS)
        let connectionID = UUID()
        activeConnections.insert(connectionID)

        statistics.totalCreated += 1
        statistics.activeConnections = activeConnections.count

        os_log(.info, log: logger, "Created new connection to \(host):\(port) (TLS: \(useTLS))")

        return connection
    }

    /// Return a connection to the pool for reuse
    public func returnConnection(
        _ connection: NWConnection,
        host: String,
        port: Int,
        useTLS: Bool
    ) async {
        let key = ConnectionKey(host: host, port: port, useTLS: useTLS)

        // Check if we should keep this connection
        guard await isConnectionHealthy(connection) else {
            os_log(.debug, log: logger, "Not returning unhealthy connection to pool")
            connection.cancel()
            return
        }

        // Check pool size limit
        let totalAvailable = availableConnections.values.reduce(0) { $0 + $1.count }
        guard totalAvailable < maxConnections else {
            os_log(.debug, log: logger, "Pool is full, closing connection")
            connection.cancel()
            statistics.droppedConnections += 1
            return
        }

        // Create pooled connection entry
        let pooled = PooledConnection(
            id: UUID(),
            connection: connection,
            host: host,
            port: port,
            useTLS: useTLS,
            lastUsed: Date(),
            useCount: 1
        )

        // Add to available connections
        if availableConnections[key] == nil {
            availableConnections[key] = []
        }
        availableConnections[key]?.append(pooled)

        statistics.totalReturned += 1

        os_log(.debug, log: logger, "Returned connection to pool: \(host):\(port)")
    }

    /// Close a specific connection
    public func closeConnection(_ connectionID: UUID) {
        activeConnections.remove(connectionID)
        statistics.activeConnections = activeConnections.count
    }

    /// Close all connections in the pool
    public func closeAll() async {
        os_log(.info, log: logger, "Closing all pooled connections")

        for connections in availableConnections.values {
            for pooled in connections {
                pooled.connection.cancel()
            }
        }

        availableConnections.removeAll()
        activeConnections.removeAll()

        statistics.activeConnections = 0

        os_log(.info, log: logger, "All connections closed")
    }

    // MARK: - Connection Health

    private func isConnectionHealthy(_ connection: NWConnection) async -> Bool {
        // Check connection state
        let state = await withCheckedContinuation { continuation in
            var currentState: NWConnection.State?

            connection.stateUpdateHandler = { state in
                if currentState == nil {
                    currentState = state
                    continuation.resume(returning: state)
                }
            }

            // If we already have a state, return it
            if let state = currentState {
                continuation.resume(returning: state)
            }
        }

        switch state {
        case .ready:
            return true
        case .failed, .cancelled:
            return false
        default:
            return false
        }
    }

    // MARK: - Connection Creation

    private func createNewConnection(
        host: String,
        port: Int,
        useTLS: Bool
    ) throws -> NWConnection {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )

        // Configure TCP parameters for connection reuse
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 60
        tcpOptions.keepaliveInterval = 30
        tcpOptions.keepaliveCount = 3
        tcpOptions.connectionTimeout = 30

        let parameters: NWParameters

        if useTLS {
            let tlsOptions = NWProtocolTLS.Options()

            // Configure TLS options
            let securityOptions = tlsOptions.securityProtocolOptions

            parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        } else {
            parameters = NWParameters(tls: nil, tcp: tcpOptions)
        }

        // Enable connection reuse
        parameters.allowLocalEndpointReuse = true
        parameters.multipathServiceType = .handover
        parameters.expiredDNSBehavior = .allow

        return NWConnection(to: endpoint, using: parameters)
    }

    // MARK: - Cleanup

    private func startCleanupTask() {
        cleanupTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(healthCheckInterval * 1_000_000_000))
                await performCleanup()
            }
        }
    }

    private func performCleanup() async {
        let now = Date()
        var removedCount = 0

        for (key, connections) in availableConnections {
            var kept: [PooledConnection] = []

            for pooled in connections {
                let idleTime = now.timeIntervalSince(pooled.lastUsed)

                if idleTime > maxIdleTime {
                    // Connection has been idle too long
                    pooled.connection.cancel()
                    removedCount += 1
                    os_log(.debug, log: logger, "Removed idle connection: \(key.host):\(key.port) (idle: \(Int(idleTime))s)")
                } else if !(await isConnectionHealthy(pooled.connection)) {
                    // Connection is not healthy
                    pooled.connection.cancel()
                    removedCount += 1
                    os_log(.debug, log: logger, "Removed unhealthy connection: \(key.host):\(key.port)")
                } else {
                    kept.append(pooled)
                }
            }

            if kept.isEmpty {
                availableConnections.removeValue(forKey: key)
            } else {
                availableConnections[key] = kept
            }
        }

        if removedCount > 0 {
            statistics.cleanedConnections += removedCount
            os_log(.info, log: logger, "Cleanup removed \(removedCount) connections")
        }
    }

    public func stopCleanup() {
        cleanupTask?.cancel()
        cleanupTask = nil
    }

    // MARK: - Statistics

    public func getStatistics() -> PoolStatistics {
        let totalAvailable = availableConnections.values.reduce(0) { $0 + $1.count }
        var stats = statistics
        stats.availableConnections = totalAvailable
        stats.activeConnections = activeConnections.count
        return stats
    }

    public func resetStatistics() {
        statistics = PoolStatistics()
    }

    /// Get pool efficiency (hit rate)
    public func getHitRate() -> Double {
        let total = statistics.poolHits + statistics.poolMisses
        guard total > 0 else { return 0 }
        return Double(statistics.poolHits) / Double(total)
    }

    // MARK: - Pool Information

    public func getPoolInfo() -> PoolInfo {
        var connectionsByHost: [String: Int] = [:]

        for (key, connections) in availableConnections {
            let hostKey = "\(key.host):\(key.port)"
            connectionsByHost[hostKey] = connections.count
        }

        return PoolInfo(
            availableConnections: connectionsByHost,
            activeConnectionCount: activeConnections.count,
            maxConnections: maxConnections,
            hitRate: getHitRate()
        )
    }
}

// MARK: - Supporting Types

/// Key for identifying pooled connections
struct ConnectionKey: Hashable {
    let host: String
    let port: Int
    let useTLS: Bool
}

/// Represents a connection in the pool
struct PooledConnection {
    let id: UUID
    let connection: NWConnection
    let host: String
    let port: Int
    let useTLS: Bool
    var lastUsed: Date
    var useCount: Int

    var isStale: Bool {
        Date().timeIntervalSince(lastUsed) > 300 // 5 minutes
    }

    mutating func markUsed() {
        lastUsed = Date()
        useCount += 1
    }
}

/// Statistics for connection pool
public struct PoolStatistics: Codable {
    public var poolHits: Int = 0
    public var poolMisses: Int = 0
    public var totalCreated: Int = 0
    public var totalReturned: Int = 0
    public var droppedConnections: Int = 0
    public var cleanedConnections: Int = 0
    public var availableConnections: Int = 0
    public var activeConnections: Int = 0

    public var hitRate: Double {
        let total = poolHits + poolMisses
        guard total > 0 else { return 0 }
        return Double(poolHits) / Double(total)
    }
}

/// Information about the current pool state
public struct PoolInfo {
    public let availableConnections: [String: Int]
    public let activeConnectionCount: Int
    public let maxConnections: Int
    public let hitRate: Double

    public var utilizationRate: Double {
        let total = availableConnections.values.reduce(0, +) + activeConnectionCount
        guard maxConnections > 0 else { return 0 }
        return Double(total) / Double(maxConnections)
    }
}
