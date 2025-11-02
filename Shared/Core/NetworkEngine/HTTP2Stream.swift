import Foundation
import OSLog

// MARK: - HTTP/2 Stream State

/// HTTP/2 stream states as defined in RFC 7540
public enum HTTP2StreamState {
    case idle
    case reservedLocal
    case reservedRemote
    case open
    case halfClosedLocal
    case halfClosedRemote
    case closed

    /// Check if stream can send frames
    public var canSend: Bool {
        switch self {
        case .open, .halfClosedRemote:
            return true
        default:
            return false
        }
    }

    /// Check if stream can receive frames
    public var canReceive: Bool {
        switch self {
        case .open, .halfClosedLocal:
            return true
        default:
            return false
        }
    }
}

// MARK: - HTTP/2 Stream

/// Represents an HTTP/2 stream
@available(macOS 12.0, *)
public actor HTTP2Stream {
    // MARK: - Properties

    public let streamID: UInt32
    public private(set) var state: HTTP2StreamState
    private var windowSize: Int
    private var receivedData: Data = Data()
    private var receivedHeaders: [(String, String)] = []
    private var sentData: Data = Data()
    private let logger: OSLog

    // Flow control
    private var localWindowSize: Int
    private var remoteWindowSize: Int

    // Callbacks
    public var onDataReceived: ((Data) -> Void)?
    public var onHeadersReceived: (([(String, String)]) -> Void)?
    public var onStreamClosed: (() -> Void)?

    // MARK: - Initialization

    public init(
        streamID: UInt32,
        initialWindowSize: Int = HTTP2Constants.defaultWindowSize,
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "HTTP2Stream")
    ) {
        self.streamID = streamID
        self.state = .idle
        self.windowSize = initialWindowSize
        self.localWindowSize = initialWindowSize
        self.remoteWindowSize = initialWindowSize
        self.logger = logger
    }

    // MARK: - State Management

    /// Transition stream state based on frame type and flags
    public func updateState(frameType: HTTP2FrameType, flags: HTTP2FrameFlags, isSending: Bool) throws {
        let oldState = state

        switch frameType {
        case .headers:
            switch state {
            case .idle:
                state = flags.contains(.endStream) ? .halfClosedRemote : .open
            case .reservedRemote:
                state = .halfClosedLocal
            case .open:
                if flags.contains(.endStream) {
                    state = isSending ? .halfClosedLocal : .halfClosedRemote
                }
            default:
                throw HTTP2Error.streamError(.streamClosed, streamID: streamID)
            }

        case .data:
            if flags.contains(.endStream) {
                switch state {
                case .open:
                    state = isSending ? .halfClosedLocal : .halfClosedRemote
                case .halfClosedLocal:
                    if !isSending {
                        state = .closed
                    }
                case .halfClosedRemote:
                    if isSending {
                        state = .closed
                    }
                default:
                    break
                }
            }

        case .rstStream:
            state = .closed

        default:
            break
        }

        if oldState != state {
            os_log(.debug, log: logger, "Stream %d: %{public}@ -> %{public}@",
                   streamID, String(describing: oldState), String(describing: state))
        }
    }

    /// Close the stream
    public func close() {
        state = .closed
        onStreamClosed?()
    }

    // MARK: - Data Management

    /// Add received data to buffer
    public func receiveData(_ data: Data, endStream: Bool) throws {
        guard state.canReceive else {
            throw HTTP2Error.streamError(.streamClosed, streamID: streamID)
        }

        receivedData.append(data)
        onDataReceived?(data)

        // Update local window
        localWindowSize -= data.count
        if localWindowSize < 0 {
            throw HTTP2Error.flowControlError
        }

        if endStream {
            try updateState(frameType: .data, flags: .endStream, isSending: false)
        }
    }

    /// Add received headers
    public func receiveHeaders(_ headers: [(String, String)], endStream: Bool) throws {
        guard state.canReceive else {
            throw HTTP2Error.streamError(.streamClosed, streamID: streamID)
        }

        receivedHeaders.append(contentsOf: headers)
        onHeadersReceived?(headers)

        if endStream {
            try updateState(frameType: .headers, flags: .endStream, isSending: false)
        }
    }

    /// Get all received data
    public func getReceivedData() -> Data {
        return receivedData
    }

    /// Get all received headers
    public func getReceivedHeaders() -> [(String, String)] {
        return receivedHeaders
    }

    // MARK: - Flow Control

    /// Update remote window size
    public func updateRemoteWindowSize(delta: Int) throws {
        remoteWindowSize += delta
        if remoteWindowSize > HTTP2Constants.maxWindowSize {
            throw HTTP2Error.flowControlError
        }
    }

    /// Update local window size
    public func updateLocalWindowSize(delta: Int) throws {
        localWindowSize += delta
        if localWindowSize > HTTP2Constants.maxWindowSize {
            throw HTTP2Error.flowControlError
        }
    }

    /// Check if stream can send data (has window space)
    public func canSendData(size: Int) -> Bool {
        return state.canSend && remoteWindowSize >= size
    }

    /// Consume remote window space
    public func consumeRemoteWindow(size: Int) throws {
        guard size <= remoteWindowSize else {
            throw HTTP2Error.flowControlError
        }
        remoteWindowSize -= size
    }

    /// Get current window sizes
    public func getWindowSizes() -> (local: Int, remote: Int) {
        return (localWindowSize, remoteWindowSize)
    }
}

// MARK: - HTTP/2 Stream Manager

/// Manages multiple HTTP/2 streams
@available(macOS 12.0, *)
public actor HTTP2StreamManager {
    // MARK: - Properties

    private var streams: [UInt32: HTTP2Stream] = [:]
    private var nextStreamID: UInt32 = 1 // Client streams are odd
    private var maxConcurrentStreams: UInt32?
    private let logger: OSLog

    // Statistics
    private var totalStreamsCreated: Int = 0
    private var totalStreamsClosed: Int = 0

    // MARK: - Initialization

    public init(
        isClient: Bool = true,
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "HTTP2StreamManager")
    ) {
        self.nextStreamID = isClient ? 1 : 2 // Clients use odd, servers use even
        self.logger = logger
    }

    // MARK: - Stream Creation

    /// Create a new stream
    public func createStream(initialWindowSize: Int = HTTP2Constants.defaultWindowSize) throws -> HTTP2Stream {
        // Check concurrent stream limit (use current stream count as proxy for active streams)
        if let maxStreams = maxConcurrentStreams {
            guard UInt32(streams.count) < maxStreams else {
                throw HTTP2Error.connectionError(.refusedStream)
            }
        }

        let streamID = nextStreamID
        nextStreamID += 2 // Skip even/odd based on role

        let stream = HTTP2Stream(streamID: streamID, initialWindowSize: initialWindowSize, logger: logger)
        streams[streamID] = stream
        totalStreamsCreated += 1

        os_log(.debug, log: logger, "Created stream %d (total: %d)", streamID, streams.count)

        return stream
    }

    /// Get existing stream
    public func getStream(_ streamID: UInt32) -> HTTP2Stream? {
        return streams[streamID]
    }

    /// Get or create stream (for incoming streams)
    public func getOrCreateStream(
        _ streamID: UInt32,
        initialWindowSize: Int = HTTP2Constants.defaultWindowSize
    ) throws -> HTTP2Stream {
        if let existing = streams[streamID] {
            return existing
        }

        let stream = HTTP2Stream(streamID: streamID, initialWindowSize: initialWindowSize, logger: logger)
        streams[streamID] = stream
        totalStreamsCreated += 1

        os_log(.debug, log: logger, "Created incoming stream %d", streamID)

        return stream
    }

    /// Close a stream
    public func closeStream(_ streamID: UInt32) async {
        if let stream = streams[streamID] {
            await stream.close()
            streams.removeValue(forKey: streamID)
            totalStreamsClosed += 1

            os_log(.debug, log: logger, "Closed stream %d (active: %d)", streamID, streams.count)
        }
    }

    /// Close all streams
    public func closeAllStreams() async {
        for (streamID, stream) in streams {
            await stream.close()
            os_log(.debug, log: logger, "Closed stream %d", streamID)
        }
        streams.removeAll()
        totalStreamsClosed += totalStreamsCreated
    }

    // MARK: - Configuration

    /// Update max concurrent streams setting
    public func updateMaxConcurrentStreams(_ max: UInt32?) {
        maxConcurrentStreams = max
        os_log(.info, log: logger, "Updated max concurrent streams: %{public}@",
               max.map(String.init) ?? "unlimited")
    }

    /// Update window size for all streams
    public func updateInitialWindowSize(_ newSize: Int) async throws {
        for stream in streams.values {
            let delta = newSize - HTTP2Constants.defaultWindowSize
            if delta != 0 {
                try await stream.updateRemoteWindowSize(delta: delta)
            }
        }
    }

    // MARK: - Statistics

    /// Get stream statistics
    public func getStatistics() -> (active: Int, total: Int, closed: Int) {
        return (streams.count, totalStreamsCreated, totalStreamsClosed)
    }

    /// Get all active stream IDs
    public func getActiveStreamIDs() -> [UInt32] {
        return Array(streams.keys).sorted()
    }

    /// Get stream count
    public func getStreamCount() -> Int {
        return streams.count
    }
}

// MARK: - Stream Priority

/// HTTP/2 stream priority
public struct HTTP2StreamPriority {
    public let exclusive: Bool
    public let streamDependency: UInt32
    public let weight: UInt8

    public init(exclusive: Bool = false, streamDependency: UInt32 = 0, weight: UInt8 = 16) {
        self.exclusive = exclusive
        self.streamDependency = streamDependency
        self.weight = weight
    }

    /// Parse priority from data (5 bytes)
    public static func parse(from data: Data) throws -> HTTP2StreamPriority {
        guard data.count >= 5 else {
            throw HTTP2Error.frameSizeError
        }

        let exclusiveBit = (data[0] & 0x80) != 0
        let dependency = (UInt32(data[0] & 0x7F) << 24) | (UInt32(data[1]) << 16) |
                        (UInt32(data[2]) << 8) | UInt32(data[3])
        let weight = data[4]

        return HTTP2StreamPriority(
            exclusive: exclusiveBit,
            streamDependency: dependency,
            weight: weight
        )
    }

    /// Serialize priority to data (5 bytes)
    public func serialize() -> Data {
        var data = Data(capacity: 5)

        let firstByte = (exclusive ? 0x80 : 0x00) | UInt8((streamDependency >> 24) & 0x7F)
        data.append(firstByte)
        data.append(UInt8((streamDependency >> 16) & 0xFF))
        data.append(UInt8((streamDependency >> 8) & 0xFF))
        data.append(UInt8(streamDependency & 0xFF))
        data.append(weight)

        return data
    }
}
