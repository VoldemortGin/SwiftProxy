# SwiftProxy 应用架构设计文档

## 1. 项目概述

SwiftProxy 是一个基于 Swift 和 SwiftUI 开发的 macOS 原生网络代理管理应用，提供系统代理控制、实时监控、规则管理和流量统计功能。

### 技术栈
- Swift 5.9+
- SwiftUI
- macOS 14.0+
- Network Extension Framework
- Combine Framework
- MVVM 架构模式

---

## 2. 项目目录结构

```
SwiftProxy/
├── SwiftProxy.xcodeproj/
├── SwiftProxy/                          # 主应用模块
│   ├── App/
│   │   ├── SwiftProxyApp.swift         # 应用入口
│   │   ├── AppDelegate.swift           # AppKit 生命周期
│   │   └── DependencyContainer.swift   # 依赖注入容器
│   │
│   ├── Core/                           # 核心基础设施
│   │   ├── Extensions/                 # Swift 扩展
│   │   ├── Protocols/                  # 核心协议定义
│   │   ├── Utils/                      # 工具类
│   │   └── Constants/                  # 常量定义
│   │
│   ├── Models/                         # 数据模型层
│   │   ├── Domain/                     # 领域模型
│   │   │   ├── ProxyConfiguration.swift
│   │   │   ├── NetworkRequest.swift
│   │   │   ├── ProxyRule.swift
│   │   │   ├── TrafficStatistics.swift
│   │   │   └── ConnectionLog.swift
│   │   ├── DTO/                        # 数据传输对象
│   │   └── Enums/                      # 枚举定义
│   │
│   ├── Services/                       # 业务服务层
│   │   ├── ProxyService/               # 代理服务
│   │   │   ├── ProxyService.swift
│   │   │   └── ProxyServiceProtocol.swift
│   │   ├── NetworkMonitor/             # 网络监控
│   │   │   ├── NetworkMonitorService.swift
│   │   │   └── NetworkMonitorProtocol.swift
│   │   ├── RuleEngine/                 # 规则引擎
│   │   │   ├── RuleEngineService.swift
│   │   │   └── RuleEngineProtocol.swift
│   │   ├── TrafficAnalyzer/            # 流量分析
│   │   │   ├── TrafficAnalyzerService.swift
│   │   │   └── TrafficAnalyzerProtocol.swift
│   │   └── Storage/                    # 数据存储
│   │       ├── StorageService.swift
│   │       └── StorageProtocol.swift
│   │
│   ├── ViewModels/                     # 视图模型层
│   │   ├── DashboardViewModel.swift
│   │   ├── ProxyControlViewModel.swift
│   │   ├── MonitorViewModel.swift
│   │   ├── RulesViewModel.swift
│   │   └── StatisticsViewModel.swift
│   │
│   ├── Views/                          # 视图层
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   └── Components/
│   │   ├── ProxyControl/
│   │   │   ├── ProxyControlView.swift
│   │   │   └── Components/
│   │   ├── Monitor/
│   │   │   ├── MonitorView.swift
│   │   │   └── Components/
│   │   ├── Rules/
│   │   │   ├── RulesView.swift
│   │   │   └── Components/
│   │   ├── Statistics/
│   │   │   ├── StatisticsView.swift
│   │   │   └── Components/
│   │   └── Common/                     # 通用组件
│   │       ├── CustomButton.swift
│   │       ├── CustomTextField.swift
│   │       └── LoadingView.swift
│   │
│   ├── Resources/                      # 资源文件
│   │   ├── Assets.xcassets/
│   │   ├── Localizable.strings
│   │   └── Info.plist
│   │
│   └── Supporting Files/
│       └── SwiftProxy.entitlements
│
├── SwiftProxyExtension/                # Network Extension 模块
│   ├── PacketTunnelProvider.swift
│   ├── ProxyProvider.swift
│   ├── TrafficInterceptor.swift
│   ├── PacketProcessor.swift
│   └── Info.plist
│
├── SwiftProxyCore/                     # 共享核心库
│   ├── SharedModels/
│   ├── SharedProtocols/
│   └── SharedUtils/
│
├── SwiftProxyTests/                    # 单元测试
│   ├── ServiceTests/
│   ├── ViewModelTests/
│   └── ModelTests/
│
├── SwiftProxyUITests/                  # UI 测试
│
└── Packages/                           # Swift Package 依赖
    └── Package.swift
```

---

## 3. 核心模块划分

### 3.1 应用层 (App Layer)
- 应用生命周期管理
- 依赖注入容器
- 全局状态管理

### 3.2 视图层 (View Layer)
- SwiftUI 视图组件
- 视图组合和布局
- 用户交互处理

### 3.3 视图模型层 (ViewModel Layer)
- 业务逻辑编排
- 状态管理
- 数据绑定

### 3.4 服务层 (Service Layer)
- 代理服务：系统代理配置
- 网络监控：流量监控和日志
- 规则引擎：规则匹配和应用
- 流量分析：统计和分析
- 存储服务：数据持久化

### 3.5 模型层 (Model Layer)
- 领域模型定义
- 数据传输对象
- 枚举和常量

### 3.6 Extension 模块
- Network Extension Provider
- 数据包拦截和处理
- 与主应用通信

---

## 4. 数据流架构

```
User Interaction (View)
        ↓
    ViewModel (State Management)
        ↓
    Service Layer (Business Logic)
        ↓
    Storage / Network Extension
        ↓
    System / Network
```

### 数据流特点
- 单向数据流
- Combine 实现响应式编程
- @Published 属性自动更新 UI
- async/await 处理异步操作

---

## 5. 关键类和协议设计

### 5.1 核心协议

#### ServiceProtocol
```swift
protocol ServiceProtocol: AnyObject {
    associatedtype Input
    associatedtype Output

    func execute(_ input: Input) async throws -> Output
}
```

#### ProxyServiceProtocol
```swift
protocol ProxyServiceProtocol: AnyObject {
    var isEnabled: AnyPublisher<Bool, Never> { get }
    var currentConfiguration: AnyPublisher<ProxyConfiguration?, Never> { get }

    func enable(configuration: ProxyConfiguration) async throws
    func disable() async throws
    func updateConfiguration(_ configuration: ProxyConfiguration) async throws
    func getCurrentSystemProxy() async throws -> SystemProxySettings
}
```

#### NetworkMonitorProtocol
```swift
protocol NetworkMonitorProtocol: AnyObject {
    var requests: AnyPublisher<[NetworkRequest], Never> { get }
    var connectionLogs: AnyPublisher<[ConnectionLog], Never> { get }

    func startMonitoring() async throws
    func stopMonitoring() async throws
    func clearLogs() async
}
```

#### RuleEngineProtocol
```swift
protocol RuleEngineProtocol: AnyObject {
    var rules: AnyPublisher<[ProxyRule], Never> { get }

    func addRule(_ rule: ProxyRule) async throws
    func updateRule(_ rule: ProxyRule) async throws
    func deleteRule(id: UUID) async throws
    func matchRule(for request: NetworkRequest) -> ProxyRule?
    func importRules(from url: URL) async throws
    func exportRules(to url: URL) async throws
}
```

### 5.2 核心模型

#### ProxyConfiguration
```swift
struct ProxyConfiguration: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: ProxyType
    var host: String
    var port: Int
    var username: String?
    var password: String?
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum ProxyType: String, Codable, CaseIterable {
    case http = "HTTP"
    case https = "HTTPS"
    case socks5 = "SOCKS5"
}
```

#### NetworkRequest
```swift
struct NetworkRequest: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let method: HTTPMethod
    let url: URL
    let host: String
    let port: Int
    var status: RequestStatus
    var responseCode: Int?
    var duration: TimeInterval?
    var bytesIn: Int64
    var bytesOut: Int64
    let processName: String?
    var appliedRule: ProxyRule?
}

enum RequestStatus: String, Codable {
    case pending
    case connected
    case completed
    case failed
}
```

#### ProxyRule
```swift
struct ProxyRule: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var ruleType: RuleType
    var pattern: String
    var action: RuleAction
    var isEnabled: Bool
    var priority: Int
    var createdAt: Date
    var updatedAt: Date
}

enum RuleType: String, Codable, CaseIterable {
    case domain = "Domain"
    case domainSuffix = "Domain Suffix"
    case domainKeyword = "Domain Keyword"
    case ipCIDR = "IP-CIDR"
    case geoIP = "GeoIP"
    case processName = "Process Name"
}

enum RuleAction: String, Codable, CaseIterable {
    case direct = "DIRECT"
    case proxy = "PROXY"
    case reject = "REJECT"
}
```

#### TrafficStatistics
```swift
struct TrafficStatistics: Codable {
    var totalRequests: Int
    var directRequests: Int
    var proxyRequests: Int
    var failedRequests: Int
    var totalBytesIn: Int64
    var totalBytesOut: Int64
    var averageLatency: TimeInterval
    var peakConnectionsPerMinute: Int
    var topDomains: [DomainStats]
    var hourlyTraffic: [HourlyTraffic]
}

struct DomainStats: Codable, Identifiable {
    let id: UUID
    let domain: String
    var requestCount: Int
    var bytesIn: Int64
    var bytesOut: Int64
}

struct HourlyTraffic: Codable, Identifiable {
    let id: UUID
    let hour: Date
    var requests: Int
    var bytesIn: Int64
    var bytesOut: Int64
}
```

---

## 6. 依赖注入方案

### DependencyContainer
```swift
final class DependencyContainer: ObservableObject {
    // MARK: - Singleton
    static let shared = DependencyContainer()

    // MARK: - Services
    private(set) lazy var proxyService: ProxyServiceProtocol = {
        ProxyService(storage: storageService)
    }()

    private(set) lazy var networkMonitor: NetworkMonitorProtocol = {
        NetworkMonitorService(
            proxyService: proxyService,
            ruleEngine: ruleEngine
        )
    }()

    private(set) lazy var ruleEngine: RuleEngineProtocol = {
        RuleEngineService(storage: storageService)
    }()

    private(set) lazy var trafficAnalyzer: TrafficAnalyzerProtocol = {
        TrafficAnalyzerService(storage: storageService)
    }()

    private(set) lazy var storageService: StorageProtocol = {
        StorageService()
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
        RulesViewModel(
            ruleEngine: ruleEngine
        )
    }

    func makeStatisticsViewModel() -> StatisticsViewModel {
        StatisticsViewModel(
            trafficAnalyzer: trafficAnalyzer
        )
    }

    private init() {}
}
```

---

## 7. 错误处理策略

### AppError 枚举
```swift
enum AppError: LocalizedError {
    // Proxy Errors
    case proxyNotAuthorized
    case proxyConfigurationInvalid(String)
    case proxyConnectionFailed(String)
    case proxyAlreadyEnabled

    // Network Extension Errors
    case extensionNotInstalled
    case extensionActivationFailed(String)
    case extensionCommunicationFailed

    // Storage Errors
    case storageReadFailed(String)
    case storageWriteFailed(String)
    case storageMigrationFailed(String)

    // Rule Engine Errors
    case ruleValidationFailed(String)
    case ruleDuplicateFound
    case ruleImportFailed(String)

    // Network Errors
    case networkUnavailable
    case requestTimeout
    case invalidURL(String)

    // General Errors
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .proxyNotAuthorized:
            return "需要系统授权才能修改代理设置"
        case .proxyConfigurationInvalid(let reason):
            return "代理配置无效: \(reason)"
        case .proxyConnectionFailed(let reason):
            return "代理连接失败: \(reason)"
        case .proxyAlreadyEnabled:
            return "代理已经启用"
        case .extensionNotInstalled:
            return "Network Extension 未安装"
        case .extensionActivationFailed(let reason):
            return "Extension 激活失败: \(reason)"
        case .extensionCommunicationFailed:
            return "与 Extension 通信失败"
        case .storageReadFailed(let reason):
            return "读取数据失败: \(reason)"
        case .storageWriteFailed(let reason):
            return "保存数据失败: \(reason)"
        case .storageMigrationFailed(let reason):
            return "数据迁移失败: \(reason)"
        case .ruleValidationFailed(let reason):
            return "规则验证失败: \(reason)"
        case .ruleDuplicateFound:
            return "规则已存在"
        case .ruleImportFailed(let reason):
            return "规则导入失败: \(reason)"
        case .networkUnavailable:
            return "网络不可用"
        case .requestTimeout:
            return "请求超时"
        case .invalidURL(let url):
            return "无效的URL: \(url)"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}
```

### Result 类型使用
```swift
typealias AppResult<T> = Result<T, AppError>

// 在 ViewModel 中使用
@Published var operationState: OperationState = .idle

enum OperationState {
    case idle
    case loading
    case success(String)
    case failure(AppError)
}
```

---

## 8. 测试架构

### 8.1 测试策略
- 单元测试覆盖率目标: 80%+
- 使用 Mock 对象隔离依赖
- 异步测试使用 XCTestExpectation
- UI 测试覆盖关键用户流程

### 8.2 Mock 协议实现
```swift
final class MockProxyService: ProxyServiceProtocol {
    var isEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    var configurationSubject = CurrentValueSubject<ProxyConfiguration?, Never>(nil)
    var currentConfiguration: AnyPublisher<ProxyConfiguration?, Never> {
        configurationSubject.eraseToAnyPublisher()
    }

    var enableCalled = false
    var disableCalled = false

    func enable(configuration: ProxyConfiguration) async throws {
        enableCalled = true
        isEnabledSubject.send(true)
        configurationSubject.send(configuration)
    }

    func disable() async throws {
        disableCalled = true
        isEnabledSubject.send(false)
        configurationSubject.send(nil)
    }

    func updateConfiguration(_ configuration: ProxyConfiguration) async throws {
        configurationSubject.send(configuration)
    }

    func getCurrentSystemProxy() async throws -> SystemProxySettings {
        SystemProxySettings(httpEnabled: false, httpsEnabled: false)
    }
}
```

### 8.3 ViewModel 测试示例
```swift
final class ProxyControlViewModelTests: XCTestCase {
    var sut: ProxyControlViewModel!
    var mockProxyService: MockProxyService!
    var mockStorageService: MockStorageService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockProxyService = MockProxyService()
        mockStorageService = MockStorageService()
        sut = ProxyControlViewModel(
            proxyService: mockProxyService,
            storageService: mockStorageService
        )
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockStorageService = nil
        mockProxyService = nil
        super.tearDown()
    }

    func testEnableProxy_Success() async throws {
        // Given
        let config = ProxyConfiguration(
            id: UUID(),
            name: "Test Proxy",
            type: .http,
            host: "127.0.0.1",
            port: 8080,
            isDefault: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        // When
        await sut.enableProxy(configuration: config)

        // Then
        XCTAssertTrue(mockProxyService.enableCalled)
        XCTAssertEqual(sut.operationState, .success("代理已启用"))
    }
}
```

---

## 9. 性能优化策略

### 9.1 内存管理
- 使用 `@StateObject` 和 `@ObservedObject` 管理视图生命周期
- 避免循环引用，使用 `[weak self]`
- 及时释放大对象和取消订阅

### 9.2 网络监控优化
- 使用环形缓冲区限制日志数量
- 实现分页加载机制
- 后台线程处理数据包

### 9.3 UI 渲染优化
- 使用 `LazyVStack` 和 `LazyHStack`
- 避免在视图中进行复杂计算
- 使用 `@ViewBuilder` 优化视图组合

---

## 10. 安全考虑

### 10.1 权限管理
- 系统代理修改需要管理员权限
- Network Extension 需要用户授权
- 敏感数据加密存储

### 10.2 数据安全
- 使用 Keychain 存储密码
- HTTPS 代理支持 TLS/SSL
- 日志脱敏处理

### 10.3 沙盒限制
- 遵循 macOS 沙盒规则
- 最小权限原则
- App Group 用于进程间通信

---

## 11. 扩展性设计

### 11.1 插件化架构
- 规则引擎支持自定义匹配器
- 支持第三方规则格式导入
- 可扩展的协议支持

### 11.2 配置化
- 外部化配置文件
- 支持主题定制
- 国际化支持

### 11.3 API 设计
- 预留 CLI 接口
- 支持 URL Scheme
- AppleScript 自动化支持

---

## 12. 部署和分发

### 12.1 代码签名
- Developer ID 签名
- Network Extension 单独签名
- 公证（Notarization）

### 12.2 沙盒和权限
```xml
<!-- SwiftProxy.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourcompany.swiftproxy</string>
</array>
```

### 12.3 分发方式
- Mac App Store
- 独立分发（公证）
- TestFlight Beta 测试

---

## 13. 监控和日志

### 13.1 日志系统
```swift
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier!

    static let proxy = Logger(subsystem: subsystem, category: "Proxy")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let rules = Logger(subsystem: subsystem, category: "Rules")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
}
```

### 13.2 性能监控
- 使用 Instruments 分析
- 关键路径性能埋点
- 崩溃日志收集

---

## 14. 开发规范

### 14.1 代码风格
- 遵循 Swift API Design Guidelines
- 使用 SwiftLint 进行代码检查
- 统一命名规范

### 14.2 Git 工作流
- 主分支保护
- Feature Branch 开发
- Code Review 机制
- 语义化版本号

### 14.3 文档要求
- 公共 API 必须添加注释
- 复杂算法添加说明
- README 和 CHANGELOG 维护

---

## 总结

本架构设计遵循以下原则：
1. **分层清晰**：严格的层次划分，职责明确
2. **可测试性**：依赖注入，协议驱动，易于 Mock
3. **可维护性**：MVVM 模式，单一职责
4. **可扩展性**：插件化设计，配置外部化
5. **性能优先**：异步处理，内存优化
6. **安全可靠**：权限管理，数据加密，错误处理

此架构为 SwiftProxy 提供了坚实的技术基础，支持快速迭代和长期维护。
