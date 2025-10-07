import Foundation
import Network
import OSLog

/// Main proxy server that handles incoming connections and routes them through configured proxies
/// Supports HTTP, HTTPS, and SOCKS5 protocols with connection pooling and SSL/TLS handling
@available(macOS 12.0, *)
public actor ProxyServer {
    // MARK: - Properties

    private let configuration: ProxyConfiguration
    private let logger: OSLog
    private let connectionPool: ConnectionPool
    private let sslHandler: SSLHandler
    private let retryHandler: RetryHandler

    private var listener: NWListener?
    private var activeConnections: [UUID: ProxyConnection] = [:]
    private var isRunning: Bool = false
    private var statistics: ProxyStatistics = ProxyStatistics()

    // Queue for handling connections
    private let connectionQueue: DispatchQueue

    // MARK: - Initialization

    public init(
        configuration: ProxyConfiguration,
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "ProxyServer")
    ) {
        self.configuration = configuration
        self.logger = logger
        self.connectionPool = ConnectionPool(maxConnections: 100)
        self.sslHandler = SSLHandler(logger: logger)
        self.retryHandler = RetryHandler(maxRetries: 3, backoffMultiplier: 2.0)
        self.connectionQueue = DispatchQueue(label: "com.swiftproxy.connection", qos: .userInitiated, attributes: .concurrent)
    }

    // MARK: - Server Lifecycle

    /// Start the proxy server on the configured port
    public func start() async throws {
        guard !isRunning else {
            os_log(.default, log: logger, "Proxy server is already running")
            throw AppError.proxyAlreadyEnabled
        }

        os_log(.info, log: logger, "Starting proxy server on \(self.configuration.host):\(self.configuration.port)")

        do {
            // Create listener based on proxy type
            let listener = try createListener()
            self.listener = listener

            // Start receiving connections
            listener.stateUpdateHandler = { [weak self] state in
                Task { await self?.handleListenerState(state) }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { await self?.handleNewConnection(connection) }
            }

            listener.start(queue: connectionQueue)
            isRunning = true

            os_log(.info, log: logger, "Proxy server started successfully")
        } catch {
            os_log(.error, log: logger, "Failed to start proxy server: \(error.localizedDescription)")
            throw AppError.proxyConnectionFailed("Failed to start listener: \(error.localizedDescription)")
        }
    }

    /// Stop the proxy server and close all connections
    public func stop() async {
        guard isRunning else {
            os_log(.default, log: logger, "Proxy server is not running")
            return
        }

        os_log(.info, log: logger, "Stopping proxy server")

        // Cancel listener
        listener?.cancel()
        listener = nil

        // Close all active connections
        for (_, connection) in activeConnections {
            await connection.close()
        }
        activeConnections.removeAll()

        isRunning = false
        os_log(.info, log: logger, "Proxy server stopped")
    }

    // MARK: - Listener Management

    private func createListener() throws -> NWListener {
        let port = NWEndpoint.Port(integerLiteral: UInt16(configuration.port))

        // Configure TCP parameters
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 60

        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        parameters.acceptLocalOnly = false
        parameters.allowLocalEndpointReuse = true

        // For HTTPS, configure TLS
        if configuration.type == .https {
            let tlsOptions = NWProtocolTLS.Options()
            parameters.defaultProtocolStack.applicationProtocols.insert(tlsOptions, at: 0)
        }

        return try NWListener(using: parameters, on: port)
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            os_log(.info, log: logger, "Listener is ready to accept connections")

        case .failed(let error):
            os_log(.error, log: logger, "Listener failed: \(error.localizedDescription)")
            isRunning = false

        case .cancelled:
            os_log(.info, log: logger, "Listener was cancelled")
            isRunning = false

        case .waiting(let error):
            os_log(.default, log: logger, "Listener is waiting: \(error.localizedDescription)")

        case .setup:
            os_log(.debug, log: logger, "Listener is setting up")

        @unknown default:
            os_log(.default, log: logger, "Unknown listener state")
        }
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ nwConnection: NWConnection) async {
        let connectionID = UUID()
        os_log(.info, log: logger, "New connection: \(connectionID)")

        do {
            // Create proxy connection based on type
            let connection: ProxyConnection

            switch configuration.type {
            case .http, .https:
                connection = HTTPProxyConnection(
                    id: connectionID,
                    nwConnection: nwConnection,
                    configuration: configuration,
                    connectionPool: connectionPool,
                    sslHandler: sslHandler,
                    retryHandler: retryHandler,
                    logger: logger
                )

            case .socks5:
                connection = SOCKS5ProxyConnection(
                    id: connectionID,
                    nwConnection: nwConnection,
                    configuration: configuration,
                    connectionPool: connectionPool,
                    sslHandler: sslHandler,
                    retryHandler: retryHandler,
                    logger: logger
                )
            }

            // Store active connection
            activeConnections[connectionID] = connection

            // Handle the connection
            await connection.start()

            // Update statistics
            statistics.totalConnections += 1
            statistics.activeConnections = activeConnections.count

            // Remove connection when done
            connection.onComplete = { [weak self] result in
                Task {
                    await self?.connectionDidComplete(connectionID, result: result)
                }
            }

        } catch {
            os_log(.error, log: logger, "Failed to handle connection \(connectionID): \(error.localizedDescription)")
            nwConnection.cancel()
        }
    }

    private func connectionDidComplete(_ id: UUID, result: ConnectionResult) {
        activeConnections.removeValue(forKey: id)
        statistics.activeConnections = activeConnections.count

        switch result {
        case .success(let stats):
            statistics.totalBytesTransferred += stats.bytesTransferred
            statistics.successfulConnections += 1
            os_log(.debug, log: logger, "Connection \(id) completed: \(stats.bytesTransferred) bytes")

        case .failure(let error):
            statistics.failedConnections += 1
            os_log(.error, log: logger, "Connection \(id) failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Statistics

    public func getStatistics() -> ProxyStatistics {
        return statistics
    }

    public func resetStatistics() {
        statistics = ProxyStatistics()
    }
}

// MARK: - HTTPProxyConnection

/// Handles HTTP/HTTPS proxy connections using CONNECT method or direct forwarding
@available(macOS 12.0, *)
final class HTTPProxyConnection: ProxyConnection {
    override func start() async {
        os_log(.info, log: logger, "Starting HTTP proxy connection: \(self.id)")

        nwConnection.start(queue: .global(qos: .userInitiated))

        // Wait for connection to be ready
        await waitForReady()

        // Read HTTP request
        do {
            let request = try await readHTTPRequest()

            // Handle CONNECT method for HTTPS
            if request.method == "CONNECT" {
                try await handleHTTPSConnect(request)
            } else {
                try await handleHTTPRequest(request)
            }

        } catch {
            os_log(.error, log: logger, "HTTP connection error: \(error.localizedDescription)")
            onComplete?(.failure(error))
            await close()
        }
    }

    private func handleHTTPSConnect(_ request: HTTPRequest) async throws {
        // Parse target host and port
        guard let targetHost = request.host, let targetPort = request.port else {
            throw AppError.invalidURL("Invalid CONNECT request")
        }

        os_log(.info, log: logger, "Handling HTTPS CONNECT to %{public}@:%d", targetHost, targetPort)

        // Get or create connection from pool
        let targetConnection = try await connectionPool.getConnection(
            host: targetHost,
            port: targetPort,
            useTLS: true
        )

        // Send 200 Connection Established
        let response = "HTTP/1.1 200 Connection Established\r\n\r\n"
        try await send(data: response.data(using: .utf8)!)

        // Start bidirectional data forwarding
        await startTunnel(to: targetConnection)
    }

    private func handleHTTPRequest(_ request: HTTPRequest) async throws {
        os_log(.info, log: logger, "Handling HTTP request: \(request.method) \(request.url)")

        // For HTTP, forward the request directly
        guard let targetHost = request.host, let targetPort = request.port else {
            throw AppError.invalidURL("Invalid HTTP request")
        }

        // Apply retry logic
        let targetConnection = try await retryHandler.execute { [self] in
            try await self.connectionPool.getConnection(
                host: targetHost,
                port: targetPort,
                useTLS: false
            )
        }

        // Forward request to target
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            targetConnection.send(content: request.rawData, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }

        // Forward response back
        await startTunnel(to: targetConnection)
    }

    private func readHTTPRequest() async throws -> HTTPRequest {
        // Read until we have complete HTTP headers
        var buffer = Data()
        let headerTerminator = "\r\n\r\n".data(using: .utf8)!

        while !buffer.contains(headerTerminator) {
            let chunk = try await receive(minLength: 1, maxLength: 8192)
            buffer.append(chunk)

            // Prevent reading too much
            if buffer.count > 16384 {
                throw AppError.invalidResponse
            }
        }

        return try HTTPRequest.parse(from: buffer)
    }
}

// MARK: - SOCKS5ProxyConnection

/// Handles SOCKS5 proxy connections with authentication support
@available(macOS 12.0, *)
final class SOCKS5ProxyConnection: ProxyConnection {
    override func start() async {
        os_log(.info, log: logger, "Starting SOCKS5 proxy connection: \(self.id)")

        nwConnection.start(queue: .global(qos: .userInitiated))

        await waitForReady()

        do {
            // SOCKS5 handshake
            try await performSOCKS5Handshake()

            // Parse SOCKS5 request
            let request = try await readSOCKS5Request()

            os_log(.info, log: logger, "SOCKS5 request: \(request.addressType) \(request.destinationHost):\(request.destinationPort)")

            // Connect to target
            let targetConnection = try await retryHandler.execute {
                try await connectionPool.getConnection(
                    host: request.destinationHost,
                    port: Int(request.destinationPort),
                    useTLS: false
                )
            }

            // Send success response
            try await sendSOCKS5Response(success: true)

            // Start tunneling
            await startTunnel(to: targetConnection)

        } catch {
            os_log(.error, log: logger, "SOCKS5 connection error: \(error.localizedDescription)")

            // Try to send error response
            try? await sendSOCKS5Response(success: false)

            onComplete?(.failure(error))
            await close()
        }
    }

    private func performSOCKS5Handshake() async throws {
        // Read client greeting
        let greeting = try await receive(minLength: 2, maxLength: 257)

        guard greeting.count >= 2 else {
            throw AppError.proxyConnectionFailed("Invalid SOCKS5 greeting")
        }

        let version = greeting[0]
        let nmethods = greeting[1]

        guard version == 0x05 else {
            throw AppError.proxyConnectionFailed("Unsupported SOCKS version: \(version)")
        }

        // Read authentication methods
        guard greeting.count >= Int(2 + nmethods) else {
            throw AppError.proxyConnectionFailed("Incomplete SOCKS5 greeting")
        }

        let methods = Array(greeting[2..<(2 + Int(nmethods))])

        // Choose authentication method
        var authMethod: UInt8 = 0xFF // No acceptable methods

        if configuration.requiresAuth {
            // Username/password authentication
            if methods.contains(0x02) {
                authMethod = 0x02
            }
        } else {
            // No authentication
            if methods.contains(0x00) {
                authMethod = 0x00
            }
        }

        // Send method selection response
        let response = Data([0x05, authMethod])
        try await send(data: response)

        guard authMethod != 0xFF else {
            throw AppError.proxyAuthenticationFailed
        }

        // Perform authentication if required
        if authMethod == 0x02 {
            try await performUsernamePasswordAuth()
        }
    }

    private func performUsernamePasswordAuth() async throws {
        // Read auth request
        let authData = try await receive(minLength: 3, maxLength: 513)

        guard authData.count >= 3 else {
            throw AppError.proxyAuthenticationFailed
        }

        let version = authData[0]
        guard version == 0x01 else {
            throw AppError.proxyAuthenticationFailed
        }

        let usernameLen = Int(authData[1])
        guard authData.count >= 2 + usernameLen + 1 else {
            throw AppError.proxyAuthenticationFailed
        }

        let username = String(data: authData[2..<(2 + usernameLen)], encoding: .utf8) ?? ""
        let passwordLen = Int(authData[2 + usernameLen])

        guard authData.count >= 2 + usernameLen + 1 + passwordLen else {
            throw AppError.proxyAuthenticationFailed
        }

        let password = String(data: authData[(3 + usernameLen)..<(3 + usernameLen + passwordLen)], encoding: .utf8) ?? ""

        // Verify credentials
        let isValid = username == configuration.username && password == configuration.password

        // Send auth response
        let response = Data([0x01, isValid ? 0x00 : 0x01])
        try await send(data: response)

        if !isValid {
            throw AppError.proxyAuthenticationFailed
        }
    }

    private func readSOCKS5Request() async throws -> SOCKS5Request {
        let header = try await receive(minLength: 4, maxLength: 4)

        guard header[0] == 0x05 else {
            throw AppError.proxyConnectionFailed("Invalid SOCKS5 request version")
        }

        let command = header[1]
        let addressType = header[3]

        // We only support CONNECT command
        guard command == 0x01 else {
            throw AppError.proxyConnectionFailed("Unsupported SOCKS5 command: \(command)")
        }

        // Read destination address based on type
        let destinationHost: String

        switch addressType {
        case 0x01: // IPv4
            let addr = try await receive(minLength: 4, maxLength: 4)
            destinationHost = addr.map { String($0) }.joined(separator: ".")

        case 0x03: // Domain name
            let lenData = try await receive(minLength: 1, maxLength: 1)
            let len = Int(lenData[0])
            let domain = try await receive(minLength: len, maxLength: len)
            destinationHost = String(data: domain, encoding: .utf8) ?? ""

        case 0x04: // IPv6
            let addr = try await receive(minLength: 16, maxLength: 16)
            // Format IPv6 address
            destinationHost = formatIPv6(addr)

        default:
            throw AppError.proxyConnectionFailed("Unsupported address type: \(addressType)")
        }

        // Read port
        let portData = try await receive(minLength: 2, maxLength: 2)
        let port = UInt16(portData[0]) << 8 | UInt16(portData[1])

        return SOCKS5Request(
            command: command,
            addressType: addressType,
            destinationHost: destinationHost,
            destinationPort: port
        )
    }

    private func sendSOCKS5Response(success: Bool) async throws {
        // VER | REP | RSV | ATYP | BND.ADDR | BND.PORT
        var response = Data([
            0x05, // Version
            success ? 0x00 : 0x01, // Reply (0x00 = success, 0x01 = general failure)
            0x00, // Reserved
            0x01  // Address type (IPv4)
        ])

        // Bind address (0.0.0.0)
        response.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        // Bind port (0)
        response.append(contentsOf: [0x00, 0x00])

        try await send(data: response)
    }

    private func formatIPv6(_ data: Data) -> String {
        var parts: [String] = []
        for i in stride(from: 0, to: 16, by: 2) {
            let value = UInt16(data[i]) << 8 | UInt16(data[i + 1])
            parts.append(String(format: "%x", value))
        }
        return parts.joined(separator: ":")
    }
}

// MARK: - Supporting Types

public struct ProxyStatistics: Codable {
    public var totalConnections: Int = 0
    public var activeConnections: Int = 0
    public var successfulConnections: Int = 0
    public var failedConnections: Int = 0
    public var totalBytesTransferred: Int64 = 0
}

public enum ConnectionResult {
    case success(ConnectionStats)
    case failure(any Error)
}

public struct ConnectionStats {
    public let bytesTransferred: Int64
    public let duration: TimeInterval
}

struct HTTPRequest {
    let method: String
    let url: String
    let host: String?
    let port: Int?
    let headers: [String: String]
    let rawData: Data

    static func parse(from data: Data) throws -> HTTPRequest {
        guard let string = String(data: data, encoding: .utf8) else {
            throw AppError.dataDecodingFailed
        }

        let lines = string.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw AppError.invalidResponse
        }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            throw AppError.invalidResponse
        }

        let method = parts[0]
        let url = parts[1]

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard !line.isEmpty else { break }
            let components = line.components(separatedBy: ": ")
            if components.count == 2 {
                headers[components[0]] = components[1]
            }
        }

        // Extract host and port
        var host: String?
        var port: Int?

        if method == "CONNECT" {
            let parts = url.components(separatedBy: ":")
            host = parts.first
            port = parts.count > 1 ? Int(parts[1]) : 443
        } else if let hostHeader = headers["Host"] {
            let parts = hostHeader.components(separatedBy: ":")
            host = parts.first
            port = parts.count > 1 ? Int(parts[1]) : 80
        }

        return HTTPRequest(
            method: method,
            url: url,
            host: host,
            port: port,
            headers: headers,
            rawData: data
        )
    }
}

struct SOCKS5Request {
    let command: UInt8
    let addressType: UInt8
    let destinationHost: String
    let destinationPort: UInt16
}

extension Data {
    func contains(_ other: Data) -> Bool {
        guard !other.isEmpty else { return true }
        guard self.count >= other.count else { return false }

        for i in 0...(self.count - other.count) {
            if self[i..<(i + other.count)] == other {
                return true
            }
        }
        return false
    }
}
