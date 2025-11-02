import Foundation
import Network
import OSLog

/// Handles low-level packet processing for network traffic
/// Performs packet inspection, modification, and routing based on proxy rules
@available(macOS 12.0, *)
public actor PacketHandler {
    // MARK: - Properties

    private let logger: OSLog
    private var rules: [ProxyRule] = []
    private var statistics: PacketStatistics = PacketStatistics()

    // Packet buffer for reassembly
    private var packetBuffer: [UUID: PacketBuffer] = [:]

    // Maximum buffer size to prevent memory issues
    private let maxBufferSize: Int = 10 * 1024 * 1024 // 10MB

    // MARK: - Initialization

    public init(logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "PacketHandler")) {
        self.logger = logger
    }

    // MARK: - Rule Management

    /// Update the proxy rules used for packet routing decisions
    public func updateRules(_ rules: [ProxyRule]) {
        self.rules = rules.sorted() // Sort by priority
        os_log(.info, log: logger, "Updated packet handler rules: %d rules", rules.count)
    }

    /// Add a single rule
    public func addRule(_ rule: ProxyRule) {
        rules.append(rule)
        rules.sort()
        os_log(.debug, log: logger, "Added rule: %@", rule.name)
    }

    /// Remove a rule by ID
    public func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
        os_log(.debug, log: logger, "Removed rule: %@", id.uuidString)
    }

    // MARK: - Packet Processing

    /// Process an incoming packet and determine routing action
    public func processPacket(_ packet: Data, protocolFamily: Int32) async throws -> ProcessedPacket {
        statistics.totalPackets += 1
        statistics.totalBytes += Int64(packet.count)

        // Parse packet based on protocol family
        let parsedPacket: ParsedPacket

        switch protocolFamily {
        case AF_INET: // IPv4
            parsedPacket = try parseIPv4Packet(packet)

        case AF_INET6: // IPv6
            parsedPacket = try parseIPv6Packet(packet)

        default:
            throw AppError.invalidState("Unsupported protocol family: \(protocolFamily)")
        }

        // Match against rules
        let action = matchRules(for: parsedPacket)

        // Create processed packet with routing decision
        let processed = ProcessedPacket(
            originalPacket: packet,
            parsedPacket: parsedPacket,
            action: action,
            timestamp: Date()
        )

        // Update statistics
        updateStatistics(for: processed)

        return processed
    }

    /// Process a batch of packets for better performance
    public func processBatch(_ packets: [(Data, Int32)]) async throws -> [ProcessedPacket] {
        var results: [ProcessedPacket] = []

        for (packet, protocolFamily) in packets {
            do {
                let processed = try await processPacket(packet, protocolFamily: protocolFamily)
                results.append(processed)
            } catch {
                os_log(.error, log: logger, "Failed to process packet: %@", error.localizedDescription)
                statistics.droppedPackets += 1
            }
        }

        return results
    }

    // MARK: - Packet Parsing

    private func parseIPv4Packet(_ data: Data) throws -> ParsedPacket {
        guard data.count >= 20 else {
            throw AppError.invalidState("IPv4 packet too small")
        }

        // Parse IPv4 header
        let versionIHL = data[0]
        let version = (versionIHL >> 4) & 0x0F
        let ihl = (versionIHL & 0x0F) * 4

        guard version == 4 else {
            throw AppError.invalidState("Invalid IPv4 version: \(version)")
        }

        let `protocol` = data[9]
        let sourceIP = formatIPv4Address(data[12..<16])
        let destIP = formatIPv4Address(data[16..<20])

        // Parse transport layer protocol
        var sourcePort: UInt16 = 0
        var destPort: UInt16 = 0
        var payload = Data()

        let headerEnd = Int(ihl)
        guard data.count >= headerEnd else {
            throw AppError.invalidState("IPv4 packet header incomplete")
        }

        let transportData = data[headerEnd...]

        switch `protocol` {
        case 6: // TCP
            (sourcePort, destPort, payload) = try parseTCPSegment(transportData)

        case 17: // UDP
            (sourcePort, destPort, payload) = try parseUDPDatagram(transportData)

        default:
            break
        }

        return ParsedPacket(
            version: .ipv4,
            protocol: IPProtocol(rawValue: `protocol`) ?? .unknown,
            sourceAddress: sourceIP,
            destinationAddress: destIP,
            sourcePort: sourcePort,
            destinationPort: destPort,
            payload: payload,
            totalLength: data.count
        )
    }

    private func parseIPv6Packet(_ data: Data) throws -> ParsedPacket {
        guard data.count >= 40 else {
            throw AppError.invalidState("IPv6 packet too small")
        }

        // Parse IPv6 header
        let versionClassFlow = UInt32(data[0]) << 24 | UInt32(data[1]) << 16 | UInt32(data[2]) << 8 | UInt32(data[3])
        let version = (versionClassFlow >> 28) & 0x0F

        guard version == 6 else {
            throw AppError.invalidState("Invalid IPv6 version: \(version)")
        }

        let nextHeader = data[6]
        let sourceIP = formatIPv6Address(data[8..<24])
        let destIP = formatIPv6Address(data[24..<40])

        // Parse transport layer
        var sourcePort: UInt16 = 0
        var destPort: UInt16 = 0
        var payload = Data()

        let transportData = data[40...]

        switch nextHeader {
        case 6: // TCP
            (sourcePort, destPort, payload) = try parseTCPSegment(transportData)

        case 17: // UDP
            (sourcePort, destPort, payload) = try parseUDPDatagram(transportData)

        default:
            break
        }

        return ParsedPacket(
            version: .ipv6,
            protocol: IPProtocol(rawValue: nextHeader) ?? .unknown,
            sourceAddress: sourceIP,
            destinationAddress: destIP,
            sourcePort: sourcePort,
            destinationPort: destPort,
            payload: payload,
            totalLength: data.count
        )
    }

    private func parseTCPSegment(_ data: Data) throws -> (UInt16, UInt16, Data) {
        guard data.count >= 20 else {
            throw AppError.invalidState("TCP segment too small")
        }

        let sourcePort = UInt16(data[0]) << 8 | UInt16(data[1])
        let destPort = UInt16(data[2]) << 8 | UInt16(data[3])

        let dataOffset = (data[12] >> 4) * 4
        let headerEnd = Int(dataOffset)

        let payload = data.count > headerEnd ? data[headerEnd...] : Data()

        return (sourcePort, destPort, Data(payload))
    }

    private func parseUDPDatagram(_ data: Data) throws -> (UInt16, UInt16, Data) {
        guard data.count >= 8 else {
            throw AppError.invalidState("UDP datagram too small")
        }

        let sourcePort = UInt16(data[0]) << 8 | UInt16(data[1])
        let destPort = UInt16(data[2]) << 8 | UInt16(data[3])

        let payload = data.count > 8 ? data[8...] : Data()

        return (sourcePort, destPort, Data(payload))
    }

    // MARK: - Rule Matching

    private func matchRules(for packet: ParsedPacket) -> RuleAction {
        // Create a network request from the packet for rule matching
        guard let url = createURL(from: packet) else {
            return .direct // Default to direct if we can't create a URL
        }

        let request = NetworkRequest(
            method: .GET,
            url: url,
            processName: nil
        )

        // Find first matching rule
        for rule in rules where rule.enabled {
            // Extract host from URL for rule matching
            let host = url.host ?? packet.destinationAddress
            let ip = packet.destinationAddress
            let port = Int(packet.destinationPort)

            if rule.matches(host: host, ip: ip, port: port) {
                os_log(.debug, log: logger, "Packet matched rule: %@ -> %@", rule.name, rule.action.rawValue)
                return rule.action
            }
        }

        // No rule matched, use default action
        return .direct
    }

    private func createURL(from packet: ParsedPacket) -> URL? {
        // For HTTP/HTTPS traffic, try to parse the payload
        if packet.destinationPort == 80 || packet.destinationPort == 443 {
            if let urlString = extractURLFromHTTP(packet.payload) {
                return URL(string: urlString)
            }
        }

        // Fallback to creating a generic URL
        let scheme = packet.destinationPort == 443 ? "https" : "http"
        let urlString = "\(scheme)://\(packet.destinationAddress):\(packet.destinationPort)/"
        return URL(string: urlString)
    }

    private func extractURLFromHTTP(_ payload: Data) -> String? {
        guard let httpString = String(data: payload, encoding: .utf8) else {
            return nil
        }

        // Look for HTTP request line
        let lines = httpString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return nil
        }

        // Parse: GET /path HTTP/1.1
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            return nil
        }

        // Look for Host header
        for line in lines.dropFirst() {
            if line.lowercased().hasPrefix("host:") {
                let host = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                let path = parts[1]
                let scheme = "http" // Will be upgraded to https if needed
                return "\(scheme)://\(host)\(path)"
            }
        }

        return nil
    }

    // MARK: - Packet Buffering

    /// Buffer packets for reassembly (useful for fragmented packets)
    public func bufferPacket(_ packet: Data, connectionID: UUID) async {
        if packetBuffer[connectionID] == nil {
            packetBuffer[connectionID] = PacketBuffer(connectionID: connectionID)
        }

        packetBuffer[connectionID]?.add(packet)

        // Clean up old buffers
        await cleanupBuffers()
    }

    /// Get buffered packets for a connection
    public func getBufferedPackets(for connectionID: UUID) -> [Data]? {
        return packetBuffer[connectionID]?.packets
    }

    /// Clear buffer for a connection
    public func clearBuffer(for connectionID: UUID) {
        packetBuffer.removeValue(forKey: connectionID)
    }

    private func cleanupBuffers() async {
        let now = Date()
        let timeout: TimeInterval = 60 // 1 minute

        packetBuffer = packetBuffer.filter { _, buffer in
            now.timeIntervalSince(buffer.createdAt) < timeout
        }
    }

    // MARK: - Statistics

    private func updateStatistics(for packet: ProcessedPacket) {
        switch packet.action {
        case .direct:
            statistics.directPackets += 1
        case .proxy:
            statistics.proxiedPackets += 1
        case .reject:
            statistics.rejectedPackets += 1
        case .modify:
            statistics.proxiedPackets += 1 // Count modified packets as proxied
        case .proxyServer:
            statistics.proxiedPackets += 1 // Count specific proxy server as proxied
        }

        statistics.lastProcessedAt = Date()
    }

    public func getStatistics() -> PacketStatistics {
        return statistics
    }

    public func resetStatistics() {
        statistics = PacketStatistics()
    }

    // MARK: - Helper Methods

    private func formatIPv4Address(_ data: Data) -> String {
        data.map { String($0) }.joined(separator: ".")
    }

    private func formatIPv6Address(_ data: Data) -> String {
        var parts: [String] = []
        for i in stride(from: 0, to: 16, by: 2) {
            let value = UInt16(data[i]) << 8 | UInt16(data[i + 1])
            parts.append(String(format: "%x", value))
        }
        return parts.joined(separator: ":")
    }
}

// MARK: - Supporting Types

public struct ParsedPacket {
    public let version: IPVersion
    public let `protocol`: IPProtocol
    public let sourceAddress: String
    public let destinationAddress: String
    public let sourcePort: UInt16
    public let destinationPort: UInt16
    public let payload: Data
    public let totalLength: Int

    public var description: String {
        "\(sourceAddress):\(sourcePort) -> \(destinationAddress):\(destinationPort) [\(`protocol`)]"
    }
}

public struct ProcessedPacket {
    public let originalPacket: Data
    public let parsedPacket: ParsedPacket
    public let action: RuleAction
    public let timestamp: Date

    public var shouldProxy: Bool {
        action == .proxy
    }

    public var shouldReject: Bool {
        action == .reject
    }
}

public enum IPVersion {
    case ipv4
    case ipv6
}

public enum IPProtocol: UInt8 {
    case icmp = 1
    case tcp = 6
    case udp = 17
    case icmpv6 = 58
    case unknown = 255
}

public struct PacketStatistics: Codable {
    public var totalPackets: Int = 0
    public var totalBytes: Int64 = 0
    public var directPackets: Int = 0
    public var proxiedPackets: Int = 0
    public var rejectedPackets: Int = 0
    public var droppedPackets: Int = 0
    public var lastProcessedAt: Date?

    public var packetsPerSecond: Double {
        guard let lastProcessed = lastProcessedAt else { return 0 }
        let duration = Date().timeIntervalSince(lastProcessed)
        guard duration > 0 else { return 0 }
        return Double(totalPackets) / duration
    }
}

struct PacketBuffer {
    let connectionID: UUID
    var packets: [Data] = []
    let createdAt: Date = Date()
    private var totalSize: Int = 0

    init(connectionID: UUID) {
        self.connectionID = connectionID
    }

    mutating func add(_ packet: Data) {
        packets.append(packet)
        totalSize += packet.count
    }

    var size: Int {
        totalSize
    }
}
