import Foundation

// MARK: - HTTP/2 Frame Types

/// HTTP/2 frame types as defined in RFC 7540
public enum HTTP2FrameType: UInt8 {
    case data = 0x0
    case headers = 0x1
    case priority = 0x2
    case rstStream = 0x3
    case settings = 0x4
    case pushPromise = 0x5
    case ping = 0x6
    case goAway = 0x7
    case windowUpdate = 0x8
    case continuation = 0x9
}

/// HTTP/2 frame flags
public struct HTTP2FrameFlags: OptionSet {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    // Common flags
    public static let endStream = HTTP2FrameFlags(rawValue: 0x1)
    public static let ack = HTTP2FrameFlags(rawValue: 0x1)
    public static let endHeaders = HTTP2FrameFlags(rawValue: 0x4)
    public static let padded = HTTP2FrameFlags(rawValue: 0x8)
    public static let priority = HTTP2FrameFlags(rawValue: 0x20)
}

/// HTTP/2 error codes as defined in RFC 7540
public enum HTTP2ErrorCode: UInt32 {
    case noError = 0x0
    case protocolError = 0x1
    case internalError = 0x2
    case flowControlError = 0x3
    case settingsTimeout = 0x4
    case streamClosed = 0x5
    case frameSizeError = 0x6
    case refusedStream = 0x7
    case cancel = 0x8
    case compressionError = 0x9
    case connectError = 0xa
    case enhanceYourCalm = 0xb
    case inadequateSecurity = 0xc
    case http11Required = 0xd
}

// MARK: - HTTP/2 Frame Header

/// HTTP/2 frame header (9 bytes)
/// +-----------------------------------------------+
/// |                 Length (24)                   |
/// +---------------+---------------+---------------+
/// |   Type (8)    |   Flags (8)   |
/// +-+-------------+---------------+-------------------------------+
/// |R|                 Stream Identifier (31)                      |
/// +=+=============================================================+
public struct HTTP2FrameHeader {
    public let length: UInt32        // 24-bit length
    public let type: HTTP2FrameType
    public let flags: HTTP2FrameFlags
    public let streamID: UInt32      // 31-bit stream ID (R bit is reserved)

    public static let size = 9

    public init(length: UInt32, type: HTTP2FrameType, flags: HTTP2FrameFlags, streamID: UInt32) {
        self.length = length
        self.type = type
        self.flags = flags
        self.streamID = streamID & 0x7FFFFFFF // Ensure R bit is 0
    }

    /// Parse frame header from data
    public static func parse(from data: Data) throws -> HTTP2FrameHeader {
        guard data.count >= size else {
            throw HTTP2Error.frameSizeError
        }

        // Parse 24-bit length
        let length = UInt32(data[0]) << 16 | UInt32(data[1]) << 8 | UInt32(data[2])

        // Parse type
        guard let type = HTTP2FrameType(rawValue: data[3]) else {
            throw HTTP2Error.protocolError
        }

        // Parse flags
        let flags = HTTP2FrameFlags(rawValue: data[4])

        // Parse 31-bit stream ID
        let streamID = (UInt32(data[5]) << 24 | UInt32(data[6]) << 16 |
                       UInt32(data[7]) << 8 | UInt32(data[8])) & 0x7FFFFFFF

        return HTTP2FrameHeader(length: length, type: type, flags: flags, streamID: streamID)
    }

    /// Serialize frame header to data
    public func serialize() -> Data {
        var data = Data(capacity: HTTP2FrameHeader.size)

        // Length (24 bits)
        data.append(UInt8((length >> 16) & 0xFF))
        data.append(UInt8((length >> 8) & 0xFF))
        data.append(UInt8(length & 0xFF))

        // Type
        data.append(type.rawValue)

        // Flags
        data.append(flags.rawValue)

        // Stream ID (31 bits, R bit is 0)
        data.append(UInt8((streamID >> 24) & 0x7F))
        data.append(UInt8((streamID >> 16) & 0xFF))
        data.append(UInt8((streamID >> 8) & 0xFF))
        data.append(UInt8(streamID & 0xFF))

        return data
    }
}

// MARK: - HTTP/2 Frame

/// Represents a complete HTTP/2 frame
public struct HTTP2Frame {
    public let header: HTTP2FrameHeader
    public let payload: Data

    public init(header: HTTP2FrameHeader, payload: Data) {
        self.header = header
        self.payload = payload
    }

    /// Parse frame from data
    public static func parse(from data: Data) throws -> HTTP2Frame {
        let header = try HTTP2FrameHeader.parse(from: data)

        let totalSize = HTTP2FrameHeader.size + Int(header.length)
        guard data.count >= totalSize else {
            throw HTTP2Error.frameSizeError
        }

        let payload = data.subdata(in: HTTP2FrameHeader.size..<totalSize)
        return HTTP2Frame(header: header, payload: payload)
    }

    /// Serialize frame to data
    public func serialize() -> Data {
        var data = header.serialize()
        data.append(payload)
        return data
    }

    /// Total frame size
    public var totalSize: Int {
        return HTTP2FrameHeader.size + payload.count
    }
}

// MARK: - HTTP/2 Settings

/// HTTP/2 settings parameters
public enum HTTP2SettingsParameter: UInt16 {
    case headerTableSize = 0x1
    case enablePush = 0x2
    case maxConcurrentStreams = 0x3
    case initialWindowSize = 0x4
    case maxFrameSize = 0x5
    case maxHeaderListSize = 0x6
}

/// HTTP/2 settings frame payload
public struct HTTP2Settings {
    public var headerTableSize: UInt32 = 4096
    public var enablePush: Bool = true
    public var maxConcurrentStreams: UInt32? = nil
    public var initialWindowSize: UInt32 = 65535
    public var maxFrameSize: UInt32 = 16384
    public var maxHeaderListSize: UInt32? = nil

    /// Default settings
    public static let `default` = HTTP2Settings()

    /// Parse settings from frame payload
    public static func parse(from data: Data) throws -> HTTP2Settings {
        guard data.count % 6 == 0 else {
            throw HTTP2Error.frameSizeError
        }

        var settings = HTTP2Settings()
        var offset = 0

        while offset < data.count {
            let paramID = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
            let value = UInt32(data[offset + 2]) << 24 | UInt32(data[offset + 3]) << 16 |
                       UInt32(data[offset + 4]) << 8 | UInt32(data[offset + 5])

            if let param = HTTP2SettingsParameter(rawValue: paramID) {
                switch param {
                case .headerTableSize:
                    settings.headerTableSize = value
                case .enablePush:
                    settings.enablePush = value != 0
                case .maxConcurrentStreams:
                    settings.maxConcurrentStreams = value
                case .initialWindowSize:
                    guard value <= 0x7FFFFFFF else {
                        throw HTTP2Error.flowControlError
                    }
                    settings.initialWindowSize = value
                case .maxFrameSize:
                    guard value >= 16384 && value <= 16777215 else {
                        throw HTTP2Error.protocolError
                    }
                    settings.maxFrameSize = value
                case .maxHeaderListSize:
                    settings.maxHeaderListSize = value
                }
            }

            offset += 6
        }

        return settings
    }

    /// Serialize settings to frame payload
    public func serialize() -> Data {
        var data = Data()

        func appendSetting(_ param: HTTP2SettingsParameter, _ value: UInt32) {
            data.append(UInt8(param.rawValue >> 8))
            data.append(UInt8(param.rawValue & 0xFF))
            data.append(UInt8((value >> 24) & 0xFF))
            data.append(UInt8((value >> 16) & 0xFF))
            data.append(UInt8((value >> 8) & 0xFF))
            data.append(UInt8(value & 0xFF))
        }

        appendSetting(.headerTableSize, headerTableSize)
        appendSetting(.enablePush, enablePush ? 1 : 0)
        if let maxConcurrentStreams = maxConcurrentStreams {
            appendSetting(.maxConcurrentStreams, maxConcurrentStreams)
        }
        appendSetting(.initialWindowSize, initialWindowSize)
        appendSetting(.maxFrameSize, maxFrameSize)
        if let maxHeaderListSize = maxHeaderListSize {
            appendSetting(.maxHeaderListSize, maxHeaderListSize)
        }

        return data
    }
}

// MARK: - HTTP/2 Errors

public enum HTTP2Error: Error {
    case protocolError
    case frameSizeError
    case flowControlError
    case settingsTimeout
    case streamClosed
    case compressionError
    case inadequateSecurity
    case unknownFrameType
    case invalidStreamID
    case connectionError(HTTP2ErrorCode)
    case streamError(HTTP2ErrorCode, streamID: UInt32)

    public var errorCode: HTTP2ErrorCode {
        switch self {
        case .protocolError:
            return .protocolError
        case .frameSizeError:
            return .frameSizeError
        case .flowControlError:
            return .flowControlError
        case .settingsTimeout:
            return .settingsTimeout
        case .streamClosed:
            return .streamClosed
        case .compressionError:
            return .compressionError
        case .inadequateSecurity:
            return .inadequateSecurity
        case .connectionError(let code), .streamError(let code, _):
            return code
        default:
            return .internalError
        }
    }
}

// MARK: - HTTP/2 Constants

public enum HTTP2Constants {
    /// HTTP/2 connection preface
    public static let connectionPreface = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".data(using: .ascii)!

    /// Default max frame size
    public static let defaultMaxFrameSize: UInt32 = 16384

    /// Maximum frame size
    public static let maxFrameSize: UInt32 = 16777215

    /// Default window size
    public static let defaultWindowSize: Int = 65535

    /// Maximum window size
    public static let maxWindowSize: Int = 0x7FFFFFFF
}
