import Foundation
import Network
import OSLog

/// Handles low-level packet processing for network traffic
/// Performs packet inspection, modification, and routing based on proxy rules
/// Features: Advanced buffering, traffic shaping, packet size optimization
@available(macOS 12.0, *)
public actor PacketHandler {
    // MARK: - Properties

    private let logger: OSLog
    private var rules: [ProxyRule] = []
    private var statistics: PacketStatistics = PacketStatistics()

    // Packet buffer for reassembly
    private var packetBuffer: [UUID: AdvancedPacketBuffer] = [:]

    // Maximum buffer size to prevent memory issues
    private let maxBufferSize: Int

    // Traffic Shaping
    private let trafficShaper: TrafficShaper

    // Packet Size Optimizer
    private let sizeOptimizer: PacketSizeOptimizer

    // Buffer Pool for efficient memory management
    private let bufferPool: BufferPool

    // MARK: - Initialization

    /// Initialize PacketHandler with optional custom configuration
    /// - Parameters:
    ///   - logger: OSLog instance for logging
    ///   - maxBufferSize: Maximum buffer size in bytes (default 10MB)
    ///   - trafficShapingConfig: Configuration for traffic shaping
    public init(
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "PacketHandler"),
        maxBufferSize: Int = 10 * 1024 * 1024,
        trafficShapingConfig: TrafficShapingConfig = .default
    ) {
        self.logger = logger
        self.maxBufferSize = maxBufferSize
        self.trafficShaper = TrafficShaper(config: trafficShapingConfig, logger: logger)
        self.sizeOptimizer = PacketSizeOptimizer(logger: logger)
        self.bufferPool = BufferPool(bufferSize: 65536, maxPoolSize: 100, logger: logger)
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
        // Create URL from packet for rule matching
        guard let url = createURL(from: packet) else {
            return .direct // Default to direct if we can't create a URL
        }

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

    // MARK: - Advanced Packet Buffering

    /// Buffer packets for reassembly with intelligent memory management
    /// Supports fragmented packets, out-of-order delivery, and automatic coalescing
    public func bufferPacket(_ packet: Data, connectionID: UUID, sequenceNumber: UInt32 = 0) async throws {
        // Check traffic shaping constraints before buffering
        guard await trafficShaper.allowPacket(size: packet.count) else {
            statistics.droppedPackets += 1
            os_log(.debug, log: logger, "Packet dropped by traffic shaper (connection: %@)", connectionID.uuidString)
            throw AppError.invalidState("Traffic limit exceeded")
        }

        if packetBuffer[connectionID] == nil {
            packetBuffer[connectionID] = AdvancedPacketBuffer(
                connectionID: connectionID,
                maxSize: maxBufferSize,
                bufferPool: bufferPool
            )
        }

        guard let buffer = packetBuffer[connectionID] else {
            throw AppError.invalidState("Failed to create packet buffer")
        }

        // Add packet with sequence number for ordering
        try await buffer.add(packet, sequenceNumber: sequenceNumber)

        // Check if buffer size limit is exceeded
        if await buffer.totalSize > maxBufferSize {
            os_log(.default, log: logger, "⚠️ Buffer for connection %@ exceeded max size", connectionID.uuidString)
            statistics.droppedPackets += 1
            throw AppError.invalidState("Buffer size limit exceeded")
        }

        // Clean up old buffers periodically
        await cleanupBuffers()
    }

    /// Get buffered packets for a connection in order
    public func getBufferedPackets(for connectionID: UUID) async -> [Data] {
        guard let buffer = packetBuffer[connectionID] else {
            return []
        }
        return await buffer.getOrderedPackets()
    }

    /// Get coalesced (merged) buffer for a connection
    public func getCoalescedBuffer(for connectionID: UUID) async -> Data? {
        guard let buffer = packetBuffer[connectionID] else {
            return nil
        }
        return await buffer.coalesce()
    }

    /// Clear buffer for a connection and return pooled memory
    public func clearBuffer(for connectionID: UUID) async {
        if let buffer = packetBuffer.removeValue(forKey: connectionID) {
            await buffer.release()
        }
    }

    /// Cleanup stale buffers and return memory to pool
    private func cleanupBuffers() async {
        let now = Date()
        let timeout: TimeInterval = 60 // 1 minute

        var toRemove: [UUID] = []
        for (id, buffer) in packetBuffer {
            if now.timeIntervalSince(buffer.createdAt) > timeout {
                toRemove.append(id)
                await buffer.release()
            }
        }

        for id in toRemove {
            packetBuffer.removeValue(forKey: id)
            os_log(.debug, log: logger, "Cleaned up stale buffer for connection %@", id.uuidString)
        }
    }

    // MARK: - Traffic Shaping

    /// Apply traffic shaping to control packet flow rate
    public func shapeTraffic(for connectionID: UUID, priorityClass: TrafficPriorityClass = .normal) async throws {
        try await trafficShaper.shape(connectionID: connectionID, priority: priorityClass)
    }

    /// Update traffic shaping configuration
    public func updateTrafficShaping(config: TrafficShapingConfig) async {
        await trafficShaper.updateConfig(config)
    }

    /// Get current traffic shaping statistics
    public func getTrafficShapingStats() async -> TrafficShapingStatistics {
        await trafficShaper.getStatistics()
    }

    // MARK: - Packet Size Optimization

    /// Optimize packet size based on connection characteristics
    public func optimizePacketSize(for connectionID: UUID, data: Data) async -> [Data] {
        return await sizeOptimizer.optimize(data: data, connectionID: connectionID)
    }

    /// Update MTU (Maximum Transmission Unit) for a connection
    public func updateMTU(for connectionID: UUID, mtu: Int) async {
        await sizeOptimizer.updateMTU(connectionID: connectionID, mtu: mtu)
    }

    /// Get optimal packet size for a connection
    public func getOptimalPacketSize(for connectionID: UUID) async -> Int {
        await sizeOptimizer.getOptimalSize(connectionID: connectionID)
    }

    /// Enable/disable Nagle-like algorithm for small packet coalescing
    public func setNagleEnabled(_ enabled: Bool, for connectionID: UUID) async {
        await sizeOptimizer.setNagleEnabled(enabled, connectionID: connectionID)
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

// MARK: - Advanced Packet Buffer

/// Advanced packet buffer with support for out-of-order packets, memory pooling, and auto-coalescing
actor AdvancedPacketBuffer {
    struct PacketEntry {
        let data: Data
        let sequenceNumber: UInt32
        let timestamp: Date
    }

    let connectionID: UUID
    let createdAt: Date = Date()
    private var packets: [PacketEntry] = []
    private var maxSize: Int
    private weak var bufferPool: BufferPool?
    private var _totalSize: Int = 0

    var totalSize: Int {
        _totalSize
    }

    init(connectionID: UUID, maxSize: Int, bufferPool: BufferPool) {
        self.connectionID = connectionID
        self.maxSize = maxSize
        self.bufferPool = bufferPool
    }

    /// Add packet with sequence number for ordering
    func add(_ packet: Data, sequenceNumber: UInt32) throws {
        guard _totalSize + packet.count <= maxSize else {
            throw AppError.invalidState("Buffer size exceeded")
        }

        let entry = PacketEntry(
            data: packet,
            sequenceNumber: sequenceNumber,
            timestamp: Date()
        )
        packets.append(entry)
        _totalSize += packet.count
    }

    /// Get packets in sequence order
    func getOrderedPackets() -> [Data] {
        packets.sorted { $0.sequenceNumber < $1.sequenceNumber }.map { $0.data }
    }

    /// Coalesce all packets into a single Data buffer
    func coalesce() -> Data {
        let ordered = getOrderedPackets()
        var result = Data(capacity: _totalSize)
        for packet in ordered {
            result.append(packet)
        }
        return result
    }

    /// Release all buffers back to pool
    func release() async {
        if let pool = bufferPool {
            for entry in packets {
                await pool.release(entry.data)
            }
        }
        packets.removeAll()
        _totalSize = 0
    }
}

// MARK: - Traffic Shaping

/// Traffic shaping configuration
public struct TrafficShapingConfig {
    public let maxBytesPerSecond: Int64
    public let burstSize: Int64
    public let enablePriorityQueues: Bool
    public let queueCount: Int

    public static let `default` = TrafficShapingConfig(
        maxBytesPerSecond: 10_000_000, // 10 MB/s
        burstSize: 1_000_000, // 1 MB
        enablePriorityQueues: true,
        queueCount: 3
    )

    public init(maxBytesPerSecond: Int64, burstSize: Int64, enablePriorityQueues: Bool, queueCount: Int) {
        self.maxBytesPerSecond = maxBytesPerSecond
        self.burstSize = burstSize
        self.enablePriorityQueues = enablePriorityQueues
        self.queueCount = queueCount
    }
}

/// Traffic priority classes
public enum TrafficPriorityClass: Int {
    case high = 0
    case normal = 1
    case low = 2

    var weight: Double {
        switch self {
        case .high: return 3.0
        case .normal: return 2.0
        case .low: return 1.0
        }
    }
}

/// Traffic shaper using token bucket algorithm with priority queues
actor TrafficShaper {
    private var config: TrafficShapingConfig
    private let logger: OSLog

    // Token bucket state
    private var availableTokens: Int64
    private var lastRefillTime: Date

    // Priority queues for packet scheduling
    private var queues: [[UUID]] = []

    // Statistics
    private var statistics = TrafficShapingStatistics()

    init(config: TrafficShapingConfig, logger: OSLog) {
        self.config = config
        self.logger = logger
        self.availableTokens = config.burstSize
        self.lastRefillTime = Date()

        // Initialize priority queues
        for _ in 0..<config.queueCount {
            queues.append([])
        }
    }

    /// Check if packet is allowed under traffic shaping constraints
    func allowPacket(size: Int) async -> Bool {
        refillTokens()

        guard availableTokens >= Int64(size) else {
            statistics.droppedPackets += 1
            statistics.totalDroppedBytes += Int64(size)
            return false
        }

        availableTokens -= Int64(size)
        statistics.passedPackets += 1
        statistics.totalPassedBytes += Int64(size)
        return true
    }

    /// Apply traffic shaping with priority
    func shape(connectionID: UUID, priority: TrafficPriorityClass) async throws {
        if config.enablePriorityQueues {
            let queueIndex = min(priority.rawValue, queues.count - 1)
            queues[queueIndex].append(connectionID)
        }

        // Wait for tokens if needed
        while availableTokens < config.burstSize / 10 {
            let waitTime = calculateWaitTime()
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            refillTokens()
        }
    }

    /// Update configuration
    func updateConfig(_ newConfig: TrafficShapingConfig) {
        self.config = newConfig
        os_log(.info, log: logger, "Traffic shaping config updated: %lld bytes/s", newConfig.maxBytesPerSecond)
    }

    /// Get statistics
    func getStatistics() -> TrafficShapingStatistics {
        statistics
    }

    // MARK: - Private Methods

    private func refillTokens() {
        let now = Date()
        let timePassed = now.timeIntervalSince(lastRefillTime)
        let tokensToAdd = Int64(Double(config.maxBytesPerSecond) * timePassed)

        availableTokens = min(config.burstSize, availableTokens + tokensToAdd)
        lastRefillTime = now
    }

    private func calculateWaitTime() -> TimeInterval {
        let tokensNeeded = config.burstSize / 10 - availableTokens
        return Double(tokensNeeded) / Double(config.maxBytesPerSecond)
    }
}

public struct TrafficShapingStatistics: Codable {
    public var passedPackets: Int = 0
    public var droppedPackets: Int = 0
    public var totalPassedBytes: Int64 = 0
    public var totalDroppedBytes: Int64 = 0

    public var dropRate: Double {
        let total = passedPackets + droppedPackets
        guard total > 0 else { return 0 }
        return Double(droppedPackets) / Double(total)
    }
}

// MARK: - Packet Size Optimizer

/// Optimizes packet sizes based on connection characteristics and MTU
actor PacketSizeOptimizer {
    private let logger: OSLog

    // Connection-specific settings
    private var mtuCache: [UUID: Int] = [:]
    private var nagleEnabled: [UUID: Bool] = [:]
    private var smallPacketBuffer: [UUID: Data] = [:]

    // Constants
    private let defaultMTU = 1500
    private let minPacketSize = 64
    private let nagleTimeout: TimeInterval = 0.2 // 200ms
    private let smallPacketThreshold = 512

    init(logger: OSLog) {
        self.logger = logger
    }

    /// Optimize data into appropriately sized packets
    func optimize(data: Data, connectionID: UUID) -> [Data] {
        let mtu = mtuCache[connectionID] ?? defaultMTU
        let optimalSize = calculateOptimalSize(mtu: mtu)

        // Check if Nagle is enabled and packet is small
        if nagleEnabled[connectionID] ?? false && data.count < smallPacketThreshold {
            return coalesceSmallPacket(data: data, connectionID: connectionID, optimalSize: optimalSize)
        }

        // Split data into optimal-sized packets
        return splitIntoPackets(data: data, size: optimalSize)
    }

    /// Update MTU for a connection
    func updateMTU(connectionID: UUID, mtu: Int) {
        mtuCache[connectionID] = mtu
        os_log(.info, log: logger, "Updated MTU for connection %@: %d", connectionID.uuidString, mtu)
    }

    /// Get optimal packet size
    func getOptimalSize(connectionID: UUID) -> Int {
        let mtu = mtuCache[connectionID] ?? defaultMTU
        return calculateOptimalSize(mtu: mtu)
    }

    /// Enable/disable Nagle algorithm
    func setNagleEnabled(_ enabled: Bool, connectionID: UUID) {
        nagleEnabled[connectionID] = enabled
        os_log(.debug, log: logger, "Nagle algorithm %@ for connection %@",
               enabled ? "enabled" : "disabled", connectionID.uuidString)
    }

    // MARK: - Private Methods

    private func calculateOptimalSize(mtu: Int) -> Int {
        // Account for IP header (20 bytes) and TCP header (20-60 bytes)
        let headerOverhead = 60
        return max(minPacketSize, mtu - headerOverhead)
    }

    private func splitIntoPackets(data: Data, size: Int) -> [Data] {
        var packets: [Data] = []
        var offset = 0

        while offset < data.count {
            let length = min(size, data.count - offset)
            let packet = data.subdata(in: offset..<(offset + length))
            packets.append(packet)
            offset += length
        }

        return packets
    }

    private func coalesceSmallPacket(data: Data, connectionID: UUID, optimalSize: Int) -> [Data] {
        // Add to buffer
        if var buffered = smallPacketBuffer[connectionID] {
            buffered.append(data)
            smallPacketBuffer[connectionID] = buffered

            // Check if buffer is large enough to send
            if buffered.count >= optimalSize {
                let result = smallPacketBuffer.removeValue(forKey: connectionID)!
                return [result]
            }
        } else {
            smallPacketBuffer[connectionID] = data
        }

        // Return empty array - data is buffered
        return []
    }

    /// Flush buffered small packets for a connection
    func flushBufferedPackets(connectionID: UUID) -> Data? {
        smallPacketBuffer.removeValue(forKey: connectionID)
    }
}
