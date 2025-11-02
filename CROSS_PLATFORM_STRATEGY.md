# SwiftProxy 跨平台策略

**日期:** 2025-11-02
**版本:** 1.0
**状态:** 设计方案

---

## 🎯 目标平台

1. **macOS** (12.0+) - ✅ 已实现
2. **iOS/iPadOS** (15.0+) - 🔄 待实现
3. **tvOS** (15.0+) - 🔄 待实现
4. **watchOS** (8.0+) - 🔄 可选

---

## 📊 平台特性分析

### macOS 平台
**优势:**
- 完整的系统权限
- 菜单栏常驻
- 完整的 UI 空间
- Network Extension 支持
- 文件系统完全访问

**限制:**
- 需要沙盒配置
- 可能需要公证

**使用场景:**
- 主要开发工作站
- 完整功能管理中心
- 规则编辑和调试

---

### iOS/iPadOS 平台
**优势:**
- 用户基数最大
- Shortcuts 集成
- Widget 快速操作
- Share Extension
- iCloud 同步

**限制:**
- ⚠️ **必须使用 Network Extension**
- NEPacketTunnelProvider (VPN-like)
- 后台运行受限
- 沙盒严格
- 不能直接拦截系统流量（需要 VPN 配置）

**使用场景:**
- 移动办公
- 出差旅行
- 快速切换代理
- 紧急配置调整

**技术方案:**
```
iOS App (UI)
    ↓
Network Extension (Packet Tunnel Provider)
    ↓
Shared Core (ProxyServer, Rules, GeoIP)
```

---

### tvOS 平台
**优势:**
- 客厅场景
- 家庭共享
- 流媒体优化

**限制:**
- UI 极简
- 输入困难
- 资源有限
- Network Extension 支持有限

**使用场景:**
- 智能电视代理
- 流媒体服务
- 家庭网络节点

**技术方案:**
- 简化的 UI（遥控器操作）
- 从 iCloud 同步配置
- 基本的开关功能
- 状态显示

---

### watchOS 平台
**优势:**
- 快速操作
- 状态查看
- 通知提醒

**限制:**
- 屏幕小
- 资源极度受限
- 依赖 iPhone
- 不支持 Network Extension

**使用场景:**
- 快速开关代理
- 查看连接状态
- 接收通知

**技术方案:**
- Watch App 只做 UI
- 所有功能通过 iPhone 处理
- WatchConnectivity 通信
- 极简界面

---

## 🏗️ 架构设计

### 方案：共享核心 + 平台特定 UI

```
┌─────────────────────────────────────────┐
│         Shared Core (所有平台)           │
│  ┌────────────────────────────────────┐ │
│  │ NetworkEngine (HTTP/2, WebSocket)  │ │
│  │ - ProxyServer                      │ │
│  │ - HTTP2Connection                  │ │
│  │ - WebSocketConnection              │ │
│  │ - ProxyConnection                  │ │
│  └────────────────────────────────────┘ │
│  ┌────────────────────────────────────┐ │
│  │ Rules Engine                       │ │
│  │ - RuleEngine                       │ │
│  │ - ProxyRule, RuleGroup             │ │
│  │ - GeoIPRuleEngine                  │ │
│  └────────────────────────────────────┘ │
│  ┌────────────────────────────────────┐ │
│  │ GeoIP                              │ │
│  │ - LocalGeoIPProvider               │ │
│  │ - IPRange database                 │ │
│  └────────────────────────────────────┘ │
│  ┌────────────────────────────────────┐ │
│  │ Performance                        │ │
│  │ - RateLimiter                      │ │
│  │ - BufferPool                       │ │
│  │ - MemoryPressureHandler            │ │
│  │ - StatisticsBatcher                │ │
│  └────────────────────────────────────┘ │
│  ┌────────────────────────────────────┐ │
│  │ Data Models                        │ │
│  │ - ProxyConfiguration               │ │
│  │ - NetworkRequest                   │ │
│  │ - TrafficStatistics                │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
            ↓           ↓           ↓
    ┌───────────┐ ┌──────────┐ ┌──────────┐
    │  macOS    │ │   iOS    │ │  tvOS    │
    │  ┌─────┐  │ │  ┌─────┐ │ │  ┌─────┐ │
    │  │ App │  │ │  │ App │ │ │  │ App │ │
    │  └─────┘  │ │  └─────┘ │ │  └─────┘ │
    │  ┌─────┐  │ │  ┌─────┐ │ │          │
    │  │ UI  │  │ │  │ UI  │ │ │  简化UI  │
    │  │AppKit│ │ │  │UIKit│ │ │          │
    │  └─────┘  │ │  └─────┘ │ │          │
    │           │ │  ┌─────┐ │ │          │
    │  菜单栏   │ │  │ NE  │ │ │          │
    │           │ │  │Ext  │ │ │          │
    │           │ │  └─────┘ │ │          │
    └───────────┘ └──────────┘ └──────────┘
```

---

## 📁 项目结构重组

### 推荐结构

```
SwiftProxy/
├── Shared/                         # 所有平台共享 (Framework)
│   ├── Core/
│   │   ├── NetworkEngine/
│   │   │   ├── ProxyServer.swift
│   │   │   ├── ProxyConnection.swift
│   │   │   ├── HTTP2Connection.swift
│   │   │   ├── HTTP2Frame.swift
│   │   │   ├── HTTP2Stream.swift
│   │   │   ├── WebSocketConnection.swift
│   │   │   ├── WebSocketFrame.swift
│   │   │   ├── ConnectionPool.swift
│   │   │   ├── SSLHandler.swift
│   │   │   └── RetryHandler.swift
│   │   ├── Rules/
│   │   │   ├── ProxyRule.swift
│   │   │   ├── RuleEngine.swift
│   │   │   └── GeoIPRuleEngine.swift
│   │   ├── GeoIP/
│   │   │   └── GeoIPProvider.swift
│   │   └── Performance/
│   │       ├── RateLimiter.swift
│   │       ├── BufferPool.swift
│   │       ├── MemoryPressureHandler.swift
│   │       └── StatisticsBatcher.swift
│   └── Models/
│       ├── ProxyConfiguration.swift
│       ├── NetworkRequest.swift
│       ├── TrafficStatistics.swift
│       └── AppError.swift
│
├── macOS/                          # macOS 专用
│   ├── App/
│   │   ├── SwiftProxyApp.swift
│   │   └── AppDelegate.swift
│   ├── UI/
│   │   ├── Views/
│   │   │   ├── MainView.swift
│   │   │   ├── SettingsView.swift
│   │   │   ├── RulesView.swift
│   │   │   └── StatisticsView.swift
│   │   └── ViewModels/
│   │       └── MainViewModel.swift
│   ├── Services/
│   │   └── ProxyService.swift
│   └── Resources/
│       └── Assets.xcassets
│
├── iOS/                            # iOS/iPadOS 专用
│   ├── App/
│   │   ├── SwiftProxyiOSApp.swift
│   │   └── SceneDelegate.swift
│   ├── UI/
│   │   ├── Views/
│   │   │   ├── HomeView.swift          # 主界面
│   │   │   ├── ConfigListView.swift    # 配置列表
│   │   │   ├── RuleEditorView.swift    # 规则编辑
│   │   │   └── StatsView.swift         # 统计信息
│   │   └── ViewModels/
│   │       └── ProxyViewModel.swift
│   ├── Extensions/
│   │   ├── PacketTunnel/               # Network Extension
│   │   │   ├── PacketTunnelProvider.swift
│   │   │   └── Info.plist
│   │   ├── ShareExtension/             # 分享配置
│   │   │   └── ShareViewController.swift
│   │   └── WidgetExtension/            # Widget
│   │       └── ProxyWidget.swift
│   └── Resources/
│       └── Assets.xcassets
│
├── tvOS/                           # tvOS 专用
│   ├── App/
│   │   └── SwiftProxyTVApp.swift
│   ├── UI/
│   │   ├── Views/
│   │   │   ├── TVHomeView.swift        # TV 主界面
│   │   │   ├── TVSettingsView.swift    # 简化设置
│   │   │   └── TVStatusView.swift      # 状态显示
│   │   └── ViewModels/
│   │       └── TVProxyViewModel.swift
│   └── Resources/
│       └── Assets.xcassets
│
├── watchOS/                        # watchOS 专用 (可选)
│   ├── App/
│   │   └── SwiftProxyWatchApp.swift
│   ├── UI/
│   │   └── Views/
│   │       ├── ControlView.swift       # 开关控制
│   │       └── StatusView.swift        # 状态显示
│   └── WatchConnectivity/
│       └── PhoneConnector.swift
│
└── Tests/                          # 测试
    ├── SharedTests/                # 共享代码测试
    ├── macOSTests/
    ├── iOSTests/
    └── IntegrationTests/
```

---

## 🔧 iOS Network Extension 实现

### iOS 的关键差异

iOS 上运行代理服务器需要通过 **Network Extension**，不能直接在 App 进程中运行。

### PacketTunnelProvider 实现

```swift
// iOS/Extensions/PacketTunnel/PacketTunnelProvider.swift
import NetworkExtension
import Shared  // 导入共享框架

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var proxyServer: ProxyServer?
    private var ruleEngine: GeoIPRuleEngine?

    override func startTunnel(
        options: [String : NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        // 1. 读取配置
        let configuration = loadConfiguration()

        // 2. 设置虚拟网络接口
        let networkSettings = createNetworkSettings()

        setTunnelNetworkSettings(networkSettings) { error in
            if let error = error {
                completionHandler(error)
                return
            }

            // 3. 启动代理服务器（使用共享代码）
            Task {
                do {
                    self.proxyServer = try await self.startProxyServer(configuration)
                    self.ruleEngine = await self.loadRuleEngine()
                    completionHandler(nil)
                } catch {
                    completionHandler(error)
                }
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        // 停止代理服务器
        Task {
            await proxyServer?.stop()
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data,
                                   completionHandler: ((Data?) -> Void)?) {
        // 处理来自主 App 的消息（配置更新等）
        // ...
    }

    // 使用共享的 ProxyServer
    private func startProxyServer(_ config: ProxyConfiguration) async throws -> ProxyServer {
        let server = ProxyServer(
            configuration: config,
            logger: OSLog(subsystem: "com.swiftproxy.ios", category: "tunnel")
        )

        try await server.start()
        return server
    }

    private func loadRuleEngine() async -> GeoIPRuleEngine {
        let engine = GeoIPRuleEngine()
        // 加载规则...
        return engine
    }

    private func createNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // IPv4 设置
        let ipv4Settings = NEIPv4Settings(
            addresses: ["172.16.0.1"],
            subnetMasks: ["255.255.255.0"]
        )
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4Settings

        // DNS 设置
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        settings.dnsSettings = dnsSettings

        return settings
    }

    private func loadConfiguration() -> ProxyConfiguration {
        // 从 App Group 共享容器读取配置
        let sharedDefaults = UserDefaults(suiteName: "group.com.swiftproxy")
        // ...
        return ProxyConfiguration.default
    }
}
```

### iOS App 与 Extension 通信

```swift
// iOS/App/Services/VPNManager.swift
import NetworkExtension

class VPNManager: ObservableObject {
    @Published var status: NEVPNStatus = .disconnected
    private var manager: NETunnelProviderManager?

    func setup() async throws {
        // 加载或创建 VPN 配置
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()

        if let existing = managers.first {
            self.manager = existing
        } else {
            let manager = NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()

            proto.providerBundleIdentifier = "com.swiftproxy.ios.tunnel"
            proto.serverAddress = "SwiftProxy"

            manager.protocolConfiguration = proto
            manager.localizedDescription = "SwiftProxy"
            manager.isEnabled = true

            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()

            self.manager = manager
        }

        // 监听状态变化
        observeStatus()
    }

    func start() async throws {
        guard let manager = manager else { return }
        try manager.connection.startVPNTunnel()
    }

    func stop() {
        manager?.connection.stopVPNTunnel()
    }

    func sendMessage(_ message: Data) async throws -> Data? {
        guard let session = manager?.connection as? NETunnelProviderSession else {
            throw VPNError.notConnected
        }

        return try await session.sendProviderMessage(message)
    }

    private func observeStatus() {
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager?.connection,
            queue: .main
        ) { [weak self] _ in
            self?.status = self?.manager?.connection.status ?? .disconnected
        }
    }
}
```

---

## 📦 Xcode 项目配置

### Package.swift 更新

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftProxy",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        // Shared framework
        .library(
            name: "SwiftProxyCore",
            targets: ["SwiftProxyCore"]
        ),

        // macOS app
        .executable(
            name: "SwiftProxy-macOS",
            targets: ["SwiftProxy-macOS"]
        ),

        // iOS app (通过 Xcode project 管理)
        // tvOS app (通过 Xcode project 管理)
    ],
    targets: [
        // 共享核心
        .target(
            name: "SwiftProxyCore",
            path: "Shared",
            resources: [
                .process("Resources")
            ]
        ),

        // macOS app
        .executableTarget(
            name: "SwiftProxy-macOS",
            dependencies: ["SwiftProxyCore"],
            path: "macOS"
        ),

        // Tests
        .testTarget(
            name: "SwiftProxyCoreTests",
            dependencies: ["SwiftProxyCore"],
            path: "Tests/SharedTests"
        )
    ]
)
```

### Xcode Project Targets

**建议使用 Xcode project 而不是纯 SPM，因为：**
1. Network Extension 需要 Xcode project
2. App Groups 配置更方便
3. Entitlements 管理更直观

**Targets 配置：**
1. `SwiftProxyCore` (Framework) - 所有平台
2. `SwiftProxy macOS` (macOS App)
3. `SwiftProxy iOS` (iOS App)
4. `PacketTunnel` (iOS Network Extension)
5. `ShareExtension` (iOS Share Extension)
6. `WidgetExtension` (iOS Widget)
7. `SwiftProxy tvOS` (tvOS App)
8. `SwiftProxy watchOS` (Watch App) - 可选

---

## 🔑 Capabilities 和 Entitlements

### macOS

**Capabilities:**
- Network (客户端/服务器)
- App Sandbox (关闭或配置网络访问)

**Entitlements:**
```xml
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

### iOS

**Capabilities:**
- Network Extensions
- App Groups
- Keychain Sharing (存储配置)

**Entitlements:**
```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.swiftproxy</string>
</array>
```

---

## 🔄 数据同步策略

### iCloud + App Group

```swift
// Shared/Sync/ConfigurationSync.swift
import Foundation

actor ConfigurationSync {
    // iCloud sync for cross-device
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default

    // App Group for same-device (app <-> extension)
    private let sharedDefaults = UserDefaults(suiteName: "group.com.swiftproxy")

    func saveConfiguration(_ config: ProxyConfiguration) async throws {
        let data = try JSONEncoder().encode(config)

        // Save to App Group (same device)
        sharedDefaults?.set(data, forKey: "current_config")

        // Save to iCloud (cross device)
        ubiquitousStore.set(data, forKey: "current_config")
        ubiquitousStore.synchronize()
    }

    func loadConfiguration() async -> ProxyConfiguration? {
        // Try App Group first
        if let data = sharedDefaults?.data(forKey: "current_config"),
           let config = try? JSONDecoder().decode(ProxyConfiguration.self, from: data) {
            return config
        }

        // Fall back to iCloud
        if let data = ubiquitousStore.data(forKey: "current_config"),
           let config = try? JSONDecoder().decode(ProxyConfiguration.self, from: data) {
            return config
        }

        return nil
    }
}
```

---

## 🎨 UI 适配策略

### SwiftUI + 编译条件

```swift
// Shared/UI/AdaptiveView.swift
import SwiftUI

struct ProxyControlView: View {
    @ObservedObject var viewModel: ProxyViewModel

    var body: some View {
        #if os(macOS)
        macOSView
        #elseif os(iOS)
        iOSView
        #elseif os(tvOS)
        tvOSView
        #elseif os(watchOS)
        watchOSView
        #endif
    }

    @ViewBuilder
    private var macOSView: some View {
        VStack {
            // 完整的 macOS UI
            Toggle("Enable Proxy", isOn: $viewModel.isEnabled)
            // 详细配置...
        }
    }

    @ViewBuilder
    private var iOSView: some View {
        List {
            // iOS 列表式 UI
            Toggle("Enable Proxy", isOn: $viewModel.isEnabled)
            // ...
        }
    }

    @ViewBuilder
    private var tvOSView: some View {
        VStack(spacing: 40) {
            // TV 遥控器友好的大按钮
            Button("Toggle Proxy") {
                viewModel.toggle()
            }
            .buttonStyle(.card)
        }
    }

    @ViewBuilder
    private var watchOSView: some View {
        VStack {
            // 极简的手表 UI
            Button(viewModel.isEnabled ? "ON" : "OFF") {
                viewModel.toggle()
            }
        }
    }
}
```

---

## 📱 iOS Widget 实现

```swift
// iOS/Extensions/WidgetExtension/ProxyWidget.swift
import WidgetKit
import SwiftUI

struct ProxyWidgetEntry: TimelineEntry {
    let date: Date
    let isEnabled: Bool
    let currentConfig: String
}

struct ProxyWidget: Widget {
    let kind: String = "ProxyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ProxyWidgetView(entry: entry)
        }
        .configurationDisplayName("SwiftProxy")
        .description("Quick proxy toggle")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ProxyWidgetView: View {
    var entry: ProxyWidgetEntry

    var body: some View {
        VStack {
            Image(systemName: entry.isEnabled ? "network" : "network.slash")
                .font(.largeTitle)
            Text(entry.isEnabled ? "Enabled" : "Disabled")
            Text(entry.currentConfig)
                .font(.caption)
        }
        .containerBackground(.background, for: .widget)
    }
}
```

---

## 🚀 实施步骤

### 阶段 1: 重构为共享框架 (1-2天)
1. ✅ 创建 `SwiftProxyCore` framework target
2. ✅ 移动所有核心代码到 Shared/
3. ✅ 更新 macOS app 使用 framework
4. ✅ 确保 macOS 版本正常工作

### 阶段 2: iOS 基础实现 (3-5天)
1. ✅ 创建 iOS app target
2. ✅ 实现 PacketTunnelProvider
3. ✅ 实现基本 UI（配置列表、开关）
4. ✅ 配置 App Groups
5. ✅ 测试基本代理功能

### 阶段 3: iOS 完整功能 (3-5天)
1. ✅ 实现规则编辑 UI
2. ✅ 添加 Widget Extension
3. ✅ 添加 Share Extension
4. ✅ iCloud 同步
5. ✅ 完整测试

### 阶段 4: tvOS 实现 (2-3天)
1. ✅ 创建 tvOS app target
2. ✅ 实现简化 UI
3. ✅ 配置同步
4. ✅ 测试

### 阶段 5: watchOS 实现 (可选, 1-2天)
1. ✅ 创建 Watch app target
2. ✅ 实现极简 UI
3. ✅ WatchConnectivity 通信

---

## ⚠️ 平台特定注意事项

### iOS Network Extension 限制
1. **内存限制:** Extension 内存限制约 50MB
2. **CPU 限制:** 避免长时间 CPU 密集操作
3. **后台限制:** VPN 断开后 extension 会被终止
4. **沙盒限制:** 无法访问主 app 文件（使用 App Group）

### 解决方案
- 使用 BufferPool 限制内存
- 异步处理，避免阻塞
- 合理的缓存大小
- App Group 共享数据

### tvOS 限制
1. **UI 限制:** 遥控器输入，大按钮设计
2. **资源限制:** 比 iOS 更受限
3. **使用场景:** 主要是开关，配置靠同步

---

## 📊 预期代码共享比例

| 模块 | 共享代码 | 平台特定 |
|------|----------|----------|
| NetworkEngine | 100% | 0% |
| Rules Engine | 100% | 0% |
| GeoIP | 100% | 0% |
| Performance | 95% | 5% (平台检测) |
| Data Models | 100% | 0% |
| UI Layer | 10% | 90% |
| System Integration | 0% | 100% |
| **总体** | **~70%** | **~30%** |

---

## 🎯 总结

### 关键决策

1. **核心代码 100% 共享**
   - NetworkEngine, Rules, GeoIP 完全共享
   - 基于 Network framework，天然跨平台

2. **iOS 使用 Network Extension**
   - 必须使用，但核心代码可重用
   - Extension 中运行 ProxyServer

3. **UI 完全独立**
   - 每个平台使用最合适的 UI 范式
   - macOS: AppKit + SwiftUI
   - iOS: UIKit/SwiftUI + Extensions
   - tvOS: 简化 SwiftUI
   - watchOS: 极简 SwiftUI

4. **数据同步**
   - iCloud 跨设备
   - App Group 同设备
   - 配置 JSON 格式统一

### 优势

✅ 核心逻辑一次编写，处处运行
✅ 针对每个平台优化 UI/UX
✅ 充分利用平台特性
✅ 维护成本可控
✅ 用户体验最佳

### 工作量估算

- 重构共享框架: 1-2天
- iOS 实现: 6-10天
- tvOS 实现: 2-3天
- watchOS 实现: 1-2天（可选）
- **总计: 10-17天**

---

**下一步:** 开始重构为共享框架？
