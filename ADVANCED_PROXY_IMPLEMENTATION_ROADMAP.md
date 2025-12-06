# SwiftProxy 高级代理功能实现路线图

## 🎯 项目目标

将 SwiftProxy 从简单的 HTTP/SOCKS5 代理管理工具升级为功能完整的现代化网络代理软件，支持：
- ✅ 订阅 URL 导入和管理
- ✅ Shadowsocks/ShadowsocksR 协议
- ✅ V2Ray/VMess/VLESS 协议
- ✅ Trojan 协议
- ✅ 智能分流（PAC/规则引擎）
- ✅ 本地协议转换服务器
- ✅ 自动延迟测试和节点选择

---

## 📊 整体架构设计

### 当前架构（Phase 0）
```
┌─────────────────────────────────────────────┐
│           SwiftProxy (macOS App)            │
├─────────────────────────────────────────────┤
│  UI Layer (SwiftUI)                         │
│  ├─ ProxyConfigView                         │
│  ├─ ConnectionListView                      │
│  └─ StatisticsView                          │
├─────────────────────────────────────────────┤
│  Service Layer                              │
│  ├─ ProxyService                            │
│  ├─ ConfigurationService                    │
│  └─ StatisticsService                       │
├─────────────────────────────────────────────┤
│  Core Models                                │
│  └─ ProxyConfiguration (HTTP/SOCKS5)        │
└─────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────┐
│     macOS System Proxy Settings             │
│     (SystemConfiguration Framework)         │
└─────────────────────────────────────────────┘
```

### 目标架构（Phase 4 完成后）
```
┌─────────────────────────────────────────────────────────────┐
│                SwiftProxy (macOS App)                       │
├─────────────────────────────────────────────────────────────┤
│  UI Layer (SwiftUI)                                         │
│  ├─ ProxyConfigView (增强)                                 │
│  ├─ SubscriptionManagerView (新增)                         │
│  ├─ RuleEditorView (新增)                                  │
│  ├─ NodeTestView (新增)                                    │
│  └─ AdvancedSettingsView (增强)                            │
├─────────────────────────────────────────────────────────────┤
│  Service Layer                                              │
│  ├─ SubscriptionService (新增)                             │
│  ├─ ProtocolService (新增)                                 │
│  ├─ RuleEngineService (新增)                               │
│  ├─ NodeTestService (新增)                                 │
│  └─ LocalProxyService (新增)                               │
├─────────────────────────────────────────────────────────────┤
│  Protocol Implementations (新增)                            │
│  ├─ ShadowsocksProtocol                                    │
│  ├─ V2RayProtocol                                          │
│  ├─ TrojanProtocol                                         │
│  └─ ProtocolAdapter (统一接口)                             │
├─────────────────────────────────────────────────────────────┤
│  Local Proxy Server (新增)                                 │
│  ├─ SOCKS5 Server (监听 127.0.0.1:1080)                    │
│  ├─ HTTP Proxy Server (监听 127.0.0.1:8080)                │
│  └─ Protocol Router (根据规则路由)                          │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│            macOS System Proxy Settings                      │
│            指向 → 127.0.0.1:1080 (本地 SOCKS5)              │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│     远程代理服务器 (SS/V2Ray/Trojan)                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 🗓️ 分阶段实现计划

### Phase 1: 订阅 URL 功能（2-3 天）
**优先级：高**
**难度：中等**

#### 目标
- 支持导入和管理订阅链接
- 自动解析主流订阅格式
- 定期更新订阅内容

#### 功能清单
- [ ] 订阅数据模型设计
- [ ] 订阅 URL 解析器（Base64/JSON）
- [ ] 支持格式：
  - [ ] Clash 订阅
  - [ ] V2Ray/V2RayN 订阅
  - [ ] Shadowsocks SIP008 订阅
  - [ ] 通用 Base64 订阅
- [ ] 订阅管理 UI
- [ ] 自动/手动更新订阅
- [ ] 订阅节点列表展示

#### 技术实现细节

**1.1 数据模型**
```swift
// SwiftProxy/Core/Models/Subscription.swift
public struct Subscription: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var url: String
    public var updateInterval: TimeInterval // 自动更新间隔
    public var lastUpdated: Date?
    public var nodes: [ProxyNode] // 从订阅解析的节点列表
    public var isEnabled: Bool
}

public struct ProxyNode: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var type: ProxyProtocol
    public var server: String
    public var port: Int
    public var credentials: ProxyCredentials
    public var latency: TimeInterval? // ping 测试结果
    public var subscriptionId: UUID // 所属订阅
}

public enum ProxyProtocol: String, Codable {
    case http
    case https
    case socks5
    case shadowsocks
    case shadowsocksR
    case vmess
    case vless
    case trojan
}

public struct ProxyCredentials: Codable {
    // SS 特定
    var method: String? // encryption method
    var password: String?

    // V2Ray 特定
    var uuid: String?
    var alterId: Int?
    var security: String?

    // 通用
    var username: String?
    var tls: Bool?
    var skipCertVerify: Bool?
}
```

**1.2 订阅解析器**
```swift
// SwiftProxy/Core/Services/SubscriptionParser.swift
public protocol SubscriptionParser {
    func parse(data: Data) throws -> [ProxyNode]
    func detectFormat(data: Data) -> SubscriptionFormat?
}

public enum SubscriptionFormat {
    case clash       // YAML
    case v2ray       // JSON
    case ss_sip008   // JSON
    case base64      // Base64 encoded URI list
}

public class ClashParser: SubscriptionParser {
    // 解析 Clash YAML 格式
    // 依赖: Yams (YAML parser)
}

public class V2RayParser: SubscriptionParser {
    // 解析 V2Ray JSON 格式
}

public class SIP008Parser: SubscriptionParser {
    // 解析 Shadowsocks SIP008 JSON
}

public class Base64Parser: SubscriptionParser {
    // 解析 Base64 编码的 URI 列表
    // ss://... vmess://... trojan://...
}
```

**1.3 订阅服务**
```swift
// SwiftProxy/Core/Services/SubscriptionService.swift
public class SubscriptionService {
    private let networkService: NetworkService
    private let storageService: StorageService
    private var subscriptions: [Subscription] = []

    // 添加订阅
    public func addSubscription(name: String, url: String) async throws

    // 更新订阅（拉取最新节点）
    public func updateSubscription(_ subscription: Subscription) async throws -> [ProxyNode]

    // 自动更新所有订阅
    public func startAutoUpdate()

    // 删除订阅
    public func deleteSubscription(_ id: UUID) async throws

    // 获取所有节点
    public func getAllNodes() -> [ProxyNode]

    // 根据订阅获取节点
    public func getNodes(for subscriptionId: UUID) -> [ProxyNode]
}
```

**1.4 UI 实现**
```swift
// SwiftProxy/UI/Views/SubscriptionManagerView.swift
struct SubscriptionManagerView: View {
    @ObservedObject var viewModel: SubscriptionViewModel

    var body: some View {
        List {
            // 订阅列表
            ForEach(viewModel.subscriptions) { sub in
                SubscriptionRow(subscription: sub)
            }
        }
        .toolbar {
            Button("Add Subscription") {
                showAddDialog = true
            }
        }
    }
}

// 添加订阅对话框
struct AddSubscriptionDialog: View {
    @State private var name = ""
    @State private var url = ""
    @State private var autoUpdate = true

    // ...
}
```

---

### Phase 2: Shadowsocks 协议支持（4-5 天）
**优先级：高**
**难度：高**

#### 目标
- 实现完整的 Shadowsocks 协议
- 支持主流加密算法
- 本地 SOCKS5 服务器实现

#### 技术选型

**方案 A: Swift 纯实现（推荐）**
- 优点：无外部依赖，代码可控，易于调试
- 缺点：需要自己实现所有加密算法
- 依赖库：
  - `CryptoKit` (Apple 官方，AES-GCM)
  - `BlueSocket` (IBM，TCP Socket)
  - 需要实现：AEAD ciphers (chacha20-poly1305, aes-256-gcm)

**方案 B: 集成 libss (C/C++)**
- 优点：功能完整，性能好
- 缺点：需要桥接 C 代码，增加复杂度
- 使用 shadowsocks-libev 的核心库

**推荐：方案 A**，更符合 Swift 生态

#### 功能清单
- [ ] Shadowsocks 协议实现
- [ ] 支持加密方法：
  - [ ] aes-256-gcm
  - [ ] aes-128-gcm
  - [ ] chacha20-ietf-poly1305
- [ ] SOCKS5 本地服务器
- [ ] 连接池管理
- [ ] 流量加密/解密
- [ ] UDP relay 支持（可选）

#### 技术实现细节

**2.1 核心协议实现**
```swift
// SwiftProxy/Core/Protocols/Shadowsocks/ShadowsocksProtocol.swift

import CryptoKit
import Network

public class ShadowsocksClient {
    private let server: String
    private let port: Int
    private let password: String
    private let method: EncryptionMethod

    public enum EncryptionMethod: String {
        case aes256gcm = "aes-256-gcm"
        case aes128gcm = "aes-128-gcm"
        case chacha20poly1305 = "chacha20-ietf-poly1305"
    }

    // 建立到 SS 服务器的连接
    public func connect() async throws -> NWConnection

    // 加密数据
    private func encrypt(_ data: Data, key: SymmetricKey, nonce: AES.GCM.Nonce) throws -> Data

    // 解密数据
    private func decrypt(_ data: Data, key: SymmetricKey, nonce: AES.GCM.Nonce) throws -> Data

    // 处理 SOCKS5 请求
    public func handleRequest(_ request: SOCKS5Request) async throws -> Data
}

// AEAD 加密实现
public class AEADCipher {
    private let key: SymmetricKey
    private let method: ShadowsocksClient.EncryptionMethod

    public func encrypt(plaintext: Data, associatedData: Data? = nil) throws -> (ciphertext: Data, tag: Data)
    public func decrypt(ciphertext: Data, tag: Data, associatedData: Data? = nil) throws -> Data
}
```

**2.2 本地 SOCKS5 服务器**
```swift
// SwiftProxy/Core/LocalProxy/SOCKS5Server.swift

import Network

public class SOCKS5Server {
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 1080
    private let queue = DispatchQueue(label: "com.swiftproxy.socks5")

    private var activeConnections: [UUID: SOCKS5Connection] = [:]
    private let protocolRouter: ProtocolRouter

    public func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        listener = try NWListener(using: params, on: port)

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: queue)
    }

    public func stop() {
        listener?.cancel()
        activeConnections.values.forEach { $0.close() }
        activeConnections.removeAll()
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let socks5Conn = SOCKS5Connection(
            connection: connection,
            router: protocolRouter
        )

        activeConnections[socks5Conn.id] = socks5Conn
        socks5Conn.start()
    }
}

// SOCKS5 连接处理
public class SOCKS5Connection {
    public let id = UUID()
    private let connection: NWConnection
    private let router: ProtocolRouter

    private enum State {
        case greeting      // SOCKS5 握手
        case authentication // 认证（如果需要）
        case request       // 接收请求
        case relay         // 数据转发
        case closed
    }

    private var state: State = .greeting

    public func start() {
        connection.start(queue: .global())
        receiveGreeting()
    }

    // SOCKS5 协议实现
    private func receiveGreeting() {
        // 1. 读取客户端 greeting (VER, NMETHODS, METHODS)
        // 2. 回复选择的认证方法
        // 3. 转到下一状态
    }

    private func receiveRequest() {
        // 1. 读取 SOCKS5 请求 (VER, CMD, RSV, ATYP, DST.ADDR, DST.PORT)
        // 2. 根据规则决定使用哪个协议
        // 3. 建立到目标的连接
    }

    private func relay(to remote: NWConnection) {
        // 双向数据转发
        // 客户端 <-> 本地 SOCKS5 <-> 协议适配器 <-> 远程服务器
    }
}
```

**2.3 协议路由器**
```swift
// SwiftProxy/Core/LocalProxy/ProtocolRouter.swift

public class ProtocolRouter {
    private let ruleEngine: RuleEngine
    private var protocolClients: [UUID: any ProxyProtocolClient] = [:]

    // 根据目标地址和规则决定使用哪个协议
    public func selectProtocol(for destination: Destination) -> ProxyNode? {
        return ruleEngine.match(destination: destination)
    }

    // 建立到远程服务器的连接
    public func connect(using node: ProxyNode, to destination: Destination) async throws -> NWConnection {
        switch node.type {
        case .shadowsocks:
            let client = ShadowsocksClient(config: node)
            return try await client.connect(to: destination)
        case .vmess:
            let client = V2RayClient(config: node)
            return try await client.connect(to: destination)
        // ... other protocols
        default:
            throw ProxyError.unsupportedProtocol
        }
    }
}

// 统一的协议客户端接口
public protocol ProxyProtocolClient {
    func connect(to destination: Destination) async throws -> NWConnection
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}
```

**2.4 依赖库添加**

在 `Package.swift` 中添加：
```swift
dependencies: [
    // 现有依赖...

    // 网络库
    .package(url: "https://github.com/IBM-Swift/BlueSocket.git", from: "2.0.0"),

    // YAML 解析（用于 Clash 订阅）
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
],
targets: [
    .target(
        name: "SwiftProxy",
        dependencies: [
            "BlueSocket",
            "Yams"
        ]
    ),
]
```

---

### Phase 3: V2Ray/VMess 协议支持（5-7 天）
**优先级：中**
**难度：极高**

#### 目标
- 实现 VMess 协议
- 支持 WebSocket 传输层
- 支持 TLS 加密传输

#### 技术选型

**方案 A: Swift 纯实现（极难）**
- 需要实现完整的 VMess 协议栈
- 需要实现 mKCP/WebSocket/HTTP/2 等传输层
- 工作量巨大

**方案 B: 集成 v2ray-core (Go)**
- 使用官方 v2ray-core
- 通过 XPC 或本地进程通信
- 维护成本低

**方案 C: 集成 V2RayKit (第三方 Swift 实现)**
- 查找是否有可用的 Swift 实现
- 可能不完整或不维护

**推荐：方案 B**，使用官方 v2ray-core

#### 功能清单
- [ ] 集成 v2ray-core 二进制
- [ ] V2Ray 配置生成
- [ ] 进程管理（启动/停止/监控）
- [ ] 支持传输层：
  - [ ] TCP
  - [ ] WebSocket
  - [ ] HTTP/2
  - [ ] mKCP
- [ ] TLS/XTLS 支持

#### 技术实现细节

**3.1 V2Ray Core 集成**
```swift
// SwiftProxy/Core/Protocols/V2Ray/V2RayCore.swift

import Foundation

public class V2RayCore {
    private var process: Process?
    private let executablePath: String
    private let configPath: String

    public init() {
        // v2ray-core 可执行文件打包在 app bundle 中
        let bundle = Bundle.main
        self.executablePath = bundle.path(forResource: "v2ray", ofType: nil)!
        self.configPath = bundle.path(forResource: "config", ofType: "json")!
    }

    // 启动 v2ray-core
    public func start(config: V2RayConfig) throws {
        // 1. 生成配置文件
        try config.write(to: URL(fileURLWithPath: configPath))

        // 2. 启动进程
        process = Process()
        process?.executableURL = URL(fileURLWithPath: executablePath)
        process?.arguments = ["-config", configPath]

        // 3. 监控输出
        let pipe = Pipe()
        process?.standardOutput = pipe
        process?.standardError = pipe

        try process?.run()
    }

    // 停止 v2ray-core
    public func stop() {
        process?.terminate()
        process = nil
    }

    // 检查状态
    public var isRunning: Bool {
        return process?.isRunning ?? false
    }
}
```

**3.2 V2Ray 配置生成**
```swift
// SwiftProxy/Core/Protocols/V2Ray/V2RayConfig.swift

public struct V2RayConfig: Codable {
    public var inbounds: [Inbound]
    public var outbounds: [Outbound]
    public var routing: Routing?

    public struct Inbound: Codable {
        var protocol: String = "socks"
        var listen: String = "127.0.0.1"
        var port: Int = 1080
        var settings: InboundSettings
    }

    public struct Outbound: Codable {
        var protocol: String // vmess, vless, etc
        var settings: OutboundSettings
        var streamSettings: StreamSettings?
    }

    public struct OutboundSettings: Codable {
        var vnext: [VNextServer]?

        struct VNextServer: Codable {
            var address: String
            var port: Int
            var users: [User]

            struct User: Codable {
                var id: String // UUID
                var alterId: Int
                var security: String // auto, aes-128-gcm, chacha20-poly1305
            }
        }
    }

    public struct StreamSettings: Codable {
        var network: String // tcp, ws, http, kcp
        var security: String? // none, tls
        var tlsSettings: TLSSettings?
        var wsSettings: WebSocketSettings?

        struct TLSSettings: Codable {
            var allowInsecure: Bool
            var serverName: String?
        }

        struct WebSocketSettings: Codable {
            var path: String
            var headers: [String: String]?
        }
    }

    // 从 ProxyNode 生成 V2Ray 配置
    public static func from(node: ProxyNode) -> V2RayConfig {
        // ... 配置转换逻辑
    }

    // 写入文件
    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
}
```

**3.3 打包 v2ray-core**

在项目中添加 v2ray-core：
```bash
# 下载 v2ray-core
wget https://github.com/v2fly/v2ray-core/releases/download/v5.x.x/v2ray-macos-64.zip

# 解压并复制到 Resources
unzip v2ray-macos-64.zip
cp v2ray SwiftProxy/Resources/

# 在 Xcode 中添加到 Copy Bundle Resources
```

---

### Phase 4: 规则引擎和智能分流（3-4 天）
**优先级：高**
**难度：中等**

#### 目标
- 实现灵活的规则引擎
- 支持多种匹配模式
- 智能分流（国内直连，国外走代理）

#### 功能清单
- [ ] 规则数据模型
- [ ] 规则匹配引擎
- [ ] 规则类型支持：
  - [ ] Domain（域名）
  - [ ] Domain-Suffix（域名后缀）
  - [ ] Domain-Keyword（域名关键字）
  - [ ] IP-CIDR（IP 段）
  - [ ] GeoIP（地理位置）
  - [ ] Process（进程名）
- [ ] 内置规则集（中国 IP/域名）
- [ ] 规则编辑器 UI
- [ ] PAC 文件生成（可选）

#### 技术实现细节

**4.1 规则数据模型**
```swift
// SwiftProxy/Core/Models/ProxyRule.swift

public struct ProxyRule: Identifiable, Codable {
    public let id: UUID
    public var type: RuleType
    public var pattern: String
    public var action: RuleAction
    public var priority: Int // 优先级，数字越小越优先
    public var enabled: Bool

    public enum RuleType: String, Codable {
        case domain         // 完全匹配域名
        case domainSuffix   // 域名后缀
        case domainKeyword  // 域名包含关键字
        case ipCIDR         // IP CIDR
        case geoIP          // 地理位置（CN, US, etc）
        case processName    // 进程名
        case port           // 端口
    }

    public enum RuleAction: String, Codable {
        case direct     // 直连
        case proxy      // 走代理
        case reject     // 拒绝
        case specificNode(UUID) // 使用特定节点
    }
}

// 规则集
public struct RuleSet: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var rules: [ProxyRule]
    public var isBuiltin: Bool  // 是否是内置规则集
    public var lastUpdated: Date?
}
```

**4.2 规则引擎**
```swift
// SwiftProxy/Core/Services/RuleEngine.swift

public class RuleEngine {
    private var rules: [ProxyRule] = []
    private let geoIPDatabase: GeoIPDatabase

    // 加载规则
    public func loadRules(_ rules: [ProxyRule]) {
        self.rules = rules.sorted { $0.priority < $1.priority }
    }

    // 匹配规则
    public func match(destination: Destination) -> RuleAction {
        for rule in rules where rule.enabled {
            if matches(rule: rule, destination: destination) {
                return rule.action
            }
        }

        // 默认动作
        return .direct
    }

    private func matches(rule: ProxyRule, destination: Destination) -> Bool {
        switch rule.type {
        case .domain:
            return destination.host == rule.pattern

        case .domainSuffix:
            return destination.host.hasSuffix(rule.pattern)

        case .domainKeyword:
            return destination.host.contains(rule.pattern)

        case .ipCIDR:
            guard let ip = destination.ip else { return false }
            return matchesCIDR(ip: ip, cidr: rule.pattern)

        case .geoIP:
            guard let ip = destination.ip else { return false }
            return geoIPDatabase.country(for: ip) == rule.pattern

        case .processName:
            return destination.processName == rule.pattern

        case .port:
            return String(destination.port) == rule.pattern
        }
    }

    private func matchesCIDR(ip: String, cidr: String) -> Bool {
        // CIDR 匹配实现
        // 例如: 192.168.1.0/24
    }
}

// 目标地址信息
public struct Destination {
    public let host: String
    public let port: Int
    public var ip: String?
    public var processName: String?
}
```

**4.3 GeoIP 数据库**
```swift
// SwiftProxy/Core/Services/GeoIPDatabase.swift

import MaxmindDB // 使用 MaxMind GeoLite2

public class GeoIPDatabase {
    private let db: MaxmindDB

    public init() throws {
        // 从 bundle 加载 GeoLite2-Country.mmdb
        let dbPath = Bundle.main.path(forResource: "GeoLite2-Country", ofType: "mmdb")!
        self.db = try MaxmindDB(path: dbPath)
    }

    public func country(for ip: String) -> String? {
        return try? db.lookup(ip)?["country"]?["iso_code"] as? String
    }
}
```

**4.4 内置规则集**
```swift
// SwiftProxy/Resources/builtin-rules.json

{
  "version": "2024.1",
  "rules": [
    {
      "name": "China Direct",
      "rules": [
        {"type": "geoIP", "pattern": "CN", "action": "direct"},
        {"type": "domainSuffix", "pattern": ".cn", "action": "direct"},
        {"type": "domainSuffix", "pattern": ".中国", "action": "direct"},
        {"type": "domainKeyword", "pattern": "baidu", "action": "direct"},
        {"type": "domainKeyword", "pattern": "taobao", "action": "direct"}
      ]
    },
    {
      "name": "Ad Block",
      "rules": [
        {"type": "domainSuffix", "pattern": "doubleclick.net", "action": "reject"},
        {"type": "domainSuffix", "pattern": "googleadservices.com", "action": "reject"}
      ]
    },
    {
      "name": "Global Proxy",
      "rules": [
        {"type": "domainSuffix", "pattern": "google.com", "action": "proxy"},
        {"type": "domainSuffix", "pattern": "youtube.com", "action": "proxy"},
        {"type": "domainSuffix", "pattern": "twitter.com", "action": "proxy"}
      ]
    }
  ]
}
```

---

## 📦 所需外部资源和依赖

### Swift Package Dependencies
```swift
// Package.swift
dependencies: [
    // 网络
    .package(url: "https://github.com/IBM-Swift/BlueSocket.git", from: "2.0.0"),

    // YAML 解析（Clash 订阅）
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),

    // GeoIP
    .package(url: "https://github.com/maxmind/MaxMind-DB-Reader-swift.git", from: "1.0.0"),
]
```

### 二进制文件
- **v2ray-core**: 从 v2fly releases 下载 macOS 版本
- **GeoLite2-Country.mmdb**: 从 MaxMind 下载（免费）
- **china-ip-list.txt**: 中国 IP 段列表

### 下载脚本
```bash
#!/bin/bash
# download-resources.sh

# V2Ray Core
echo "下载 v2ray-core..."
wget https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-macos-64.zip
unzip v2ray-macos-64.zip
mv v2ray SwiftProxy/Resources/

# GeoIP 数据库
echo "下载 GeoLite2 数据库..."
wget https://github.com/P3TERX/GeoLite.mmdb/releases/latest/download/GeoLite2-Country.mmdb
mv GeoLite2-Country.mmdb SwiftProxy/Resources/

# 中国 IP 列表
echo "下载中国 IP 列表..."
wget https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt
mv china_ip_list.txt SwiftProxy/Resources/

echo "资源下载完成！"
```

---

## 🧪 测试计划

### Phase 1 测试
- [ ] 单元测试：订阅解析器（各种格式）
- [ ] 集成测试：订阅更新流程
- [ ] UI 测试：订阅管理界面

### Phase 2 测试
- [ ] 单元测试：加密/解密算法
- [ ] 单元测试：SOCKS5 协议实现
- [ ] 集成测试：本地服务器启动/停止
- [ ] 功能测试：连接真实 SS 服务器

### Phase 3 测试
- [ ] 集成测试：v2ray-core 进程管理
- [ ] 功能测试：VMess 连接测试
- [ ] 性能测试：并发连接数

### Phase 4 测试
- [ ] 单元测试：规则匹配逻辑
- [ ] 单元测试：GeoIP 查询
- [ ] 集成测试：规则引擎
- [ ] 功能测试：分流准确性

---

## 📈 性能优化

### 连接池管理
```swift
public class ConnectionPool {
    private var pool: [String: [NWConnection]] = [:]
    private let maxConnectionsPerServer = 10

    public func getConnection(for server: String) -> NWConnection?
    public func returnConnection(_ connection: NWConnection, for server: String)
}
```

### 缓存策略
- DNS 查询结果缓存（TTL）
- GeoIP 查询结果缓存
- 规则匹配结果缓存

### 并发控制
- 限制同时进行的代理连接数
- 使用 Dispatch Semaphore 控制并发

---

## 🔐 安全考虑

### 敏感信息保护
- 订阅 URL 存储在 Keychain
- 节点密码使用 Keychain 存储
- 内存中的密钥使用完立即清除

### 网络安全
- 验证订阅 URL 的 HTTPS 证书
- 防止 DNS 泄漏
- WebRTC 泄漏防护（可选）

---

## 📚 学习资源

### Shadowsocks 协议
- 官方文档: https://shadowsocks.org/doc/
- AEAD 加密: https://shadowsocks.org/doc/aead.html
- SIP008 订阅: https://shadowsocks.org/doc/sip008.html

### V2Ray 协议
- V2Ray 配置: https://www.v2fly.org/config/
- VMess 协议: https://www.v2fly.org/developer/protocols/vmess.html

### SOCKS5 协议
- RFC 1928: https://www.rfc-editor.org/rfc/rfc1928

### Swift Network Framework
- Apple 文档: https://developer.apple.com/documentation/network
- WWDC 2018: https://developer.apple.com/videos/play/wwdc2018/715/

---

## 🎯 里程碑时间表

### Week 1-2: Phase 1（订阅功能）
- Day 1-2: 数据模型和订阅解析器
- Day 3-4: 订阅服务实现
- Day 5-6: UI 开发和测试
- Day 7: 集成测试和 bug 修复

### Week 3-4: Phase 2（Shadowsocks）
- Day 8-10: 加密算法实现
- Day 11-13: SOCKS5 服务器实现
- Day 14-15: SS 客户端实现
- Day 16: 集成测试
- Day 17: 性能优化

### Week 5-6: Phase 3（V2Ray）
- Day 18-20: V2Ray Core 集成
- Day 21-22: 配置生成器
- Day 23: WebSocket/TLS 支持
- Day 24: 测试和调试

### Week 7: Phase 4（规则引擎）
- Day 25-26: 规则引擎实现
- Day 27: GeoIP 集成
- Day 28: 内置规则集
- Day 29: 规则编辑器 UI
- Day 30: 全面测试

### Week 8: 优化和完善
- 性能优化
- UI/UX 改进
- 文档编写
- 发布准备

---

## 🚀 快速开始（立即可以做的）

### 第一步：创建分支
```bash
cd /Users/linhan/startup/SwiftProxy
git checkout -b feature/subscription-support
```

### 第二步：创建基础结构
```bash
# 创建新目录
mkdir -p SwiftProxy/Core/Protocols/Shadowsocks
mkdir -p SwiftProxy/Core/Protocols/V2Ray
mkdir -p SwiftProxy/Core/LocalProxy
mkdir -p SwiftProxy/Resources

# 创建占位文件
touch SwiftProxy/Core/Models/Subscription.swift
touch SwiftProxy/Core/Services/SubscriptionService.swift
touch SwiftProxy/UI/Views/SubscriptionManagerView.swift
```

### 第三步：开始实现 Phase 1
从订阅数据模型开始，这是最基础且最容易的部分。

---

## 💡 建议

1. **分阶段开发**：不要一次实现所有功能，按 Phase 顺序逐步推进
2. **测试驱动**：每个功能都要有对应的单元测试
3. **代码复审**：重要模块实现后进行 code review
4. **性能监控**：使用 Instruments 监控内存和 CPU 使用
5. **用户反馈**：每个 Phase 完成后可以发布 beta 版本收集反馈

---

## 🤝 社区和开源

考虑将 SwiftProxy 开源：
- 吸引贡献者
- 接受社区 PR
- 建立用户社区
- 提供详细文档

推荐的开源协议：
- MIT License（最宽松）
- GPL v3（如果希望衍生作品也开源）

---

**准备好开始了吗？让我知道你想从哪个 Phase 开始！** 🚀
