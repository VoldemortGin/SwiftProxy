import Foundation
import Network
import NetworkExtension
import OSLog

/// Intercepts and analyzes network traffic at the system level
/// Captures packets, extracts metadata, and forwards to the proxy engine
@available(macOS 12.0, *)
public actor TrafficInterceptor {
    // MARK: - Properties

    private let logger: OSLog
    private let packetHandler: PacketHandler
    private var isIntercepting: Bool = false

    // Traffic observers
    private var observers: [any TrafficObserver] = []

    // Statistics
    private var statistics: InterceptorStatistics = InterceptorStatistics()

    // Flow tracking
    private var activeFlows: [FlowIdentifier: NetworkFlow] = [:]

    // Rate limiting
    private let rateLimiter: RateLimiter

    // MARK: - Initialization

    public init(
        packetHandler: PacketHandler,
        logger: OSLog = Logger.networkLog
    ) {
        self.packetHandler = packetHandler
        self.logger = logger
        self.rateLimiter = RateLimiter(capacity: 10000, refillRate: 10000)
    }

    // MARK: - Interception Control

    /// Start intercepting network traffic
    public func startIntercepting() async throws {
        guard !isIntercepting else {
            os_log(.default, log: logger, "Traffic interception is already active")
            return
        }

        os_log(.info, log: logger, "Starting traffic interception")

        isIntercepting = true
        statistics.startTime = Date()

        os_log(.info, log: logger, "Traffic interception started")
    }

    /// Stop intercepting network traffic
    public func stopIntercepting() async {
        guard isIntercepting else {
            os_log(.default, log: logger, "Traffic interception is not active")
            return
        }

        os_log(.info, log: logger, "Stopping traffic interception")

        isIntercepting = false

        // Close all active flows
        for (_, flow) in activeFlows {
            await closeFlow(flow)
        }
        activeFlows.removeAll()

        os_log(.info, log: logger, "Traffic interception stopped")
    }

    // MARK: - Packet Interception

    /// Intercept and process a network packet
    public func interceptPacket(_ packet: Data, protocolFamily: Int32) async throws -> InterceptResult {
        guard isIntercepting else {
            return .allow // Pass through if not intercepting
        }

        // Apply rate limiting
        guard await rateLimiter.checkRateLimit() else {
            statistics.droppedPackets += 1
            os_log(.default, log: logger, "Packet dropped due to rate limiting")
            return .drop
        }

        statistics.totalPackets += 1
        statistics.totalBytes += Int64(packet.count)

        // Process packet
        let processed = try await packetHandler.processPacket(packet, protocolFamily: protocolFamily)

        // Track flow
        let flowID = FlowIdentifier(from: processed.parsedPacket)
        await trackFlow(flowID, packet: processed.parsedPacket)

        // Notify observers
        await notifyObservers(packet: processed)

        // Determine action
        let result: InterceptResult

        switch processed.action {
        case .direct:
            result = .allow
            statistics.allowedPackets += 1

        case .proxy:
            result = .proxy(processed.originalPacket)
            statistics.proxiedPackets += 1

        case .reject:
            result = .drop
            statistics.rejectedPackets += 1

        case .modify:
            result = .modify(processed.originalPacket)
            statistics.proxiedPackets += 1

        case .proxyServer:
            result = .proxy(processed.originalPacket)
            statistics.proxiedPackets += 1
        }

        return result
    }

    /// Intercept a new network flow
    public func interceptFlow(_ flow: NWConnection.State) async {
        guard isIntercepting else { return }

        os_log(.debug, log: logger, "New flow intercepted")
        statistics.totalFlows += 1
    }

    // MARK: - Flow Tracking

    private func trackFlow(_ identifier: FlowIdentifier, packet: ParsedPacket) async {
        if var flow = activeFlows[identifier] {
            // Update existing flow
            flow.packetCount += 1
            flow.totalBytes += Int64(packet.totalLength)
            flow.lastActivity = Date()
            activeFlows[identifier] = flow
        } else {
            // Create new flow
            let flow = NetworkFlow(
                identifier: identifier,
                startTime: Date(),
                lastActivity: Date(),
                sourceAddress: packet.sourceAddress,
                destinationAddress: packet.destinationAddress,
                sourcePort: packet.sourcePort,
                destinationPort: packet.destinationPort,
                protocol: packet.protocol
            )
            activeFlows[identifier] = flow
            statistics.activeFlows = activeFlows.count
        }

        // Clean up stale flows periodically
        await cleanupStaleFlows()
    }

    private func closeFlow(_ flow: NetworkFlow) async {
        let duration = Date().timeIntervalSince(flow.startTime)
        os_log(.debug, log: logger, "Flow closed: %{public}@ (duration: %fs, packets: %d)",
               String(describing: flow.identifier), duration, flow.packetCount)

        activeFlows.removeValue(forKey: flow.identifier)
        statistics.activeFlows = activeFlows.count
    }

    private func cleanupStaleFlows() async {
        let now = Date()
        let staleThreshold: TimeInterval = 300 // 5 minutes

        var staleFlows: [FlowIdentifier] = []

        for (id, flow) in activeFlows {
            if now.timeIntervalSince(flow.lastActivity) > staleThreshold {
                staleFlows.append(id)
            }
        }

        for id in staleFlows {
            if let flow = activeFlows.removeValue(forKey: id) {
                await closeFlow(flow)
            }
        }

        if !staleFlows.isEmpty {
            os_log(.debug, log: logger, "Cleaned up %d stale flows", staleFlows.count)
        }
    }

    // MARK: - Observer Management

    /// Register a traffic observer
    public func addObserver(_ observer: any TrafficObserver) {
        observers.append(observer)
        os_log(.debug, log: logger, "Added traffic observer")
    }

    /// Unregister a traffic observer
    public func removeObserver(_ observer: any TrafficObserver) {
        observers.removeAll { $0.id == observer.id }
        os_log(.debug, log: logger, "Removed traffic observer")
    }

    private func notifyObservers(packet: ProcessedPacket) async {
        for observer in observers {
            await observer.didInterceptPacket(packet)
        }
    }

    // MARK: - Statistics

    public func getStatistics() -> InterceptorStatistics {
        var stats = statistics
        stats.activeFlows = activeFlows.count
        return stats
    }

    public func resetStatistics() {
        statistics = InterceptorStatistics()
        statistics.startTime = Date()
    }

    // MARK: - Flow Information

    public func getActiveFlows() -> [NetworkFlow] {
        Array(activeFlows.values)
    }

    public func getFlowInfo(for identifier: FlowIdentifier) -> NetworkFlow? {
        activeFlows[identifier]
    }
}

// MARK: - Flow Identifier

public struct FlowIdentifier: Hashable {
    public let sourceAddress: String
    public let sourcePort: UInt16
    public let destinationAddress: String
    public let destinationPort: UInt16
    public let `protocol`: IPProtocol

    init(from packet: ParsedPacket) {
        self.sourceAddress = packet.sourceAddress
        self.sourcePort = packet.sourcePort
        self.destinationAddress = packet.destinationAddress
        self.destinationPort = packet.destinationPort
        self.`protocol` = packet.protocol
    }

    public var description: String {
        "\(sourceAddress):\(sourcePort) -> \(destinationAddress):\(destinationPort) [\(`protocol`)]"
    }
}

// MARK: - Network Flow

public struct NetworkFlow {
    public let identifier: FlowIdentifier
    public let startTime: Date
    public var lastActivity: Date
    public let sourceAddress: String
    public let destinationAddress: String
    public let sourcePort: UInt16
    public let destinationPort: UInt16
    public let `protocol`: IPProtocol

    public var packetCount: Int = 0
    public var totalBytes: Int64 = 0

    public var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    public var bytesPerSecond: Double {
        guard duration > 0 else { return 0 }
        return Double(totalBytes) / duration
    }
}

// MARK: - Intercept Result

public enum InterceptResult {
    case allow
    case drop
    case modify(Data)
    case proxy(Data)
}

// MARK: - Traffic Observer

public protocol TrafficObserver {
    var id: UUID { get }
    func didInterceptPacket(_ packet: ProcessedPacket) async
}

// MARK: - Statistics

public struct InterceptorStatistics: Codable {
    public var totalPackets: Int = 0
    public var totalBytes: Int64 = 0
    public var allowedPackets: Int = 0
    public var proxiedPackets: Int = 0
    public var rejectedPackets: Int = 0
    public var droppedPackets: Int = 0
    public var totalFlows: Int = 0
    public var activeFlows: Int = 0
    public var startTime: Date = Date()

    public var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    public var packetsPerSecond: Double {
        guard duration > 0 else { return 0 }
        return Double(totalPackets) / duration
    }

    public var bytesPerSecond: Double {
        guard duration > 0 else { return 0 }
        return Double(totalBytes) / duration
    }
}

// MARK: - Flow Analyzer

/// Analyzes network flows to extract metadata and patterns
public struct FlowAnalyzer {
    public static func analyzeFlow(_ flow: NetworkFlow) -> FlowAnalysis {
        var analysis = FlowAnalysis(flowIdentifier: flow.identifier)

        // Determine flow type based on port
        analysis.flowType = determineFlowType(port: flow.destinationPort)

        // Calculate metrics
        analysis.averageBytesPerPacket = flow.packetCount > 0
            ? Double(flow.totalBytes) / Double(flow.packetCount)
            : 0

        analysis.throughput = flow.bytesPerSecond

        // Detect patterns
        analysis.patterns = detectPatterns(flow)

        return analysis
    }

    private static func determineFlowType(port: UInt16) -> FlowType {
        switch port {
        case 80:
            return .http
        case 443:
            return .https
        case 53:
            return .dns
        case 20, 21:
            return .ftp
        case 22:
            return .ssh
        case 25, 587, 465:
            return .smtp
        case 110, 995:
            return .pop3
        case 143, 993:
            return .imap
        default:
            return .other
        }
    }

    private static func detectPatterns(_ flow: NetworkFlow) -> [FlowPattern] {
        var patterns: [FlowPattern] = []

        // Detect long-running connections
        if flow.duration > 300 { // 5 minutes
            patterns.append(.longRunning)
        }

        // Detect high-bandwidth flows
        if flow.bytesPerSecond > 1_000_000 { // 1 MB/s
            patterns.append(.highBandwidth)
        }

        // Detect low-activity flows
        if flow.packetCount < 10 && flow.duration > 60 {
            patterns.append(.lowActivity)
        }

        return patterns
    }
}

// MARK: - Flow Analysis

public struct FlowAnalysis {
    public let flowIdentifier: FlowIdentifier
    public var flowType: FlowType = .other
    public var averageBytesPerPacket: Double = 0
    public var throughput: Double = 0
    public var patterns: [FlowPattern] = []
}

public enum FlowType {
    case http
    case https
    case dns
    case ftp
    case ssh
    case smtp
    case pop3
    case imap
    case other
}

public enum FlowPattern {
    case longRunning
    case highBandwidth
    case lowActivity
    case bursty
    case suspicious
}
