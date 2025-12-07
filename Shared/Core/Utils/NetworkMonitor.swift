import Foundation
import Network
import Combine
import OSLog

/// Monitors system network connectivity and path changes
/// Provides real-time updates on network availability and interface changes
/// Thread-safe implementation using NWPathMonitor
public final class NetworkMonitor: ObservableObject {
    // MARK: - Published Properties

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var connectionType: ConnectionType = .unknown
    @Published public private(set) var isExpensive: Bool = false
    @Published public private(set) var isConstrained: Bool = false
    @Published public private(set) var supportsIPv4: Bool = false
    @Published public private(set) var supportsIPv6: Bool = false
    @Published public private(set) var availableInterfaces: Set<NWInterface.InterfaceType> = []

    // MARK: - Publishers

    private let statusSubject = CurrentValueSubject<NetworkStatus, Never>(.disconnected)
    public var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    private let pathSubject = PassthroughSubject<NWPath, Never>()
    public var pathPublisher: AnyPublisher<NWPath, Never> {
        pathSubject.eraseToAnyPublisher()
    }

    // MARK: - Properties

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.swiftproxy.networkmonitor", qos: .utility)
    private let logger: OSLog
    private var isMonitoring: Bool = false

    // MARK: - Initialization

    public init(requiredInterfaceType: NWInterface.InterfaceType? = nil, logger: OSLog = Logger.networkLog) {
        self.logger = logger

        if let interfaceType = requiredInterfaceType {
            self.monitor = NWPathMonitor(requiredInterfaceType: interfaceType)
        } else {
            self.monitor = NWPathMonitor()
        }

        setupMonitor()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Start monitoring network changes
    public func startMonitoring() {
        guard !isMonitoring else { return }

        os_log(.info, log: logger, "Starting network monitoring")
        monitor.start(queue: monitorQueue)
        isMonitoring = true
    }

    /// Stop monitoring network changes
    public func stopMonitoring() {
        guard isMonitoring else { return }

        os_log(.info, log: logger, "Stopping network monitoring")
        monitor.cancel()
        isMonitoring = false
    }

    /// Get current network status
    public var currentStatus: NetworkStatus {
        statusSubject.value
    }

    /// Check if a specific interface type is available
    public func hasInterface(_ type: NWInterface.InterfaceType) -> Bool {
        availableInterfaces.contains(type)
    }

    // MARK: - Private Methods

    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            self.updateNetworkState(from: path)
            self.pathSubject.send(path)

            // Log path changes
            os_log(.debug, log: self.logger, "Network path updated: %@", path.debugDescription)
        }
    }

    private func updateNetworkState(from path: NWPath) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Update connection status
            let wasConnected = self.isConnected
            self.isConnected = path.status == .satisfied

            // Update connection type
            self.connectionType = self.determineConnectionType(from: path)

            // Update path properties
            self.isExpensive = path.isExpensive
            self.isConstrained = path.isConstrained
            self.supportsIPv4 = path.supportsIPv4
            self.supportsIPv6 = path.supportsIPv6

            // Update available interfaces
            self.availableInterfaces = Set(path.availableInterfaces.map { $0.type })

            // Update status
            let newStatus = self.createNetworkStatus(from: path)
            self.statusSubject.send(newStatus)

            // Log connection state changes
            if wasConnected != self.isConnected {
                if self.isConnected {
                    os_log(.info, log: self.logger, "Network connected via %@", self.connectionType.displayName)
                } else {
                    os_log(.default, log: self.logger, "Network disconnected")
                }
            }
        }
    }

    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.loopback) {
            return .loopback
        } else if path.usesInterfaceType(.other) {
            return .other
        } else {
            return .unknown
        }
    }

    private func createNetworkStatus(from path: NWPath) -> NetworkStatus {
        switch path.status {
        case .satisfied:
            return .connected(
                type: connectionType,
                isExpensive: path.isExpensive,
                isConstrained: path.isConstrained
            )

        case .unsatisfied:
            return .disconnected

        case .requiresConnection:
            return .connecting

        @unknown default:
            return .unknown
        }
    }
}

// MARK: - Supporting Types

/// Network connection status with detailed information
public enum NetworkStatus: Equatable {
    case connected(type: ConnectionType, isExpensive: Bool, isConstrained: Bool)
    case disconnected
    case connecting
    case unknown

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var displayName: String {
        switch self {
        case .connected(let type, let isExpensive, let isConstrained):
            var parts = [type.displayName]
            if isExpensive { parts.append("Expensive") }
            if isConstrained { parts.append("Constrained") }
            return parts.joined(separator: ", ")

        case .disconnected:
            return "Disconnected"

        case .connecting:
            return "Connecting"

        case .unknown:
            return "Unknown"
        }
    }
}

/// Network connection type
public enum ConnectionType: String, Codable, CaseIterable {
    case wifi = "WiFi"
    case ethernet = "Ethernet"
    case cellular = "Cellular"
    case loopback = "Loopback"
    case other = "Other"
    case unknown = "Unknown"

    public var displayName: String {
        rawValue
    }

    public var systemImageName: String {
        switch self {
        case .wifi: return "wifi"
        case .ethernet: return "cable.connector"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .loopback: return "arrow.triangle.2.circlepath"
        case .other: return "network"
        case .unknown: return "questionmark.circle"
        }
    }

    public var priority: Int {
        // Higher priority = preferred connection
        switch self {
        case .ethernet: return 5
        case .wifi: return 4
        case .cellular: return 3
        case .other: return 2
        case .loopback: return 1
        case .unknown: return 0
        }
    }
}

// MARK: - Network Path Extensions

extension NWPath {
    /// Human-readable description of the network path
    public var debugDescription: String {
        var components: [String] = []

        components.append("Status: \(status)")

        if !availableInterfaces.isEmpty {
            let interfaces = availableInterfaces.map { $0.type.debugName }.joined(separator: ", ")
            components.append("Interfaces: [\(interfaces)]")
        }

        if isExpensive {
            components.append("Expensive")
        }

        if isConstrained {
            components.append("Constrained")
        }

        if supportsIPv4 {
            components.append("IPv4")
        }

        if supportsIPv6 {
            components.append("IPv6")
        }

        return components.joined(separator: ", ")
    }
}

extension NWInterface.InterfaceType {
    var debugName: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Network Quality

/// Additional network quality information
public struct NetworkQuality {
    public let latency: TimeInterval?
    public let bandwidth: UInt64?
    public let packetLoss: Double?

    public init(latency: TimeInterval? = nil, bandwidth: UInt64? = nil, packetLoss: Double? = nil) {
        self.latency = latency
        self.bandwidth = bandwidth
        self.packetLoss = packetLoss
    }

    public var quality: QualityRating {
        // Simple quality rating based on latency
        guard let latency = latency else { return .unknown }

        if latency < 0.050 { // < 50ms
            return .excellent
        } else if latency < 0.100 { // < 100ms
            return .good
        } else if latency < 0.200 { // < 200ms
            return .fair
        } else {
            return .poor
        }
    }

    public enum QualityRating: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case unknown = "Unknown"

        public var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "yellow"
            case .poor: return "red"
            case .unknown: return "gray"
            }
        }
    }
}

// MARK: - Reachability Helper

/// Simple reachability check for specific hosts
public final class ReachabilityChecker {
    private let logger = Logger.networkLog

    /// Test if a specific host is reachability
    public func checkReachability(to host: String, port: UInt16 = 80, timeout: TimeInterval = 5.0) async -> Bool {
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
            let connection = NWConnection(to: endpoint, using: .tcp)

            // Thread-safe state wrapper
            final class ResumeState: @unchecked Sendable {
                private let lock = NSLock()
                private var _didResume = false

                var didResume: Bool {
                    get {
                        lock.lock()
                        defer { lock.unlock() }
                        return _didResume
                    }
                    set {
                        lock.lock()
                        defer { lock.unlock() }
                        _didResume = newValue
                    }
                }
            }

            let state = ResumeState()

            // Create cancellable timeout work item
            let timeoutWork = DispatchWorkItem {
                guard !state.didResume else { return }
                state.didResume = true
                connection.cancel()
                continuation.resume(returning: false)
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

            connection.stateUpdateHandler = { connectionState in
                guard !state.didResume else { return }

                switch connectionState {
                case .ready:
                    state.didResume = true
                    timeoutWork.cancel()  // Cancel the timeout
                    connection.cancel()
                    continuation.resume(returning: true)

                case .failed, .cancelled:
                    state.didResume = true
                    timeoutWork.cancel()  // Cancel the timeout
                    connection.cancel()
                    continuation.resume(returning: false)

                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    /// Measure latency to a specific host
    public func measureLatency(to host: String, port: UInt16 = 80, timeout: TimeInterval = 5.0) async -> TimeInterval? {
        let startTime = Date()

        let isReachable = await checkReachability(to: host, port: port, timeout: timeout)

        guard isReachable else { return nil }

        return Date().timeIntervalSince(startTime)
    }
}
