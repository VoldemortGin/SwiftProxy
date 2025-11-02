import Foundation
import Network
import OSLog

/// Base class for proxy connections that handles bidirectional data forwarding
/// Subclasses implement protocol-specific handshaking and request handling
@available(macOS 12.0, *)
public class ProxyConnection {
    // MARK: - Properties

    public let id: UUID
    let nwConnection: NWConnection
    let configuration: ProxyConfiguration
    let connectionPool: ConnectionPool
    let sslHandler: SSLHandler
    let retryHandler: RetryHandler
    let logger: OSLog

    // Shared buffer pool for all connections
    private static let bufferPool = BufferPool(
        bufferSize: 65536,  // 64KB buffers
        maxPoolSize: 100,
        logger: OSLog(subsystem: "com.swiftproxy", category: "BufferPool")
    )

    // Connection state
    private var isActive: Bool = false
    private var totalBytesReceived: Int64 = 0
    private var totalBytesSent: Int64 = 0
    private let startTime: Date = Date()

    // Completion handler
    var onComplete: ((ConnectionResult) -> Void)?

    // MARK: - Initialization

    init(
        id: UUID,
        nwConnection: NWConnection,
        configuration: ProxyConfiguration,
        connectionPool: ConnectionPool,
        sslHandler: SSLHandler,
        retryHandler: RetryHandler,
        logger: OSLog
    ) {
        self.id = id
        self.nwConnection = nwConnection
        self.configuration = configuration
        self.connectionPool = connectionPool
        self.sslHandler = sslHandler
        self.retryHandler = retryHandler
        self.logger = logger
    }

    // MARK: - Lifecycle

    /// Start handling the connection (must be overridden by subclasses)
    public func start() async {
        fatalError("start() must be overridden by subclass")
    }

    /// Close the connection gracefully
    public func close() async {
        guard isActive else { return }

        os_log(.info, log: logger, "Closing connection: \(self.id)")
        isActive = false

        nwConnection.cancel()

        // Calculate statistics
        let duration = Date().timeIntervalSince(startTime)
        let stats = ConnectionStats(
            bytesTransferred: totalBytesReceived + totalBytesSent,
            duration: duration
        )

        onComplete?(.success(stats))
    }

    // MARK: - Data Transfer

    /// Send data through the connection
    func send(data: Data) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            nwConnection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: AppError.requestFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Receive data from the connection using buffer pool
    func receive(minLength: Int = 1, maxLength: Int = 65536) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            nwConnection.receive(minimumIncompleteLength: minLength, maximumLength: maxLength) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: AppError.requestFailed(error.localizedDescription))
                } else if let data = data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: AppError.connectionTimeout)
                } else {
                    continuation.resume(throwing: AppError.invalidResponse)
                }
            }
        }
    }

    /// Get statistics about buffer pool usage
    static func getBufferPoolStats() async -> BufferPoolStatistics {
        await bufferPool.getStatistics()
    }

    /// Clear buffer pool (for testing or memory pressure)
    static func clearBufferPool() async {
        await bufferPool.clear()
    }

    /// Wait for connection to be ready
    func waitForReady() async {
        await withCheckedContinuation { continuation in
            nwConnection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                    self.isActive = true

                case .failed(let error):
                    os_log(.error, log: self.logger, "Connection failed: \(error.localizedDescription)")
                    continuation.resume()

                case .cancelled:
                    os_log(.info, log: self.logger, "Connection cancelled")
                    continuation.resume()

                default:
                    break
                }
            }
        }
    }

    // MARK: - Tunneling

    /// Start bidirectional data tunneling between client and target
    func startTunnel(to targetConnection: NWConnection) async {
        os_log(.info, log: logger, "Starting tunnel for connection: \(self.id)")
        isActive = true

        // Create tasks for bidirectional forwarding
        await withTaskGroup(of: Void.self) { group in
            // Forward from client to target
            group.addTask {
                await self.forwardData(
                    from: self.nwConnection,
                    to: targetConnection,
                    direction: "client->target"
                )
            }

            // Forward from target to client
            group.addTask {
                await self.forwardData(
                    from: targetConnection,
                    to: self.nwConnection,
                    direction: "target->client"
                )
            }

            // Wait for both tasks to complete
            await group.waitForAll()
        }

        os_log(.info, log: logger, "Tunnel closed for connection: \(self.id)")
        await close()
    }

    /// Forward data from one connection to another
    private func forwardData(
        from source: NWConnection,
        to destination: NWConnection,
        direction: String
    ) async {
        while isActive {
            do {
                // Read data from source
                let data = try await receiveFrom(source)

                guard !data.isEmpty else {
                    os_log(.debug, log: logger, "\(direction): Connection closed by peer")
                    break
                }

                // Update statistics
                if direction.contains("client->") {
                    totalBytesSent += Int64(data.count)
                } else {
                    totalBytesReceived += Int64(data.count)
                }

                // Write data to destination
                try await sendTo(destination, data: data)

                os_log(.debug, log: logger, "\(direction): Forwarded \(data.count) bytes")

            } catch {
                os_log(.error, log: logger, "\(direction): Error forwarding data: \(error.localizedDescription)")
                break
            }
        }
    }

    private func receiveFrom(_ connection: NWConnection) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(returning: Data())
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    private func sendTo(_ connection: NWConnection, data: Data) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    // MARK: - Connection Management

    /// Create a new outbound connection to the target server
    static func createOutboundConnection(
        host: String,
        port: Int,
        useTLS: Bool
    ) throws -> NWConnection {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 60

        let parameters: NWParameters

        if useTLS {
            let tlsOptions = NWProtocolTLS.Options()
            parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        } else {
            parameters = NWParameters(tls: nil, tcp: tcpOptions)
        }

        parameters.allowLocalEndpointReuse = true
        parameters.prohibitedInterfaceTypes = []

        return NWConnection(to: endpoint, using: parameters)
    }
}

// MARK: - Connection State

/// Represents the current state of a proxy connection
public enum ProxyConnectionState {
    case idle
    case connecting
    case handshaking
    case tunneling
    case closing
    case closed
    case error(any Error)

    var isActive: Bool {
        switch self {
        case .connecting, .handshaking, .tunneling:
            return true
        default:
            return false
        }
    }
}

// MARK: - Connection Metrics

/// Metrics for a proxy connection
public struct ConnectionMetrics {
    public let connectionID: UUID
    public let startTime: Date
    public var endTime: Date?
    public var bytesReceived: Int64 = 0
    public var bytesSent: Int64 = 0
    public var state: ProxyConnectionState = .idle

    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    public var totalBytes: Int64 {
        bytesReceived + bytesSent
    }

    public var throughput: Double? {
        guard let duration = duration, duration > 0 else { return nil }
        return Double(totalBytes) / duration
    }
}

// MARK: - Connection Manager

/// Manages multiple proxy connections and their lifecycle
@available(macOS 12.0, *)
public actor ConnectionManager {
    private var connections: [UUID: ProxyConnection] = [:]
    private var metrics: [UUID: ConnectionMetrics] = [:]
    private let logger: OSLog

    public init(logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "ConnectionManager")) {
        self.logger = logger
    }

    /// Register a new connection
    public func register(_ connection: ProxyConnection) {
        connections[connection.id] = connection
        metrics[connection.id] = ConnectionMetrics(
            connectionID: connection.id,
            startTime: Date()
        )
        os_log(.info, log: logger, "Registered connection: \(connection.id)")
    }

    /// Unregister a connection
    public func unregister(_ connectionID: UUID) {
        connections.removeValue(forKey: connectionID)
        if var metric = metrics[connectionID] {
            metric.endTime = Date()
            metric.state = .closed
            metrics[connectionID] = metric
        }
        os_log(.info, log: logger, "Unregistered connection: \(connectionID)")
    }

    /// Get all active connections
    public func getActiveConnections() -> [ProxyConnection] {
        Array(connections.values)
    }

    /// Get connection metrics
    public func getMetrics(for connectionID: UUID) -> ConnectionMetrics? {
        metrics[connectionID]
    }

    /// Get all metrics
    public func getAllMetrics() -> [ConnectionMetrics] {
        Array(metrics.values)
    }

    /// Close all connections
    public func closeAll() async {
        os_log(.info, log: logger, "Closing all connections (\(self.connections.count))")

        for connection in connections.values {
            await connection.close()
        }

        connections.removeAll()
    }

    /// Get connection count
    public func getConnectionCount() -> Int {
        connections.count
    }

    /// Update connection metrics
    public func updateMetrics(
        for connectionID: UUID,
        bytesReceived: Int64? = nil,
        bytesSent: Int64? = nil,
        state: ProxyConnectionState? = nil
    ) {
        guard var metric = metrics[connectionID] else { return }

        if let bytesReceived = bytesReceived {
            metric.bytesReceived += bytesReceived
        }

        if let bytesSent = bytesSent {
            metric.bytesSent += bytesSent
        }

        if let state = state {
            metric.state = state
        }

        metrics[connectionID] = metric
    }
}

// MARK: - Connection Pool Entry
// MARK: - Connection Extensions

extension NWConnection.State: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .setup:
            return "setup"
        case .preparing:
            return "preparing"
        case .ready:
            return "ready"
        case .waiting(let error):
            return "waiting(\(error.localizedDescription))"
        case .failed(let error):
            return "failed(\(error.localizedDescription))"
        case .cancelled:
            return "cancelled"
        @unknown default:
            return "unknown"
        }
    }
}
