import Foundation
import Network
import OSLog

// MARK: - HTTP/2 Connection

/// Manages an HTTP/2 connection with frame processing and stream multiplexing
@available(macOS 12.0, *)
public class HTTP2Connection: ProxyConnection {
    // MARK: - Properties

    private let streamManager: HTTP2StreamManager
    private var settings: HTTP2Settings
    private var peerSettings: HTTP2Settings
    private var connectionWindowSize: Int
    private var isPrefaceReceived: Bool = false
    private var isPrefaceSent: Bool = false
    private let frameQueue: AsyncStream<HTTP2Frame>
    private var frameContinuation: AsyncStream<HTTP2Frame>.Continuation?

    // State
    private var isConnected: Bool = false
    private var goAwayReceived: Bool = false

    // MARK: - Initialization

    init(
        id: UUID,
        nwConnection: NWConnection,
        configuration: ProxyConfiguration,
        connectionPool: ConnectionPool,
        sslHandler: SSLHandler,
        retryHandler: RetryHandler,
        logger: OSLog,
        isClient: Bool = true
    ) {
        self.streamManager = HTTP2StreamManager(isClient: isClient, logger: logger)
        self.settings = .default
        self.peerSettings = .default
        self.connectionWindowSize = HTTP2Constants.defaultWindowSize

        let (stream, continuation) = AsyncStream<HTTP2Frame>.makeStream()
        self.frameQueue = stream
        self.frameContinuation = continuation

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
        os_log(.info, log: logger, "Starting HTTP/2 connection: %{public}@", self.id.uuidString)

        do {
            // Wait for connection to be ready
            await waitForReady()

            // Send connection preface
            try await sendPreface()

            // Send initial SETTINGS frame
            try await sendSettings()

            // Start frame processing
            await withTaskGroup(of: Void.self) { group in
                // Task 1: Read frames from connection
                group.addTask {
                    await self.readFramesLoop()
                }

                // Task 2: Process frames
                group.addTask {
                    await self.processFramesLoop()
                }

                // Wait for both tasks
                await group.waitForAll()
            }

        } catch {
            os_log(.error, log: logger, "HTTP/2 connection error: %{public}@", error.localizedDescription)
            await close()
        }
    }

    // MARK: - Connection Preface

    private func sendPreface() async throws {
        guard !isPrefaceSent else { return }

        os_log(.debug, log: logger, "Sending HTTP/2 connection preface")
        try await send(data: HTTP2Constants.connectionPreface)
        isPrefaceSent = true
    }

    private func verifyPreface(_ data: Data) throws {
        guard data == HTTP2Constants.connectionPreface else {
            throw HTTP2Error.protocolError
        }
        isPrefaceReceived = true
        os_log(.debug, log: logger, "Received valid HTTP/2 connection preface")
    }

    // MARK: - Settings Management

    private func sendSettings() async throws {
        let settingsData = settings.serialize()
        let header = HTTP2FrameHeader(
            length: UInt32(settingsData.count),
            type: .settings,
            flags: [],
            streamID: 0
        )
        let frame = HTTP2Frame(header: header, payload: settingsData)

        os_log(.debug, log: logger, "Sending SETTINGS frame")
        try await sendFrame(frame)
    }

    private func handleSettingsFrame(_ frame: HTTP2Frame) async throws {
        // ACK
        if frame.header.flags.contains(.ack) {
            os_log(.debug, log: logger, "Received SETTINGS ACK")
            return
        }

        // Parse and apply settings
        peerSettings = try HTTP2Settings.parse(from: frame.payload)
        os_log(.debug, log: logger, "Received SETTINGS from peer")

        // Update stream manager
        if let maxStreams = peerSettings.maxConcurrentStreams {
            await streamManager.updateMaxConcurrentStreams(maxStreams)
        }

        // Update initial window size
        if peerSettings.initialWindowSize != HTTP2Constants.defaultWindowSize {
            try await streamManager.updateInitialWindowSize(Int(peerSettings.initialWindowSize))
        }

        // Send SETTINGS ACK
        let ackHeader = HTTP2FrameHeader(
            length: 0,
            type: .settings,
            flags: .ack,
            streamID: 0
        )
        let ackFrame = HTTP2Frame(header: ackHeader, payload: Data())
        try await sendFrame(ackFrame)
        os_log(.debug, log: logger, "Sent SETTINGS ACK")
    }

    // MARK: - Frame Processing

    private func readFramesLoop() async {
        while !goAwayReceived {
            do {
                // Read frame header (9 bytes)
                let headerData = try await receive(minLength: HTTP2FrameHeader.size, maxLength: HTTP2FrameHeader.size)
                let header = try HTTP2FrameHeader.parse(from: headerData)

                // Validate frame size
                guard header.length <= peerSettings.maxFrameSize else {
                    throw HTTP2Error.frameSizeError
                }

                // Read frame payload
                let payload: Data
                if header.length > 0 {
                    payload = try await receive(minLength: Int(header.length), maxLength: Int(header.length))
                } else {
                    payload = Data()
                }

                let frame = HTTP2Frame(header: header, payload: payload)

                // Send to processing queue
                frameContinuation?.yield(frame)

            } catch {
                os_log(.error, log: logger, "Frame read error: %{public}@", error.localizedDescription)
                frameContinuation?.finish()
                break
            }
        }
    }

    private func processFramesLoop() async {
        for await frame in frameQueue {
            do {
                try await processFrame(frame)
            } catch {
                os_log(.error, log: logger, "Frame processing error: %{public}@", error.localizedDescription)
                await handleError(error as? HTTP2Error ?? .protocolError)
                break
            }
        }
    }

    private func processFrame(_ frame: HTTP2Frame) async throws {
        os_log(.debug, log: logger, "Processing %{public}@ frame (stream: %d, length: %d)",
               String(describing: frame.header.type), frame.header.streamID, frame.header.length)

        // Connection-level frames (stream ID must be 0)
        if frame.header.streamID == 0 {
            switch frame.header.type {
            case .settings:
                try await handleSettingsFrame(frame)
            case .ping:
                try await handlePingFrame(frame)
            case .goAway:
                try await handleGoAwayFrame(frame)
            case .windowUpdate:
                try await handleConnectionWindowUpdate(frame)
            default:
                throw HTTP2Error.protocolError
            }
            return
        }

        // Stream-level frames
        let stream = try await streamManager.getOrCreateStream(
            frame.header.streamID,
            initialWindowSize: Int(peerSettings.initialWindowSize)
        )

        switch frame.header.type {
        case .data:
            try await handleDataFrame(frame, stream: stream)
        case .headers:
            try await handleHeadersFrame(frame, stream: stream)
        case .priority:
            try await handlePriorityFrame(frame, stream: stream)
        case .rstStream:
            try await handleRstStreamFrame(frame, stream: stream)
        case .windowUpdate:
            try await handleStreamWindowUpdate(frame, stream: stream)
        default:
            os_log(.default, log: logger, "Unhandled frame type: %{public}@", String(describing: frame.header.type))
        }
    }

    // MARK: - Frame Handlers

    private func handleDataFrame(_ frame: HTTP2Frame, stream: HTTP2Stream) async throws {
        let endStream = frame.header.flags.contains(.endStream)

        // Check window size
        guard connectionWindowSize >= frame.payload.count else {
            throw HTTP2Error.flowControlError
        }

        connectionWindowSize -= frame.payload.count

        // Deliver to stream
        try await stream.receiveData(frame.payload, endStream: endStream)

        // Update flow control
        if connectionWindowSize < HTTP2Constants.defaultWindowSize / 2 {
            try await sendConnectionWindowUpdate(increment: HTTP2Constants.defaultWindowSize)
        }

        if endStream {
            os_log(.debug, log: logger, "Stream %d received END_STREAM", frame.header.streamID)
        }
    }

    private func handleHeadersFrame(_ frame: HTTP2Frame, stream: HTTP2Stream) async throws {
        let endStream = frame.header.flags.contains(.endStream)

        // Parse headers (simplified - real implementation would use HPACK)
        let headers = parseHeaders(from: frame.payload)
        try await stream.receiveHeaders(headers, endStream: endStream)

        if endStream {
            os_log(.debug, log: logger, "Stream %d received END_STREAM with headers", frame.header.streamID)
        }
    }

    private func handlePriorityFrame(_ frame: HTTP2Frame, stream: HTTP2Stream) async throws {
        guard frame.payload.count == 5 else {
            throw HTTP2Error.frameSizeError
        }

        let priority = try HTTP2StreamPriority.parse(from: frame.payload)
        os_log(.debug, log: logger, "Stream %d priority: weight=%d", frame.header.streamID, priority.weight)
    }

    private func handleRstStreamFrame(_ frame: HTTP2Frame, stream: HTTP2Stream) async throws {
        guard frame.payload.count == 4 else {
            throw HTTP2Error.frameSizeError
        }

        let errorCode = UInt32(frame.payload[0]) << 24 | UInt32(frame.payload[1]) << 16 |
                       UInt32(frame.payload[2]) << 8 | UInt32(frame.payload[3])

        os_log(.info, log: logger, "Stream %d reset with error code: %d", frame.header.streamID, errorCode)
        await streamManager.closeStream(frame.header.streamID)
    }

    private func handlePingFrame(_ frame: HTTP2Frame) async throws {
        guard frame.payload.count == 8 else {
            throw HTTP2Error.frameSizeError
        }

        if frame.header.flags.contains(.ack) {
            os_log(.debug, log: logger, "Received PING ACK")
        } else {
            // Send PING ACK
            let ackHeader = HTTP2FrameHeader(
                length: 8,
                type: .ping,
                flags: .ack,
                streamID: 0
            )
            let ackFrame = HTTP2Frame(header: ackHeader, payload: frame.payload)
            try await sendFrame(ackFrame)
            os_log(.debug, log: logger, "Sent PING ACK")
        }
    }

    private func handleGoAwayFrame(_ frame: HTTP2Frame) async throws {
        guard frame.payload.count >= 8 else {
            throw HTTP2Error.frameSizeError
        }

        let lastStreamID = (UInt32(frame.payload[0] & 0x7F) << 24) | (UInt32(frame.payload[1]) << 16) |
                          (UInt32(frame.payload[2]) << 8) | UInt32(frame.payload[3])
        let errorCode = UInt32(frame.payload[4]) << 24 | UInt32(frame.payload[5]) << 16 |
                       UInt32(frame.payload[6]) << 8 | UInt32(frame.payload[7])

        os_log(.info, log: logger, "Received GOAWAY: lastStreamID=%d, errorCode=%d", lastStreamID, errorCode)
        goAwayReceived = true
    }

    private func handleStreamWindowUpdate(_ frame: HTTP2Frame, stream: HTTP2Stream) async throws {
        guard frame.payload.count == 4 else {
            throw HTTP2Error.frameSizeError
        }

        let increment = Int((UInt32(frame.payload[0] & 0x7F) << 24) | (UInt32(frame.payload[1]) << 16) |
                           (UInt32(frame.payload[2]) << 8) | UInt32(frame.payload[3]))

        guard increment > 0 && increment <= HTTP2Constants.maxWindowSize else {
            throw HTTP2Error.flowControlError
        }

        try await stream.updateRemoteWindowSize(delta: increment)
        os_log(.debug, log: logger, "Stream %d window updated: +%d", frame.header.streamID, increment)
    }

    private func handleConnectionWindowUpdate(_ frame: HTTP2Frame) async throws {
        guard frame.payload.count == 4 else {
            throw HTTP2Error.frameSizeError
        }

        let increment = Int((UInt32(frame.payload[0] & 0x7F) << 24) | (UInt32(frame.payload[1]) << 16) |
                           (UInt32(frame.payload[2]) << 8) | UInt32(frame.payload[3]))

        guard increment > 0 && increment <= HTTP2Constants.maxWindowSize else {
            throw HTTP2Error.flowControlError
        }

        connectionWindowSize += increment
        os_log(.debug, log: logger, "Connection window updated: +%d (total: %d)", increment, connectionWindowSize)
    }

    // MARK: - Sending Frames

    private func sendFrame(_ frame: HTTP2Frame) async throws {
        let data = frame.serialize()
        try await send(data: data)
    }

    private func sendConnectionWindowUpdate(increment: Int) async throws {
        var payload = Data(capacity: 4)
        payload.append(UInt8((increment >> 24) & 0x7F))
        payload.append(UInt8((increment >> 16) & 0xFF))
        payload.append(UInt8((increment >> 8) & 0xFF))
        payload.append(UInt8(increment & 0xFF))

        let header = HTTP2FrameHeader(
            length: 4,
            type: .windowUpdate,
            flags: [],
            streamID: 0
        )
        let frame = HTTP2Frame(header: header, payload: payload)
        try await sendFrame(frame)

        connectionWindowSize += increment
        os_log(.debug, log: logger, "Sent connection WINDOW_UPDATE: +%d", increment)
    }

    // MARK: - Helper Methods

    private func parseHeaders(from data: Data) -> [(String, String)] {
        // Simplified header parsing - real implementation would use HPACK decompression
        // For now, return empty headers
        return []
    }

    private func handleError(_ error: HTTP2Error) async {
        os_log(.error, log: logger, "HTTP/2 error: %{public}@", String(describing: error))

        // Send GOAWAY frame
        do {
            var payload = Data(capacity: 8)
            payload.append(0) // Last stream ID (we'll use 0 for now)
            payload.append(0)
            payload.append(0)
            payload.append(0)

            let errorCode = error.errorCode.rawValue
            payload.append(UInt8((errorCode >> 24) & 0xFF))
            payload.append(UInt8((errorCode >> 16) & 0xFF))
            payload.append(UInt8((errorCode >> 8) & 0xFF))
            payload.append(UInt8(errorCode & 0xFF))

            let header = HTTP2FrameHeader(
                length: UInt32(payload.count),
                type: .goAway,
                flags: [],
                streamID: 0
            )
            let frame = HTTP2Frame(header: header, payload: payload)
            try await sendFrame(frame)
        } catch {
            os_log(.error, log: logger, "Failed to send GOAWAY: %{public}@", error.localizedDescription)
        }

        await close()
    }

    public override func close() async {
        os_log(.info, log: logger, "Closing HTTP/2 connection: %{public}@", self.id.uuidString)
        await streamManager.closeAllStreams()
        frameContinuation?.finish()
        await super.close()
    }
}
