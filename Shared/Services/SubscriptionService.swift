import Foundation
import Combine
import OSLog

/// 订阅服务协议
/// 定义订阅管理的核心功能
public protocol SubscriptionServiceProtocol: AnyObject {
    // Publishers
    var subscriptions: AnyPublisher<[Subscription], Never> { get }
    var allNodes: AnyPublisher<[ProxyNode], Never> { get }

    // Subscription management
    func addSubscription(name: String, url: String, updateInterval: TimeInterval) async throws
    func updateSubscription(_ subscription: Subscription) async throws -> [ProxyNode]
    func deleteSubscription(_ id: UUID) async throws
    func toggleSubscription(_ id: UUID) async throws

    // Node management
    func getAllNodes() async -> [ProxyNode]
    func getNodes(for subscriptionId: UUID) async -> [ProxyNode]
    func testNode(_ nodeId: UUID) async -> TimeInterval?

    // Auto-update
    func startAutoUpdate()
    func stopAutoUpdate()

    // Persistence
    func saveSubscriptions() async throws
    func loadSubscriptions() async throws
}

/// 订阅服务实现
/// 管理订阅的添加、更新、删除和节点解析
public final class SubscriptionService: SubscriptionServiceProtocol, @unchecked Sendable {
    // MARK: - Publishers

    private let subscriptionsSubject = CurrentValueSubject<[Subscription], Never>([])
    private let allNodesSubject = CurrentValueSubject<[ProxyNode], Never>([])

    public var subscriptions: AnyPublisher<[Subscription], Never> {
        subscriptionsSubject.eraseToAnyPublisher()
    }

    public var allNodes: AnyPublisher<[ProxyNode], Never> {
        allNodesSubject.eraseToAnyPublisher()
    }

    // MARK: - Properties

    private let logger: OSLog
    private let fileManager: FileManager
    private let storageURL: URL
    private let stateQueue = DispatchQueue(label: "com.swiftproxy.subscription", qos: .utility)

    // Auto-update timer
    private var autoUpdateTimer: Timer?
    private let checkInterval: TimeInterval = 3600.0  // 每小时检查一次

    // MARK: - Initialization

    public init(
        fileManager: FileManager = .default,
        logger: OSLog = Logger.storageLog
    ) throws {
        self.fileManager = fileManager
        self.logger = logger

        // Setup storage directory
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        self.storageURL = appSupport.appendingPathComponent("SwiftProxy/Subscriptions", isDirectory: true)

        try createStorageDirectoryIfNeeded()

        // Load subscriptions
        Task {
            try? await loadSubscriptions()
        }
    }

    deinit {
        stopAutoUpdate()
    }

    // MARK: - Subscription Management

    public func addSubscription(name: String, url: String, updateInterval: TimeInterval = 86400) async throws {
        os_log(.info, log: logger, "Adding subscription: %@", name)

        // 验证 URL
        guard let _ = URL(string: url) else {
            throw SubscriptionServiceError.invalidURL
        }

        // 创建订阅
        var subscription = Subscription(
            name: name,
            url: url,
            updateInterval: updateInterval
        )

        // 立即更新以获取节点
        do {
            let nodes = try await fetchAndParseSubscription(url: url)
            subscription.nodes = nodes
            subscription.lastUpdated = Date()

            // 设置订阅 ID 给每个节点
            subscription.nodes = nodes.map { node in
                var newNode = node
                newNode.subscriptionId = subscription.id
                return newNode
            }

            os_log(.info, log: logger, "Successfully fetched %d nodes from subscription", nodes.count)
        } catch {
            os_log(.error, log: logger, "Failed to fetch subscription: %@", error.localizedDescription)
            throw SubscriptionServiceError.fetchFailed(error)
        }

        // 添加到列表
        await MainActor.run {
            var subs = self.subscriptionsSubject.value
            subs.append(subscription)
            self.subscriptionsSubject.send(subs)
            self.updateAllNodes()
        }

        // 保存
        try await saveSubscriptions()
    }

    public func updateSubscription(_ subscription: Subscription) async throws -> [ProxyNode] {
        os_log(.info, log: logger, "Updating subscription: %@", subscription.name)

        // 获取最新节点
        let nodes = try await fetchAndParseSubscription(url: subscription.url)

        // 更新订阅
        await MainActor.run {
            var subs = self.subscriptionsSubject.value
            if let index = subs.firstIndex(where: { $0.id == subscription.id }) {
                subs[index].nodes = nodes.map { node in
                    var newNode = node
                    newNode.subscriptionId = subscription.id
                    return newNode
                }
                subs[index].lastUpdated = Date()
                self.subscriptionsSubject.send(subs)
                self.updateAllNodes()
            }
        }

        // 保存
        try await saveSubscriptions()

        return nodes
    }

    public func deleteSubscription(_ id: UUID) async throws {
        os_log(.info, log: logger, "Deleting subscription: %@", id.uuidString)

        await MainActor.run {
            var subs = self.subscriptionsSubject.value
            subs.removeAll { $0.id == id }
            self.subscriptionsSubject.send(subs)
            self.updateAllNodes()
        }

        try await saveSubscriptions()
    }

    public func toggleSubscription(_ id: UUID) async throws {
        await MainActor.run {
            var subs = self.subscriptionsSubject.value
            if let index = subs.firstIndex(where: { $0.id == id }) {
                subs[index].isEnabled.toggle()
                self.subscriptionsSubject.send(subs)
                self.updateAllNodes()
            }
        }

        try await saveSubscriptions()
    }

    // MARK: - Node Management

    public func getAllNodes() async -> [ProxyNode] {
        await MainActor.run {
            allNodesSubject.value
        }
    }

    public func getNodes(for subscriptionId: UUID) async -> [ProxyNode] {
        await MainActor.run {
            guard let subscription = subscriptionsSubject.value.first(where: { $0.id == subscriptionId }) else {
                return []
            }
            return subscription.nodes
        }
    }

    public func testNode(_ nodeId: UUID) async -> TimeInterval? {
        // 实现节点延迟测试
        // 这里暂时返回模拟值，实际应该 ping 节点
        return TimeInterval.random(in: 50...500)
    }

    // MARK: - Auto Update

    public func startAutoUpdate() {
        stopAutoUpdate()  // 先停止现有的

        Task { @MainActor in
            self.autoUpdateTimer = Timer.scheduledTimer(
                withTimeInterval: self.checkInterval,
                repeats: true
            ) { [weak self] _ in
                Task {
                    await self?.checkAndUpdateSubscriptions()
                }
            }

            os_log(.info, log: self.logger, "Auto-update started (interval: %.0f seconds)", self.checkInterval)
        }
    }

    public func stopAutoUpdate() {
        autoUpdateTimer?.invalidate()
        autoUpdateTimer = nil
        os_log(.info, log: logger, "Auto-update stopped")
    }

    private func checkAndUpdateSubscriptions() async {
        let subs = await MainActor.run { subscriptionsSubject.value }

        for subscription in subs where subscription.isEnabled && subscription.needsUpdate {
            do {
                _ = try await updateSubscription(subscription)
                os_log(.info, log: logger, "Auto-updated subscription: %@", subscription.name)
            } catch {
                os_log(.error, log: logger, "Failed to auto-update subscription %@: %@",
                       subscription.name, error.localizedDescription)
            }
        }
    }

    // MARK: - Network

    private func fetchAndParseSubscription(url: String) async throws -> [ProxyNode] {
        guard let url = URL(string: url) else {
            throw SubscriptionServiceError.invalidURL
        }

        // 创建请求
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("SwiftProxy/1.0", forHTTPHeaderField: "User-Agent")

        // 获取数据
        let (data, response) = try await URLSession.shared.data(for: request)

        // 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubscriptionServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SubscriptionServiceError.httpError(httpResponse.statusCode)
        }

        // 解析订阅
        do {
            let nodes = try SubscriptionParserFactory.parse(data: data)
            os_log(.info, log: logger, "Parsed %d nodes from subscription", nodes.count)
            return nodes
        } catch {
            os_log(.error, log: logger, "Failed to parse subscription: %@", error.localizedDescription)
            throw SubscriptionServiceError.parseFailed(error)
        }
    }

    // MARK: - Persistence

    public func saveSubscriptions() async throws {
        let subs = await MainActor.run { subscriptionsSubject.value }

        try await stateQueue.syncThrowing { [self] in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(subs)

            let fileURL = self.storageURL.appendingPathComponent("subscriptions.json")
            try data.write(to: fileURL, options: [.atomic])

            os_log(.debug, log: self.logger, "Subscriptions saved to disk")
        }
    }

    public func loadSubscriptions() async throws {
        let loadedSubs: [Subscription]? = try await stateQueue.syncThrowing { [self] in
            let fileURL = self.storageURL.appendingPathComponent("subscriptions.json")

            guard self.fileManager.fileExists(atPath: fileURL.path) else {
                os_log(.info, log: self.logger, "No saved subscriptions found")
                return nil as [Subscription]?
            }

            let data = try Data(contentsOf: fileURL)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let subs = try decoder.decode([Subscription].self, from: data)

            os_log(.info, log: self.logger, "Loaded %d subscriptions from disk", subs.count)
            return subs
        }

        if let subs = loadedSubs {
            await MainActor.run {
                self.subscriptionsSubject.send(subs)
                self.updateAllNodes()
            }
        }
    }

    // MARK: - Private Methods

    private func createStorageDirectoryIfNeeded() throws {
        if !fileManager.fileExists(atPath: storageURL.path) {
            try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
            os_log(.info, log: logger, "Created subscriptions storage directory")
        }
    }

    private func updateAllNodes() {
        let subs = subscriptionsSubject.value
        let allNodes = subs.filter { $0.isEnabled }
            .flatMap { $0.nodes }
            .filter { $0.isEnabled }

        allNodesSubject.send(allNodes)
    }
}

// MARK: - Errors

public enum SubscriptionServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case fetchFailed(Error)
    case parseFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的订阅 URL"
        case .invalidResponse:
            return "无效的服务器响应"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .fetchFailed(let error):
            return "获取订阅失败: \(error.localizedDescription)"
        case .parseFailed(let error):
            return "解析订阅失败: \(error.localizedDescription)"
        }
    }
}
