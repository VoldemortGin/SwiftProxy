import Foundation
import Network
import OSLog
import CryptoKit

// MARK: - WebSocket Connection

/// Manages a WebSocket connection with handshake and message handling
@available(macOS 12.0, *)
public class WebSocketConnection: ProxyConnection {
    // MARK: - Properties

    private let fragmenter = WebSocketFragmenter()
    private var isWebSocketEstablished: Bool = false
    private var closeCodeSent: Bool = false

    // Callbacks
    public var onTextMessage: ((String) -> Void)?
    public var onBinaryMessage: ((Data) -> Void)?
    public var onPing: ((Data) -> Void)?
    public var onPong: ((Data) -> Void)?
    public var onClose: ((WebSocketCloseCode?, String?) -> Void)?

    // Ping/Pong
    private var lastPingTime: Date?
    private var pingInterval: TimeInterval = 30.0
    private var pongTimeout: TimeInterval = 10.0

    // MARK: - Initialization

    override init(
        id: UUID,
        nwConnection: NWConnection,
        configuration: ProxyConfiguration,
        connectionPool: ConnectionPool,
        sslHandler: SSLHandler,
        retryHandler: RetryHandler,
        logger: OSLog
    ) {
        super.init(
            id: id,
            nwConnection: nwConnection,
            configuration: configuration,
            connectionPool: connectionPool,
            sslHandler: sslHandler,
            retryHandler: retryHandler,
            logger: logger
        )
    }

    // MARK: - Connection Lifecycle

    public override func start() async {
        os_log(.info, log: logger, "Starting WebSocket connection: %{public}@", self.id.uuidString)

        do {
            await waitForReady()

            // Read and process WebSocket handshake from client
            try await performHandshake()

            isWebSocketEstablished = true
            os_log(.info, log: logger, "WebSocket connection established")

            // Start message processing and ping/pong
            await withTaskGroup(of: Void.self) { group in
                // Task 1: Read and process frames
                group.addTask {
                    await self.readFramesLoop()
                }

                // Task 2: Send periodic pings
                group.addTask {
                    await self.pingLoop()
                }

                await group.waitForAll()
            }

        } catch {
            os_log(.error, log: logger, "WebSocket error: %{public}@", error.localizedDescription)
            await close()
        }
    }

    // MARK: - WebSocket Handshake

    private func performHandshake() async throws {
        // Read HTTP request
        let requestData = try await receiveHTTPHeaders()
        let request = try parseHTTPRequest(from: requestData)

        os_log(.debug, log: logger, "WebSocket handshake request: %{public}@", request.method)

        // Validate WebSocket upgrade request
        guard request.method == "GET",
              request.headers["upgrade"]?.lowercased() == "websocket",
              request.headers["connection"]?.lowercased().contains("upgrade") == true,
              let key = request.headers["sec-websocket-key"],
              request.headers["sec-websocket-version"] == "13" else {
            throw WebSocketError.handshakeFailed
        }

        // Generate accept key
        let acceptKey = generateAcceptKey(from: key)

        // Send handshake response
        let response = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r\n
        """

        guard let responseData = response.data(using: .utf8) else {
            throw WebSocketError.handshakeFailed
        }

        try await send(data: responseData)
        os_log(.debug, log: logger, "WebSocket handshake response sent")
    }

    private func receiveHTTPHeaders() async throws -> Data {
        var buffer = Data()
        let headerEnd = "\r\n\r\n".data(using: .ascii)!

        while true {
            let chunk = try await receive(minLength: 1, maxLength: 4096)
            buffer.append(chunk)

            // Check for end of headers
            if let range = buffer.range(of: headerEnd) {
                return buffer.subdata(in: 0..<(range.upperBound))
            }

            // Prevent excessive header size
            guard buffer.count < 8192 else {
                throw WebSocketError.handshakeFailed
            }
        }
    }

    private func parseHTTPRequest(from data: Data) throws -> WebSocketHTTPRequest {
        guard let string = String(data: data, encoding: .utf8) else {
            throw WebSocketError.handshakeFailed
        }

        let lines = string.components(separatedBy: "\r\n")
        guard !lines.isEmpty else {
            throw WebSocketError.handshakeFailed
        }

        // Parse request line
        let requestLine = lines[0].components(separatedBy: " ")
        guard requestLine.count >= 2 else {
            throw WebSocketError.handshakeFailed
        }

        let method = requestLine[0]
        let path = requestLine[1]

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }

            let parts = line.components(separatedBy: ": ")
            guard parts.count >= 2 else { continue }

            let key = parts[0].lowercased()
            let value = parts[1...].joined(separator: ": ")
            headers[key] = value
        }

        return WebSocketHTTPRequest(method: method, path: path, headers: headers)
    }

    private func generateAcceptKey(from clientKey: String) -> String {
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let combined = clientKey + magic

        guard let data = combined.data(using: .utf8) else {
            return ""
        }

        let hash = Insecure.SHA1.hash(data: data)
        return Data(hash).base64EncodedString()
    }

    // MARK: - Frame Processing

    private func readFramesLoop() async {
        var buffer = Data()

        while isWebSocketEstablished && !closeCodeSent {
            do {
                // Read data
                let chunk = try await receive(minLength: 1, maxLength: 65536)
                buffer.append(chunk)

                // Try to parse frames from buffer
                while true {
                    do {
                        let (frame, bytesRead) = try WebSocketFrame.parse(from: buffer)

                        // Remove parsed bytes from buffer
                        buffer.removeFirst(bytesRead)

                        // Process frame
                        try await processFrame(frame)

                    } catch WebSocketError.incompleteFrame {
                        // Need more data
                        break
                    }
                }

            } catch {
                os_log(.error, log: logger, "Frame read error: %{public}@", error.localizedDescription)
                break
            }
        }

        await close()
    }

    private func processFrame(_ frame: WebSocketFrame) async throws {
        os_log(.debug, log: logger, "Processing WebSocket frame: %{public}@", String(describing: frame.opcode))

        // Handle control frames immediately
        switch frame.opcode {
        case .ping:
            try await handlePing(frame)
            return

        case .pong:
            handlePong(frame)
            return

        case .connectionClose:
            try await handleClose(frame)
            return

        default:
            break
        }

        // Handle data frames with fragmenter
        if let message = try await fragmenter.processFrame(frame) {
            await handleMessage(message)
        }
    }

    private func handleMessage(_ message: WebSocketMessage) async {
        switch message.opcode {
        case .text:
            if let text = try? message.asText() {
                os_log(.debug, log: logger, "Received text message: %d bytes", message.data.count)
                onTextMessage?(text)
            } else {
                os_log(.error, log: logger, "Invalid UTF-8 in text message")
                try? await sendClose(code: .invalidFramePayload, reason: "Invalid UTF-8")
            }

        case .binary:
            os_log(.debug, log: logger, "Received binary message: %d bytes", message.data.count)
            onBinaryMessage?(message.data)

        default:
            break
        }
    }

    private func handlePing(_ frame: WebSocketFrame) async throws {
        os_log(.debug, log: logger, "Received ping")
        onPing?(frame.payload)

        // Send pong response
        let pongFrame = WebSocketFrame.pong(frame.payload, masked: false)
        try await sendFrame(pongFrame)
    }

    private func handlePong(_ frame: WebSocketFrame) {
        os_log(.debug, log: logger, "Received pong")
        onPong?(frame.payload)
        lastPingTime = nil // Reset ping timeout
    }

    private func handleClose(_ frame: WebSocketFrame) async throws {
        let (code, reason) = frame.closeInfo()
        os_log(.info, log: logger, "Received close frame: code=%{public}@, reason=%{public}@",
               code.map { String($0.rawValue) } ?? "none",
               reason ?? "none")

        onClose?(code, reason)

        // Send close response if we haven't already
        if !closeCodeSent {
            try await sendClose(code: .normal, reason: "")
        }

        closeCodeSent = true
        await close()
    }

    // MARK: - Sending

    private func sendFrame(_ frame: WebSocketFrame) async throws {
        let data = frame.serialize()
        try await send(data: data)
    }

    /// Send a text message
    public func sendText(_ text: String, fragmented: Bool = false) async throws {
        guard isWebSocketEstablished else {
            throw WebSocketError.connectionClosed
        }

        let frame = try WebSocketFrame.text(text, fin: !fragmented, masked: false)
        try await sendFrame(frame)
        os_log(.debug, log: logger, "Sent text message: %d bytes", text.utf8.count)
    }

    /// Send a binary message
    public func sendBinary(_ data: Data, fragmented: Bool = false) async throws {
        guard isWebSocketEstablished else {
            throw WebSocketError.connectionClosed
        }

        let frame = WebSocketFrame.binary(data, fin: !fragmented, masked: false)
        try await sendFrame(frame)
        os_log(.debug, log: logger, "Sent binary message: %d bytes", data.count)
    }

    /// Send a ping
    public func sendPing(_ data: Data = Data()) async throws {
        guard isWebSocketEstablished else {
            throw WebSocketError.connectionClosed
        }

        let frame = WebSocketFrame.ping(data, masked: false)
        try await sendFrame(frame)
        lastPingTime = Date()
        os_log(.debug, log: logger, "Sent ping")
    }

    /// Send a close frame
    public func sendClose(code: WebSocketCloseCode = .normal, reason: String = "") async throws {
        guard !closeCodeSent else { return }

        let frame = try WebSocketFrame.close(code: code, reason: reason, masked: false)
        try await sendFrame(frame)
        closeCodeSent = true
        os_log(.info, log: logger, "Sent close frame: code=%d", code.rawValue)
    }

    // MARK: - Ping/Pong Loop

    private func pingLoop() async {
        while isWebSocketEstablished && !closeCodeSent {
            // Wait for ping interval
            try? await Task.sleep(nanoseconds: UInt64(pingInterval * 1_000_000_000))

            guard isWebSocketEstablished && !closeCodeSent else { break }

            // Send ping
            try? await sendPing()

            // Wait for pong timeout
            try? await Task.sleep(nanoseconds: UInt64(pongTimeout * 1_000_000_000))

            // Check if pong was received
            if let pingTime = lastPingTime {
                let elapsed = Date().timeIntervalSince(pingTime)
                if elapsed > pongTimeout {
                    os_log(.default, log: logger, "Pong timeout - closing connection")
                    try? await sendClose(code: .goingAway, reason: "Pong timeout")
                    break
                }
            }
        }
    }

    // MARK: - Close

    public override func close() async {
        guard isWebSocketEstablished else {
            await super.close()
            return
        }

        os_log(.info, log: logger, "Closing WebSocket connection: %{public}@", self.id.uuidString)

        // Send close frame if not already sent
        if !closeCodeSent {
            try? await sendClose(code: .normal, reason: "")
        }

        isWebSocketEstablished = false
        await fragmenter.reset()
        await super.close()
    }
}

// MARK: - HTTP Request

private struct WebSocketHTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
}
