# SwiftProxy 核心代码结构和实现

## 1. 应用入口和依赖注入

### SwiftProxyApp.swift
```swift
import SwiftUI

@main
struct SwiftProxyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var container = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // 菜单栏 MenuBar
        MenuBarExtra("SwiftProxy", systemImage: "network") {
            MenuBarView()
                .environmentObject(container)
        }
        .menuBarExtraStyle(.window)
    }
}
```

### AppDelegate.swift
```swift
import Cocoa
import NetworkExtension

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 请求 Network Extension 权限
        requestNetworkExtensionPermission()

        // 注册 URL Scheme
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // 关闭窗口不退出应用
    }

    private func requestNetworkExtensionPermission() {
        Task {
            do {
                try await NETransparentProxyManager.loadAllFromPreferences()
                Logger.proxy.info("Network Extension permission granted")
            } catch {
                Logger.proxy.error("Failed to request Network Extension permission: \(error)")
            }
        }
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        // 处理 swiftproxy:// URL Scheme
        handleDeepLink(url)
    }

    private func handleDeepLink(_ url: URL) {
        // 实现 URL Scheme 处理逻辑
        Logger.proxy.info("Handling deep link: \(url)")
    }
}
```

### DependencyContainer.swift
```swift
import Foundation
import Combine

final class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()

    // MARK: - Services
    private(set) lazy var proxyService: ProxyServiceProtocol = {
        ProxyService(storage: storageService, logger: Logger.proxy)
    }()

    private(set) lazy var networkMonitor: NetworkMonitorProtocol = {
        NetworkMonitorService(
            proxyService: proxyService,
            ruleEngine: ruleEngine,
            logger: Logger.network
        )
    }()

    private(set) lazy var ruleEngine: RuleEngineProtocol = {
        RuleEngineService(storage: storageService, logger: Logger.rules)
    }()

    private(set) lazy var trafficAnalyzer: TrafficAnalyzerProtocol = {
        TrafficAnalyzerService(storage: storageService)
    }()

    private(set) lazy var storageService: StorageProtocol = {
        StorageService(logger: Logger.storage)
    }()

    private(set) lazy var extensionManager: ExtensionManagerProtocol = {
        ExtensionManager(logger: Logger.proxy)
    }()

    // MARK: - ViewModels Factory
    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            proxyService: proxyService,
            networkMonitor: networkMonitor,
            trafficAnalyzer: trafficAnalyzer
        )
    }

    func makeProxyControlViewModel() -> ProxyControlViewModel {
        ProxyControlViewModel(
            proxyService: proxyService,
            storageService: storageService
        )
    }

    func makeMonitorViewModel() -> MonitorViewModel {
        MonitorViewModel(
            networkMonitor: networkMonitor,
            ruleEngine: ruleEngine
        )
    }

    func makeRulesViewModel() -> RulesViewModel {
        RulesViewModel(ruleEngine: ruleEngine)
    }

    func makeStatisticsViewModel() -> StatisticsViewModel {
        StatisticsViewModel(trafficAnalyzer: trafficAnalyzer)
    }

    private init() {}
}
```

---

## 2. 核心协议定义

### Core/Protocols/ServiceProtocol.swift
```swift
import Combine

protocol ServiceProtocol: AnyObject {
    associatedtype Input
    associatedtype Output

    func execute(_ input: Input) async throws -> Output
}

protocol ObservableService: AnyObject {
    associatedtype State
    var state: AnyPublisher<State, Never> { get }
}
```

### Services/ProxyService/ProxyServiceProtocol.swift
```swift
import Foundation
import Combine

protocol ProxyServiceProtocol: AnyObject {
    // 状态发布
    var isEnabled: AnyPublisher<Bool, Never> { get }
    var currentConfiguration: AnyPublisher<ProxyConfiguration?, Never> { get }
    var proxyStatus: AnyPublisher<ProxyStatus, Never> { get }

    // 代理控制
    func enable(configuration: ProxyConfiguration) async throws
    func disable() async throws
    func toggle() async throws
    func updateConfiguration(_ configuration: ProxyConfiguration) async throws

    // 系统代理
    func getCurrentSystemProxy() async throws -> SystemProxySettings
    func testConnection(configuration: ProxyConfiguration) async throws -> ConnectionTestResult

    // 配置管理
    func saveConfiguration(_ configuration: ProxyConfiguration) async throws
    func loadConfigurations() async throws -> [ProxyConfiguration]
    func deleteConfiguration(id: UUID) async throws
}

enum ProxyStatus {
    case disabled
    case enabling
    case enabled(ProxyConfiguration)
    case disabling
    case error(AppError)

    var isActive: Bool {
        if case .enabled = self { return true }
        return false
    }
}

struct SystemProxySettings {
    let httpEnabled: Bool
    let httpsEnabled: Bool
    let socksEnabled: Bool
    let httpProxy: String?
    let httpPort: Int?
    let httpsProxy: String?
    let httpsPort: Int?
    let socksProxy: String?
    let socksPort: Int?
    let bypassDomains: [String]
}

struct ConnectionTestResult {
    let success: Bool
    let latency: TimeInterval?
    let error: AppError?
}
```

### Services/NetworkMonitor/NetworkMonitorProtocol.swift
```swift
import Foundation
import Combine

protocol NetworkMonitorProtocol: AnyObject {
    // 实时数据流
    var requests: AnyPublisher<[NetworkRequest], Never> { get }
    var connectionLogs: AnyPublisher<[ConnectionLog], Never> { get }
    var activeConnections: AnyPublisher<Int, Never> { get }
    var monitoringState: AnyPublisher<MonitoringState, Never> { get }

    // 监控控制
    func startMonitoring() async throws
    func stopMonitoring() async throws
    func pauseMonitoring() async throws
    func resumeMonitoring() async throws

    // 数据管理
    func clearLogs() async
    func exportLogs(to url: URL) async throws
    func filterRequests(by criteria: RequestFilterCriteria) async -> [NetworkRequest]
    func searchRequests(query: String) async -> [NetworkRequest]

    // 统计
    func getCurrentStatistics() async -> MonitorStatistics
}

enum MonitoringState {
    case idle
    case starting
    case active
    case paused
    case stopping
    case error(AppError)
}

struct RequestFilterCriteria {
    var methods: Set<HTTPMethod>?
    var statuses: Set<RequestStatus>?
    var timeRange: ClosedRange<Date>?
    var domains: Set<String>?
    var ruleActions: Set<RuleAction>?
}

struct MonitorStatistics {
    let totalRequests: Int
    let activeConnections: Int
    let totalBytesIn: Int64
    let totalBytesOut: Int64
    let averageLatency: TimeInterval
    let requestsPerSecond: Double
}

struct ConnectionLog: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let event: ConnectionEvent
    let request: NetworkRequest?
    let error: String?
}

enum ConnectionEvent: String, Codable {
    case established
    case dataReceived
    case dataSent
    case closed
    case failed
}
```

### Services/RuleEngine/RuleEngineProtocol.swift
```swift
import Foundation
import Combine

protocol RuleEngineProtocol: AnyObject {
    // 规则数据流
    var rules: AnyPublisher<[ProxyRule], Never> { get }
    var ruleGroups: AnyPublisher<[RuleGroup], Never> { get }

    // 规则管理
    func addRule(_ rule: ProxyRule) async throws
    func updateRule(_ rule: ProxyRule) async throws
    func deleteRule(id: UUID) async throws
    func reorderRules(_ rules: [ProxyRule]) async throws

    // 规则组管理
    func createGroup(_ group: RuleGroup) async throws
    func updateGroup(_ group: RuleGroup) async throws
    func deleteGroup(id: UUID) async throws

    // 规则匹配
    func matchRule(for request: NetworkRequest) -> ProxyRule?
    func testRule(_ rule: ProxyRule, against testCases: [String]) -> [RuleTestResult]

    // 导入导出
    func importRules(from url: URL, format: RuleFormat) async throws -> [ProxyRule]
    func exportRules(to url: URL, format: RuleFormat) async throws
    func importFromClipboard(format: RuleFormat) async throws -> [ProxyRule]

    // 预设规则
    func loadPresetRules() async throws -> [RuleGroup]
    func applyPreset(id: String) async throws
}

struct RuleGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String?
    var rules: [ProxyRule]
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum RuleFormat: String, CaseIterable {
    case swiftProxy = "SwiftProxy"
    case clash = "Clash"
    case surge = "Surge"
    case quantumultX = "QuantumultX"

    var fileExtension: String {
        switch self {
        case .swiftProxy: return "json"
        case .clash: return "yaml"
        case .surge: return "conf"
        case .quantumultX: return "conf"
        }
    }
}

struct RuleTestResult {
    let input: String
    let matched: Bool
    let matchedPattern: String?
}
```

### Services/TrafficAnalyzer/TrafficAnalyzerProtocol.swift
```swift
import Foundation
import Combine

protocol TrafficAnalyzerProtocol: AnyObject {
    // 统计数据流
    var statistics: AnyPublisher<TrafficStatistics, Never> { get }
    var realtimeSpeed: AnyPublisher<NetworkSpeed, Never> { get }

    // 分析功能
    func analyzeTraffic(timeRange: TimeRange) async -> TrafficAnalysis
    func getTopDomains(limit: Int, timeRange: TimeRange) async -> [DomainStats]
    func getHourlyTraffic(date: Date) async -> [HourlyTraffic]
    func getDailyTraffic(month: Date) async -> [DailyTraffic]

    // 导出功能
    func exportStatistics(timeRange: TimeRange, format: ExportFormat) async throws -> URL
    func generateReport(timeRange: TimeRange) async throws -> TrafficReport
}

struct NetworkSpeed: Codable {
    let timestamp: Date
    let downloadSpeed: Int64  // bytes/sec
    let uploadSpeed: Int64    // bytes/sec
}

enum TimeRange {
    case last1Hour
    case last6Hours
    case last24Hours
    case last7Days
    case last30Days
    case custom(start: Date, end: Date)

    var dateRange: ClosedRange<Date> {
        let now = Date()
        switch self {
        case .last1Hour:
            return now.addingTimeInterval(-3600)...now
        case .last6Hours:
            return now.addingTimeInterval(-21600)...now
        case .last24Hours:
            return now.addingTimeInterval(-86400)...now
        case .last7Days:
            return now.addingTimeInterval(-604800)...now
        case .last30Days:
            return now.addingTimeInterval(-2592000)...now
        case .custom(let start, let end):
            return start...end
        }
    }
}

struct TrafficAnalysis {
    let timeRange: TimeRange
    let statistics: TrafficStatistics
    let topDomains: [DomainStats]
    let topProcesses: [ProcessStats]
    let peakTimes: [PeakTime]
    let protocolDistribution: [ProtocolStats]
}

struct ProcessStats: Identifiable, Codable {
    let id: UUID
    let processName: String
    var requestCount: Int
    var bytesIn: Int64
    var bytesOut: Int64
}

struct PeakTime: Codable {
    let timestamp: Date
    let requestsPerMinute: Int
    let bytesPerMinute: Int64
}

struct ProtocolStats: Codable {
    let protocolType: String  // HTTP, HTTPS, SOCKS5
    var requestCount: Int
    var bytesIn: Int64
    var bytesOut: Int64
}

struct DailyTraffic: Identifiable, Codable {
    let id: UUID
    let date: Date
    var requests: Int
    var bytesIn: Int64
    var bytesOut: Int64
}

struct TrafficReport {
    let title: String
    let generatedAt: Date
    let timeRange: TimeRange
    let summary: String
    let analysis: TrafficAnalysis
    let charts: [ChartData]
}

struct ChartData {
    let title: String
    let type: ChartType
    let data: [ChartDataPoint]
}

enum ChartType {
    case line
    case bar
    case pie
    case area
}

struct ChartDataPoint: Identifiable {
    let id: UUID
    let label: String
    let value: Double
    let timestamp: Date?
}

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case pdf = "PDF"
    case html = "HTML"
}
```

### Services/Storage/StorageProtocol.swift
```swift
import Foundation

protocol StorageProtocol: AnyObject {
    // 通用存储
    func save<T: Codable>(_ object: T, forKey key: StorageKey) async throws
    func load<T: Codable>(forKey key: StorageKey) async throws -> T?
    func delete(forKey key: StorageKey) async throws
    func exists(forKey key: StorageKey) async -> Bool

    // 集合操作
    func saveArray<T: Codable>(_ array: [T], forKey key: StorageKey) async throws
    func loadArray<T: Codable>(forKey key: StorageKey) async throws -> [T]
    func appendToArray<T: Codable>(_ item: T, forKey key: StorageKey) async throws
    func removeFromArray<T: Codable & Identifiable>(id: T.ID, forKey key: StorageKey) async throws

    // 敏感数据（Keychain）
    func saveSecure(_ data: Data, forKey key: String) async throws
    func loadSecure(forKey key: String) async throws -> Data?
    func deleteSecure(forKey key: String) async throws

    // 缓存管理
    func clearCache() async throws
    func getCacheSize() async throws -> Int64

    // 数据迁移
    func migrateIfNeeded() async throws
    func exportData(to url: URL) async throws
    func importData(from url: URL) async throws
}

enum StorageKey: String {
    case proxyConfigurations = "proxy_configurations"
    case proxyRules = "proxy_rules"
    case ruleGroups = "rule_groups"
    case connectionLogs = "connection_logs"
    case trafficStatistics = "traffic_statistics"
    case appSettings = "app_settings"
    case lastActiveConfiguration = "last_active_configuration"
}
```

---

## 3. ViewModel 实现

### ViewModels/ProxyControlViewModel.swift
```swift
import Foundation
import Combine
import SwiftUI

@MainActor
final class ProxyControlViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isEnabled: Bool = false
    @Published var currentConfiguration: ProxyConfiguration?
    @Published var savedConfigurations: [ProxyConfiguration] = []
    @Published var operationState: OperationState = .idle
    @Published var showingAddConfiguration = false
    @Published var editingConfiguration: ProxyConfiguration?

    // MARK: - Dependencies
    private let proxyService: ProxyServiceProtocol
    private let storageService: StorageProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(
        proxyService: ProxyServiceProtocol,
        storageService: StorageProtocol
    ) {
        self.proxyService = proxyService
        self.storageService = storageService

        setupBindings()
        loadConfigurations()
    }

    // MARK: - Setup
    private func setupBindings() {
        proxyService.isEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: &$isEnabled)

        proxyService.currentConfiguration
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentConfiguration)
    }

    // MARK: - Actions
    func toggleProxy() {
        Task {
            do {
                operationState = .loading
                try await proxyService.toggle()
                operationState = .success(isEnabled ? "代理已启用" : "代理已禁用")
            } catch {
                let appError = error as? AppError ?? .unknown(error)
                operationState = .failure(appError)
            }
        }
    }

    func enableProxy(configuration: ProxyConfiguration) {
        Task {
            do {
                operationState = .loading
                try await proxyService.enable(configuration: configuration)
                operationState = .success("代理已启用")
            } catch {
                let appError = error as? AppError ?? .unknown(error)
                operationState = .failure(appError)
            }
        }
    }

    func disableProxy() {
        Task {
            do {
                operationState = .loading
                try await proxyService.disable()
                operationState = .success("代理已禁用")
            } catch {
                let appError = error as? AppError ?? .unknown(error)
                operationState = .failure(appError)
            }
        }
    }

    func testConnection(configuration: ProxyConfiguration) {
        Task {
            do {
                operationState = .loading
                let result = try await proxyService.testConnection(configuration: configuration)

                if result.success {
                    let latencyMs = Int((result.latency ?? 0) * 1000)
                    operationState = .success("连接成功，延迟: \(latencyMs)ms")
                } else {
                    operationState = .failure(result.error ?? .proxyConnectionFailed("未知错误"))
                }
            } catch {
                let appError = error as? AppError ?? .unknown(error)
                operationState = .failure(appError)
            }
        }
    }

    func saveConfiguration(_ configuration: ProxyConfiguration) {
        Task {
            do {
                try await proxyService.saveConfiguration(configuration)
                await loadConfigurations()
                operationState = .success("配置已保存")
                showingAddConfiguration = false
                editingConfiguration = nil
            } catch {
                let appError = error as? AppError ?? .unknown(error)
                operationState = .failure(appError)
            }
        }
    }

    func deleteConfiguration(id: UUID) {
        Task {
            do {
                try await proxyService.deleteConfiguration(id: id)
                await loadConfigurations()
                operationState = .success("配置已删除")
            } catch {
                let appError = error as? AppError ?? .unknown(error)
                operationState = .failure(appError)
            }
        }
    }

    private func loadConfigurations() {
        Task {
            do {
                savedConfigurations = try await proxyService.loadConfigurations()
            } catch {
                Logger.proxy.error("Failed to load configurations: \(error)")
            }
        }
    }
}

// MARK: - OperationState
enum OperationState: Equatable {
    case idle
    case loading
    case success(String)
    case failure(AppError)

    static func == (lhs: OperationState, rhs: OperationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case let (.success(lhsMessage), .success(rhsMessage)):
            return lhsMessage == rhsMessage
        case let (.failure(lhsError), .failure(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
```

### ViewModels/MonitorViewModel.swift
```swift
import Foundation
import Combine
import SwiftUI

@MainActor
final class MonitorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var requests: [NetworkRequest] = []
    @Published var filteredRequests: [NetworkRequest] = []
    @Published var activeConnections: Int = 0
    @Published var monitoringState: MonitoringState = .idle
    @Published var searchQuery: String = ""
    @Published var filterCriteria = RequestFilterCriteria()

    // MARK: - Dependencies
    private let networkMonitor: NetworkMonitorProtocol
    private let ruleEngine: RuleEngineProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(
        networkMonitor: NetworkMonitorProtocol,
        ruleEngine: RuleEngineProtocol
    ) {
        self.networkMonitor = networkMonitor
        self.ruleEngine = ruleEngine

        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        networkMonitor.requests
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requests in
                self?.requests = requests
                self?.applyFilters()
            }
            .store(in: &cancellables)

        networkMonitor.activeConnections
            .receive(on: DispatchQueue.main)
            .assign(to: &$activeConnections)

        networkMonitor.monitoringState
            .receive(on: DispatchQueue.main)
            .assign(to: &$monitoringState)

        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions
    func startMonitoring() {
        Task {
            do {
                try await networkMonitor.startMonitoring()
            } catch {
                Logger.network.error("Failed to start monitoring: \(error)")
            }
        }
    }

    func stopMonitoring() {
        Task {
            do {
                try await networkMonitor.stopMonitoring()
            } catch {
                Logger.network.error("Failed to stop monitoring: \(error)")
            }
        }
    }

    func clearLogs() {
        Task {
            await networkMonitor.clearLogs()
        }
    }

    func exportLogs(to url: URL) {
        Task {
            do {
                try await networkMonitor.exportLogs(to: url)
            } catch {
                Logger.network.error("Failed to export logs: \(error)")
            }
        }
    }

    private func applyFilters() {
        Task {
            var filtered = requests

            // 搜索过滤
            if !searchQuery.isEmpty {
                filtered = await networkMonitor.searchRequests(query: searchQuery)
            }

            // 条件过滤
            if filterCriteria.hasActiveFilters {
                filtered = await networkMonitor.filterRequests(by: filterCriteria)
            }

            filteredRequests = filtered
        }
    }

    func updateFilter(_ criteria: RequestFilterCriteria) {
        filterCriteria = criteria
        applyFilters()
    }
}

extension RequestFilterCriteria {
    var hasActiveFilters: Bool {
        methods != nil || statuses != nil || timeRange != nil || domains != nil || ruleActions != nil
    }
}
```

---

## 4. Service 实现示例

### Services/ProxyService/ProxyService.swift
```swift
import Foundation
import Combine
import SystemConfiguration
import OSLog

final class ProxyService: ProxyServiceProtocol {
    // MARK: - Published Subjects
    private let isEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let configurationSubject = CurrentValueSubject<ProxyConfiguration?, Never>(nil)
    private let statusSubject = CurrentValueSubject<ProxyStatus, Never>(.disabled)

    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    var currentConfiguration: AnyPublisher<ProxyConfiguration?, Never> {
        configurationSubject.eraseToAnyPublisher()
    }

    var proxyStatus: AnyPublisher<ProxyStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    // MARK: - Dependencies
    private let storage: StorageProtocol
    private let logger: Logger

    // MARK: - Initialization
    init(storage: StorageProtocol, logger: Logger) {
        self.storage = storage
        self.logger = logger

        // 启动时检查系统代理状态
        Task {
            await checkSystemProxyStatus()
        }
    }

    // MARK: - Proxy Control
    func enable(configuration: ProxyConfiguration) async throws {
        logger.info("Enabling proxy with configuration: \(configuration.name)")
        statusSubject.send(.enabling)

        do {
            // 设置系统代理
            try await setSystemProxy(configuration: configuration)

            // 更新状态
            isEnabledSubject.send(true)
            configurationSubject.send(configuration)
            statusSubject.send(.enabled(configuration))

            // 保存最后使用的配置
            try await storage.save(configuration, forKey: .lastActiveConfiguration)

            logger.info("Proxy enabled successfully")
        } catch {
            statusSubject.send(.error(error as? AppError ?? .unknown(error)))
            throw error
        }
    }

    func disable() async throws {
        logger.info("Disabling proxy")
        statusSubject.send(.disabling)

        do {
            // 关闭系统代理
            try await clearSystemProxy()

            // 更新状态
            isEnabledSubject.send(false)
            configurationSubject.send(nil)
            statusSubject.send(.disabled)

            logger.info("Proxy disabled successfully")
        } catch {
            statusSubject.send(.error(error as? AppError ?? .unknown(error)))
            throw error
        }
    }

    func toggle() async throws {
        if isEnabledSubject.value {
            try await disable()
        } else {
            // 尝试加载最后使用的配置
            if let lastConfig: ProxyConfiguration = try await storage.load(forKey: .lastActiveConfiguration) {
                try await enable(configuration: lastConfig)
            } else {
                throw AppError.proxyConfigurationInvalid("没有可用的代理配置")
            }
        }
    }

    func updateConfiguration(_ configuration: ProxyConfiguration) async throws {
        logger.info("Updating proxy configuration")

        if isEnabledSubject.value {
            try await disable()
            try await enable(configuration: configuration)
        }

        try await saveConfiguration(configuration)
    }

    // MARK: - System Proxy
    func getCurrentSystemProxy() async throws -> SystemProxySettings {
        guard let preferences = SCPreferencesCreate(nil, "SwiftProxy" as CFString, nil),
              let services = SCNetworkServiceCopyAll(preferences) as? [SCNetworkService] else {
            throw AppError.proxyConnectionFailed("无法访问系统网络设置")
        }

        var settings = SystemProxySettings(
            httpEnabled: false,
            httpsEnabled: false,
            socksEnabled: false,
            httpProxy: nil,
            httpPort: nil,
            httpsProxy: nil,
            httpsPort: nil,
            socksProxy: nil,
            socksPort: nil,
            bypassDomains: []
        )

        // 读取系统代理设置
        for service in services {
            if let protocolConfig = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeIPv4) {
                // 读取 HTTP/HTTPS/SOCKS 代理设置
                // 实现具体的读取逻辑
            }
        }

        return settings
    }

    func testConnection(configuration: ProxyConfiguration) async throws -> ConnectionTestResult {
        let startTime = Date()

        do {
            // 使用代理配置测试连接
            let url = URL(string: "https://www.google.com")!
            var request = URLRequest(url: url, timeoutInterval: 10)

            // 配置代理
            let sessionConfig = URLSessionConfiguration.ephemeral
            sessionConfig.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: true,
                kCFNetworkProxiesHTTPProxy: configuration.host,
                kCFNetworkProxiesHTTPPort: configuration.port
            ] as [String: Any]

            let session = URLSession(configuration: sessionConfig)
            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return ConnectionTestResult(
                    success: false,
                    latency: nil,
                    error: .proxyConnectionFailed("HTTP 状态码无效")
                )
            }

            let latency = Date().timeIntervalSince(startTime)
            return ConnectionTestResult(success: true, latency: latency, error: nil)
        } catch {
            return ConnectionTestResult(
                success: false,
                latency: nil,
                error: .proxyConnectionFailed(error.localizedDescription)
            )
        }
    }

    // MARK: - Configuration Management
    func saveConfiguration(_ configuration: ProxyConfiguration) async throws {
        var configurations = try await loadConfigurations()

        if let index = configurations.firstIndex(where: { $0.id == configuration.id }) {
            configurations[index] = configuration
        } else {
            configurations.append(configuration)
        }

        try await storage.saveArray(configurations, forKey: .proxyConfigurations)
    }

    func loadConfigurations() async throws -> [ProxyConfiguration] {
        return try await storage.loadArray(forKey: .proxyConfigurations)
    }

    func deleteConfiguration(id: UUID) async throws {
        try await storage.removeFromArray(id: id, forKey: .proxyConfigurations)
    }

    // MARK: - Private Methods
    private func setSystemProxy(configuration: ProxyConfiguration) async throws {
        // 使用 SystemConfiguration framework 设置系统代理
        guard let authData = try? await requestAuthorization() else {
            throw AppError.proxyNotAuthorized
        }

        guard let preferences = SCPreferencesCreateWithAuthorization(
            nil,
            "SwiftProxy" as CFString,
            nil,
            authData
        ) else {
            throw AppError.proxyConfigurationInvalid("无法创建系统偏好设置")
        }

        // 获取网络服务
        guard let services = SCNetworkServiceCopyAll(preferences) as? [SCNetworkService] else {
            throw AppError.proxyConfigurationInvalid("无法获取网络服务")
        }

        for service in services {
            try setProxyForService(service, configuration: configuration, preferences: preferences)
        }

        // 应用更改
        guard SCPreferencesCommitChanges(preferences) else {
            throw AppError.proxyConfigurationInvalid("无法提交系统代理更改")
        }

        guard SCPreferencesApplyChanges(preferences) else {
            throw AppError.proxyConfigurationInvalid("无法应用系统代理更改")
        }
    }

    private func clearSystemProxy() async throws {
        guard let authData = try? await requestAuthorization() else {
            throw AppError.proxyNotAuthorized
        }

        guard let preferences = SCPreferencesCreateWithAuthorization(
            nil,
            "SwiftProxy" as CFString,
            nil,
            authData
        ) else {
            throw AppError.proxyConfigurationInvalid("无法创建系统偏好设置")
        }

        guard let services = SCNetworkServiceCopyAll(preferences) as? [SCNetworkService] else {
            throw AppError.proxyConfigurationInvalid("无法获取网络服务")
        }

        for service in services {
            try clearProxyForService(service, preferences: preferences)
        }

        guard SCPreferencesCommitChanges(preferences),
              SCPreferencesApplyChanges(preferences) else {
            throw AppError.proxyConfigurationInvalid("无法清除系统代理")
        }
    }

    private func setProxyForService(
        _ service: SCNetworkService,
        configuration: ProxyConfiguration,
        preferences: SCPreferences
    ) throws {
        guard let protocolConfig = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeIPv4) else {
            return
        }

        let proxyDict: [String: Any]

        switch configuration.type {
        case .http:
            proxyDict = [
                kCFNetworkProxiesHTTPEnable as String: 1,
                kCFNetworkProxiesHTTPProxy as String: configuration.host,
                kCFNetworkProxiesHTTPPort as String: configuration.port
            ]
        case .https:
            proxyDict = [
                kCFNetworkProxiesHTTPSEnable as String: 1,
                kCFNetworkProxiesHTTPSProxy as String: configuration.host,
                kCFNetworkProxiesHTTPSPort as String: configuration.port
            ]
        case .socks5:
            proxyDict = [
                kCFNetworkProxiesSOCKSEnable as String: 1,
                kCFNetworkProxiesSOCKSProxy as String: configuration.host,
                kCFNetworkProxiesSOCKSPort as String: configuration.port
            ]
        }

        SCNetworkProtocolSetConfiguration(protocolConfig, proxyDict as CFDictionary)
    }

    private func clearProxyForService(_ service: SCNetworkService, preferences: SCPreferences) throws {
        guard let protocolConfig = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeIPv4) else {
            return
        }

        let proxyDict: [String: Any] = [
            kCFNetworkProxiesHTTPEnable as String: 0,
            kCFNetworkProxiesHTTPSEnable as String: 0,
            kCFNetworkProxiesSOCKSEnable as String: 0
        ]

        SCNetworkProtocolSetConfiguration(protocolConfig, proxyDict as CFDictionary)
    }

    private func requestAuthorization() async throws -> AuthorizationRef {
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)

        guard status == errAuthorizationSuccess, let auth = authRef else {
            throw AppError.proxyNotAuthorized
        }

        return auth
    }

    private func checkSystemProxyStatus() async {
        do {
            let settings = try await getCurrentSystemProxy()
            let isActive = settings.httpEnabled || settings.httpsEnabled || settings.socksEnabled

            isEnabledSubject.send(isActive)

            if isActive {
                // 尝试匹配已保存的配置
                let configurations = try await loadConfigurations()
                // 匹配逻辑...
            }
        } catch {
            logger.error("Failed to check system proxy status: \(error)")
        }
    }
}
```

---

## 5. Network Extension 实现

### SwiftProxyExtension/PacketTunnelProvider.swift
```swift
import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    private let logger = Logger(subsystem: "com.yourcompany.swiftproxy.extension", category: "PacketTunnel")
    private var trafficInterceptor: TrafficInterceptor?
    private var packetProcessor: PacketProcessor?

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("Starting packet tunnel")

        // 配置虚拟网络接口
        let tunnelNetworkSettings = createTunnelSettings()

        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to set tunnel settings: \(error)")
                completionHandler(error)
                return
            }

            // 启动流量拦截
            self.trafficInterceptor = TrafficInterceptor(provider: self)
            self.packetProcessor = PacketProcessor()

            self.startPacketFlow()
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping packet tunnel, reason: \(reason.rawValue)")

        trafficInterceptor?.stop()
        trafficInterceptor = nil
        packetProcessor = nil

        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // 处理来自主应用的消息
        logger.info("Received app message")

        do {
            let message = try JSONDecoder().decode(ExtensionMessage.self, from: messageData)
            handleMessage(message, completionHandler: completionHandler)
        } catch {
            logger.error("Failed to decode app message: \(error)")
            completionHandler?(nil)
        }
    }

    // MARK: - Private Methods
    private func createTunnelSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // IPv4 设置
        let ipv4Settings = NEIPv4Settings(addresses: ["192.168.0.1"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4Settings

        // DNS 设置
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        settings.dnsSettings = dnsSettings

        return settings
    }

    private func startPacketFlow() {
        // 读取数据包
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }

            Task {
                await self.processPackets(packets, protocols: protocols)
            }

            // 继续读取
            self.startPacketFlow()
        }
    }

    private func processPackets(_ packets: [Data], protocols: [NSNumber]) async {
        guard let processor = packetProcessor else { return }

        for (index, packet) in packets.enumerated() {
            let protocolFamily = protocols[index].int32Value

            if let processedPacket = await processor.process(packet, protocolFamily: protocolFamily) {
                // 写回处理后的数据包
                packetFlow.writePackets([processedPacket], withProtocols: [protocols[index]])
            }
        }
    }

    private func handleMessage(_ message: ExtensionMessage, completionHandler: ((Data?) -> Void)?) {
        switch message.type {
        case .updateRules:
            if let rulesData = message.payload {
                updateRules(rulesData)
            }
            completionHandler?(nil)

        case .getStatistics:
            let stats = getStatistics()
            if let statsData = try? JSONEncoder().encode(stats) {
                completionHandler?(statsData)
            } else {
                completionHandler?(nil)
            }

        case .clearLogs:
            clearLogs()
            completionHandler?(nil)
        }
    }

    private func updateRules(_ rulesData: Data) {
        do {
            let rules = try JSONDecoder().decode([ProxyRule].self, from: rulesData)
            packetProcessor?.updateRules(rules)
            logger.info("Rules updated: \(rules.count) rules")
        } catch {
            logger.error("Failed to update rules: \(error)")
        }
    }

    private func getStatistics() -> ExtensionStatistics {
        return ExtensionStatistics(
            totalPackets: packetProcessor?.totalPackets ?? 0,
            bytesIn: packetProcessor?.bytesIn ?? 0,
            bytesOut: packetProcessor?.bytesOut ?? 0,
            activeConnections: trafficInterceptor?.activeConnections ?? 0
        )
    }

    private func clearLogs() {
        packetProcessor?.clearLogs()
        logger.info("Logs cleared")
    }
}

// MARK: - Extension Messages
struct ExtensionMessage: Codable {
    let type: MessageType
    let payload: Data?

    enum MessageType: String, Codable {
        case updateRules
        case getStatistics
        case clearLogs
    }
}

struct ExtensionStatistics: Codable {
    let totalPackets: Int64
    let bytesIn: Int64
    let bytesOut: Int64
    let activeConnections: Int
}
```

---

这份文档提供了 SwiftProxy 的核心代码结构和实现示例。完整实现还需要包括：

1. 所有 Service 的完整实现
2. 所有 ViewModel 的完整实现
3. SwiftUI 视图层实现
4. Network Extension 的完整实现
5. 单元测试和 UI 测试
6. 工具类和扩展
7. 错误处理和日志系统

需要我继续补充其他部分吗？
