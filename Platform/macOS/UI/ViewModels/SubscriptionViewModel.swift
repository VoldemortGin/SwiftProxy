import Foundation
import Combine
import OSLog
import SwiftProxyCore

/// 订阅管理视图模型
/// 连接订阅服务和 UI 层
@MainActor
public class SubscriptionViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var subscriptions: [SwiftProxyCore.Subscription] = []
    @Published public var allNodes: [ProxyNode] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    // MARK: - Properties

    private let subscriptionService: SubscriptionService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    public var totalNodesCount: Int {
        allNodes.count
    }

    public var enabledNodesCount: Int {
        allNodes.filter { $0.isEnabled }.count
    }

    // MARK: - Initialization

    public init(subscriptionService: SubscriptionService) {
        self.subscriptionService = subscriptionService

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // 订阅列表变化
        subscriptionService.subscriptions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subscriptions in
                self?.subscriptions = subscriptions
            }
            .store(in: &cancellables)

        // 所有节点变化
        subscriptionService.allNodes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nodes in
                self?.allNodes = nodes
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// 添加订阅
    public func addSubscription(name: String, url: String, updateInterval: TimeInterval) async throws {
        isLoading = true
        errorMessage = nil

        do {
            try await subscriptionService.addSubscription(
                name: name,
                url: url,
                updateInterval: updateInterval
            )
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// 更新订阅
    public func updateSubscription(_ subscription: SwiftProxyCore.Subscription) {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                _ = try await subscriptionService.updateSubscription(subscription)
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 删除订阅
    public func deleteSubscription(_ id: UUID) {
        Task {
            do {
                try await subscriptionService.deleteSubscription(id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 切换订阅启用状态
    public func toggleSubscription(_ id: UUID) {
        Task {
            do {
                try await subscriptionService.toggleSubscription(id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 测试节点延迟
    public func testNode(_ nodeId: UUID) async {
        if let latency = await subscriptionService.testNode(nodeId) {
            // 更新节点延迟
            if let subIndex = subscriptions.firstIndex(where: { $0.nodes.contains(where: { $0.id == nodeId }) }) {
                if let nodeIndex = subscriptions[subIndex].nodes.firstIndex(where: { $0.id == nodeId }) {
                    subscriptions[subIndex].nodes[nodeIndex].latency = latency
                }
            }
        }
    }

    /// 批量测试节点
    public func testAllNodes(for subscription: SwiftProxyCore.Subscription) async {
        for node in subscription.nodes {
            await testNode(node.id)
        }
    }

    /// 启动自动更新
    public func startAutoUpdate() {
        subscriptionService.startAutoUpdate()
    }

    /// 停止自动更新
    public func stopAutoUpdate() {
        subscriptionService.stopAutoUpdate()
    }

    /// 清除错误消息
    public func clearError() {
        errorMessage = nil
    }
}

// MARK: - Preview Helper

extension SubscriptionViewModel {
    public static var preview: SubscriptionViewModel {
        let service = try! SubscriptionService()
        let vm = SubscriptionViewModel(subscriptionService: service)

        // 添加示例订阅
        Task {
            let sub1 = Subscription(
                name: "boslife 机场",
                url: "https://example.com/sub?token=xxx",
                lastUpdated: Date(),
                nodes: [
                    ProxyNode(
                        name: "香港 01",
                        type: .shadowsocks,
                        server: "hk01.example.com",
                        port: 8388,
                        credentials: .shadowsocks(password: "password", method: "aes-256-gcm"),
                        latency: 45
                    ),
                    ProxyNode(
                        name: "日本 01",
                        type: .vmess,
                        server: "jp01.example.com",
                        port: 443,
                        credentials: .vmess(uuid: "xxxxx", alterId: 0, security: "auto", network: "ws", tls: true),
                        latency: 67
                    ),
                    ProxyNode(
                        name: "美国 01",
                        type: .trojan,
                        server: "us01.example.com",
                        port: 443,
                        credentials: .trojan(password: "password", sni: "example.com", skipCertVerify: false),
                        latency: 156
                    )
                ]
            )

            vm.subscriptions = [sub1]
            vm.allNodes = sub1.nodes
        }

        return vm
    }
}
