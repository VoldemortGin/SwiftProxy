import Foundation

// MARK: - WebSocket Frame

/// WebSocket frame structure as defined in RFC 6455
///
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-------+-+-------------+-------------------------------+
/// |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
/// |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
/// |N|V|V|V|       |S|             |   (if payload len==126/127)   |
/// | |1|2|3|       |K|             |                               |
/// +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
/// |     Extended payload length continued, if payload len == 127  |
/// + - - - - - - - - - - - - - - - +-------------------------------+
/// |                               |Masking-key, if MASK set to 1  |
/// +-------------------------------+-------------------------------+
/// | Masking-key (continued)       |          Payload Data         |
/// +-------------------------------- - - - - - - - - - - - - - - - +
/// :                     Payload Data continued ...                :
/// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
/// |                     Payload Data continued ...                |
/// +---------------------------------------------------------------+

// MARK: - WebSocket Opcode

/// WebSocket frame opcodes
public enum WebSocketOpcode: UInt8 {
    case continuation = 0x0
    case text = 0x1
    case binary = 0x2
    case connectionClose = 0x8
    case ping = 0x9
    case pong = 0xA

    public var isControl: Bool {
        return rawValue >= 0x8
    }

    public var isData: Bool {
        return !isControl
    }
}

// MARK: - WebSocket Close Code

/// WebSocket close status codes
public enum WebSocketCloseCode: UInt16 {
    case normal = 1000
    case goingAway = 1001
    case protocolError = 1002
    case unsupportedData = 1003
    case noStatusReceived = 1005
    case abnormalClosure = 1006
    case invalidFramePayload = 1007
    case policyViolation = 1008
    case messageTooBig = 1009
    case mandatoryExtension = 1010
    case internalServerError = 1011
    case tlsHandshake = 1015
}

// MARK: - WebSocket Frame

/// Represents a WebSocket frame
public struct WebSocketFrame {
    public let fin: Bool
    public let rsv1: Bool
    public let rsv2: Bool
    public let rsv3: Bool
    public let opcode: WebSocketOpcode
    public let masked: Bool
    public let maskingKey: Data?
    public let payload: Data

    public init(
        fin: Bool,
        rsv1: Bool = false,
        rsv2: Bool = false,
        rsv3: Bool = false,
        opcode: WebSocketOpcode,
        masked: Bool = false,
        maskingKey: Data? = nil,
        payload: Data
    ) {
        self.fin = fin
        self.rsv1 = rsv1
        self.rsv2 = rsv2
        self.rsv3 = rsv3
        self.opcode = opcode
        self.masked = masked
        self.maskingKey = maskingKey
        self.payload = payload
    }

    // MARK: - Parsing

    /// Parse WebSocket frame from data
    public static func parse(from data: Data) throws -> (frame: WebSocketFrame, bytesRead: Int) {
        guard data.count >= 2 else {
            throw WebSocketError.incompleteFrame
        }

        var offset = 0

        // First byte: FIN, RSV, Opcode
        let byte0 = data[offset]
        offset += 1

        let fin = (byte0 & 0x80) != 0
        let rsv1 = (byte0 & 0x40) != 0
        let rsv2 = (byte0 & 0x20) != 0
        let rsv3 = (byte0 & 0x10) != 0

        guard let opcode = WebSocketOpcode(rawValue: byte0 & 0x0F) else {
            throw WebSocketError.invalidOpcode
        }

        // Second byte: MASK, Payload length
        let byte1 = data[offset]
        offset += 1

        let masked = (byte1 & 0x80) != 0
        let payloadLen = byte1 & 0x7F

        // Extended payload length
        var payloadLength: UInt64 = 0

        if payloadLen == 126 {
            guard data.count >= offset + 2 else {
                throw WebSocketError.incompleteFrame
            }
            payloadLength = UInt64(data[offset]) << 8 | UInt64(data[offset + 1])
            offset += 2
        } else if payloadLen == 127 {
            guard data.count >= offset + 8 else {
                throw WebSocketError.incompleteFrame
            }
            payloadLength = UInt64(data[offset]) << 56 |
                           UInt64(data[offset + 1]) << 48 |
                           UInt64(data[offset + 2]) << 40 |
                           UInt64(data[offset + 3]) << 32 |
                           UInt64(data[offset + 4]) << 24 |
                           UInt64(data[offset + 5]) << 16 |
                           UInt64(data[offset + 6]) << 8 |
                           UInt64(data[offset + 7])
            offset += 8
        } else {
            payloadLength = UInt64(payloadLen)
        }

        // Validate control frame
        if opcode.isControl {
            guard payloadLength <= 125 else {
                throw WebSocketError.controlFrameTooLarge
            }
            guard fin else {
                throw WebSocketError.fragmentedControlFrame
            }
        }

        // Masking key
        var maskingKey: Data? = nil
        if masked {
            guard data.count >= offset + 4 else {
                throw WebSocketError.incompleteFrame
            }
            maskingKey = data.subdata(in: offset..<(offset + 4))
            offset += 4
        }

        // Payload data
        guard data.count >= offset + Int(payloadLength) else {
            throw WebSocketError.incompleteFrame
        }

        var payload = data.subdata(in: offset..<(offset + Int(payloadLength)))
        offset += Int(payloadLength)

        // Unmask payload if needed
        if let mask = maskingKey {
            payload = unmask(data: payload, mask: mask)
        }

        let frame = WebSocketFrame(
            fin: fin,
            rsv1: rsv1,
            rsv2: rsv2,
            rsv3: rsv3,
            opcode: opcode,
            masked: masked,
            maskingKey: maskingKey,
            payload: payload
        )

        return (frame, offset)
    }

    // MARK: - Serialization

    /// Serialize WebSocket frame to data
    public func serialize() -> Data {
        var data = Data()

        // First byte: FIN, RSV, Opcode
        var byte0: UInt8 = opcode.rawValue
        if fin { byte0 |= 0x80 }
        if rsv1 { byte0 |= 0x40 }
        if rsv2 { byte0 |= 0x20 }
        if rsv3 { byte0 |= 0x10 }
        data.append(byte0)

        // Second byte: MASK, Payload length
        var byte1: UInt8 = 0
        if masked { byte1 |= 0x80 }

        let payloadLength = payload.count

        if payloadLength < 126 {
            byte1 |= UInt8(payloadLength)
            data.append(byte1)
        } else if payloadLength <= 65535 {
            byte1 |= 126
            data.append(byte1)
            data.append(UInt8((payloadLength >> 8) & 0xFF))
            data.append(UInt8(payloadLength & 0xFF))
        } else {
            byte1 |= 127
            data.append(byte1)
            data.append(UInt8((payloadLength >> 56) & 0xFF))
            data.append(UInt8((payloadLength >> 48) & 0xFF))
            data.append(UInt8((payloadLength >> 40) & 0xFF))
            data.append(UInt8((payloadLength >> 32) & 0xFF))
            data.append(UInt8((payloadLength >> 24) & 0xFF))
            data.append(UInt8((payloadLength >> 16) & 0xFF))
            data.append(UInt8((payloadLength >> 8) & 0xFF))
            data.append(UInt8(payloadLength & 0xFF))
        }

        // Masking key
        if let mask = maskingKey, masked {
            data.append(mask)
            // Apply mask to payload
            let maskedPayload = WebSocketFrame.mask(data: payload, mask: mask)
            data.append(maskedPayload)
        } else {
            data.append(payload)
        }

        return data
    }

    // MARK: - Masking

    /// Mask data with XOR
    private static func mask(data: Data, mask: Data) -> Data {
        var masked = data
        for i in 0..<data.count {
            masked[i] = data[i] ^ mask[i % 4]
        }
        return masked
    }

    /// Unmask data (same as mask, XOR is reversible)
    private static func unmask(data: Data, mask: Data) -> Data {
        return Self.mask(data: data, mask: mask)
    }

    // MARK: - Factory Methods

    /// Create a text frame
    public static func text(_ text: String, fin: Bool = true, masked: Bool = false) throws -> WebSocketFrame {
        guard let data = text.data(using: .utf8) else {
            throw WebSocketError.invalidUTF8
        }

        let maskingKey = masked ? generateMaskingKey() : nil

        return WebSocketFrame(
            fin: fin,
            opcode: .text,
            masked: masked,
            maskingKey: maskingKey,
            payload: data
        )
    }

    /// Create a binary frame
    public static func binary(_ data: Data, fin: Bool = true, masked: Bool = false) -> WebSocketFrame {
        let maskingKey = masked ? generateMaskingKey() : nil

        return WebSocketFrame(
            fin: fin,
            opcode: .binary,
            masked: masked,
            maskingKey: maskingKey,
            payload: data
        )
    }

    /// Create a ping frame
    public static func ping(_ data: Data = Data(), masked: Bool = false) -> WebSocketFrame {
        let maskingKey = masked ? generateMaskingKey() : nil

        return WebSocketFrame(
            fin: true,
            opcode: .ping,
            masked: masked,
            maskingKey: maskingKey,
            payload: data
        )
    }

    /// Create a pong frame
    public static func pong(_ data: Data = Data(), masked: Bool = false) -> WebSocketFrame {
        let maskingKey = masked ? generateMaskingKey() : nil

        return WebSocketFrame(
            fin: true,
            opcode: .pong,
            masked: masked,
            maskingKey: maskingKey,
            payload: data
        )
    }

    /// Create a close frame
    public static func close(code: WebSocketCloseCode = .normal, reason: String = "", masked: Bool = false) throws -> WebSocketFrame {
        var payload = Data()

        // Add close code
        payload.append(UInt8((code.rawValue >> 8) & 0xFF))
        payload.append(UInt8(code.rawValue & 0xFF))

        // Add reason (UTF-8)
        if !reason.isEmpty {
            guard let reasonData = reason.data(using: .utf8) else {
                throw WebSocketError.invalidUTF8
            }
            payload.append(reasonData)
        }

        let maskingKey = masked ? generateMaskingKey() : nil

        return WebSocketFrame(
            fin: true,
            opcode: .connectionClose,
            masked: masked,
            maskingKey: maskingKey,
            payload: payload
        )
    }

    /// Generate random 4-byte masking key
    private static func generateMaskingKey() -> Data {
        var key = Data(count: 4)
        for i in 0..<4 {
            key[i] = UInt8.random(in: 0...255)
        }
        return key
    }

    // MARK: - Payload Helpers

    /// Get payload as text (for text frames)
    public func payloadText() throws -> String {
        guard let text = String(data: payload, encoding: .utf8) else {
            throw WebSocketError.invalidUTF8
        }
        return text
    }

    /// Get close code and reason (for close frames)
    public func closeInfo() -> (code: WebSocketCloseCode?, reason: String?) {
        guard opcode == .connectionClose, payload.count >= 2 else {
            return (nil, nil)
        }

        let codeValue = UInt16(payload[0]) << 8 | UInt16(payload[1])
        let code = WebSocketCloseCode(rawValue: codeValue)

        var reason: String? = nil
        if payload.count > 2 {
            let reasonData = payload.subdata(in: 2..<payload.count)
            reason = String(data: reasonData, encoding: .utf8)
        }

        return (code, reason)
    }
}

// MARK: - WebSocket Errors

public enum WebSocketError: Error {
    case incompleteFrame
    case invalidOpcode
    case controlFrameTooLarge
    case fragmentedControlFrame
    case invalidUTF8
    case messageTooBig
    case protocolError
    case unsupportedExtension
    case handshakeFailed
    case connectionClosed

    public var closeCode: WebSocketCloseCode {
        switch self {
        case .invalidOpcode, .fragmentedControlFrame:
            return .protocolError
        case .controlFrameTooLarge, .messageTooBig:
            return .messageTooBig
        case .invalidUTF8:
            return .invalidFramePayload
        case .unsupportedExtension:
            return .mandatoryExtension
        default:
            return .internalServerError
        }
    }
}

// MARK: - WebSocket Message

/// Represents a complete WebSocket message (may consist of multiple frames)
public struct WebSocketMessage {
    public let opcode: WebSocketOpcode
    public let data: Data

    public init(opcode: WebSocketOpcode, data: Data) {
        self.opcode = opcode
        self.data = data
    }

    /// Get message as text
    public func asText() throws -> String {
        guard let text = String(data: data, encoding: .utf8) else {
            throw WebSocketError.invalidUTF8
        }
        return text
    }
}

// MARK: - WebSocket Message Fragmenter

/// Handles WebSocket message fragmentation and assembly
public actor WebSocketFragmenter {
    private var fragmentBuffer: Data?
    private var fragmentOpcode: WebSocketOpcode?

    public init() {}

    /// Process a frame and return complete message if available
    public func processFrame(_ frame: WebSocketFrame) throws -> WebSocketMessage? {
        // Control frames are never fragmented
        if frame.opcode.isControl {
            return WebSocketMessage(opcode: frame.opcode, data: frame.payload)
        }

        // Start of new message
        if frame.opcode != .continuation {
            // If we have buffered data, that's an error
            guard fragmentBuffer == nil else {
                throw WebSocketError.protocolError
            }

            if frame.fin {
                // Complete message in single frame
                return WebSocketMessage(opcode: frame.opcode, data: frame.payload)
            } else {
                // Start of fragmented message
                fragmentOpcode = frame.opcode
                fragmentBuffer = frame.payload
                return nil
            }
        }

        // Continuation frame
        guard var buffer = fragmentBuffer, let opcode = fragmentOpcode else {
            throw WebSocketError.protocolError
        }

        buffer.append(frame.payload)

        if frame.fin {
            // Last fragment - complete message
            fragmentBuffer = nil
            fragmentOpcode = nil
            return WebSocketMessage(opcode: opcode, data: buffer)
        } else {
            // More fragments coming
            fragmentBuffer = buffer
            return nil
        }
    }

    /// Clear any buffered fragments
    public func reset() {
        fragmentBuffer = nil
        fragmentOpcode = nil
    }
}
