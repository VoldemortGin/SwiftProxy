# SwiftProxy 实现指南

## 1. 项目初始化步骤

### 1.1 创建 Xcode 项目
```bash
# 使用 Xcode 创建新项目
# File -> New -> Project -> macOS -> App
# Product Name: SwiftProxy
# Interface: SwiftUI
# Language: Swift
# Organization Identifier: com.yourcompany
```

### 1.2 配置项目设置
- Minimum Deployment: macOS 14.0
- Swift Language Version: Swift 5.9
- Enable Hardened Runtime
- Enable App Sandbox

### 1.3 添加 Network Extension Target
```bash
# File -> New -> Target -> Network Extension
# Product Name: SwiftProxyExtension
# Type: Packet Tunnel
```

### 1.4 配置 Capabilities
在主应用 Target 中启用：
- App Sandbox
- Network (Client & Server)
- App Groups (group.com.yourcompany.swiftproxy)

在 Extension Target 中启用：
- App Sandbox
- Network Extension
- App Groups (group.com.yourcompany.swiftproxy)

---

## 2. 依赖管理

### 2.1 Swift Package Manager
创建 `Package.swift` 或使用 Xcode 添加依赖：

推荐的第三方库：
- **Alamofire** (可选): 高级网络请求
- **SwiftLint**: 代码风格检查
- **Quick & Nimble**: 测试框架

### 2.2 添加 SwiftLint
```yaml
# .swiftlint.yml
disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - closure_spacing
  - force_unwrapping

excluded:
  - Pods
  - SwiftProxyTests
  - SwiftProxyUITests

line_length:
  warning: 120
  error: 200

identifier_name:
  min_length:
    warning: 2
  max_length:
    warning: 40
    error: 50
```

---

## 3. 核心功能实现顺序

### Phase 1: 基础架构 (Week 1-2)
1. ✅ 设置项目结构和文件夹
2. ✅ 实现 DependencyContainer
3. ✅ 创建核心协议（Protocols）
4. ✅ 实现数据模型（Models）
5. ✅ 实现 StorageService
6. ✅ 添加日志系统
7. ✅ 实现错误处理

### Phase 2: 代理服务 (Week 3-4)
1. ✅ 实现 ProxyService 基础功能
2. ✅ 系统代理配置（读取/写入）
3. ✅ 代理连接测试
4. ✅ 配置管理（CRUD）
5. ✅ 实现 ProxyControlViewModel
6. ✅ 创建代理配置 UI

### Phase 3: 网络监控 (Week 5-6)
1. ✅ 实现 NetworkMonitorService
2. ✅ Network Extension 基础设置
3. ✅ 数据包拦截和解析
4. ✅ 实时流量监控
5. ✅ 日志管理
6. ✅ 实现 MonitorViewModel
7. ✅ 创建监控 UI

### Phase 4: 规则引擎 (Week 7-8)
1. ✅ 实现 RuleEngineService
2. ✅ 规则匹配算法
3. ✅ 规则导入/导出
4. ✅ 预设规则库
5. ✅ 实现 RulesViewModel
6. ✅ 创建规则管理 UI

### Phase 5: 流量统计 (Week 9-10)
1. ✅ 实现 TrafficAnalyzerService
2. ✅ 实时统计计算
3. ✅ 历史数据分析
4. ✅ 图表数据生成
5. ✅ 实现 StatisticsViewModel
6. ✅ 创建统计 UI（图表）

### Phase 6: Dashboard 和整合 (Week 11-12)
1. ✅ 实现 DashboardViewModel
2. ✅ 创建 Dashboard UI
3. ✅ 整合所有功能模块
4. ✅ 菜单栏图标和快捷菜单
5. ✅ 系统托盘功能
6. ✅ 快捷键支持

### Phase 7: 测试和优化 (Week 13-14)
1. ✅ 单元测试（80%+ 覆盖率）
2. ✅ UI 测试
3. ✅ 性能优化
4. ✅ 内存泄漏检测
5. ✅ Bug 修复
6. ✅ 用户体验优化

### Phase 8: 发布准备 (Week 15-16)
1. ✅ 代码签名配置
2. ✅ 公证（Notarization）
3. ✅ 文档编写
4. ✅ 发布说明
5. ✅ Beta 测试
6. ✅ 正式发布

---

## 4. 关键技术实现细节

### 4.1 系统代理配置

#### macOS 系统代理 API
```swift
import SystemConfiguration

// 读取系统代理
func readSystemProxy() -> ProxySettings? {
    guard let preferences = SCPreferencesCreate(nil, "SwiftProxy" as CFString, nil) else {
        return nil
    }

    guard let networkSet = SCNetworkSetCopyCurrent(preferences),
          let services = SCNetworkSetCopyServices(networkSet) as? [SCNetworkService] else {
        return nil
    }

    for service in services {
        guard let interface = SCNetworkServiceGetInterface(service),
              let interfaceType = SCNetworkInterfaceGetInterfaceType(interface) else {
            continue
        }

        // 只处理以太网和 Wi-Fi
        if interfaceType == kSCNetworkInterfaceTypeEthernet ||
           interfaceType == kSCNetworkInterfaceTypeIEEE80211 {

            guard let protocolConfig = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeIPv4),
                  let config = SCNetworkProtocolGetConfiguration(protocolConfig) as? [String: Any] else {
                continue
            }

            // 读取代理配置
            let httpEnabled = config[kCFNetworkProxiesHTTPEnable as String] as? Int ?? 0
            let httpProxy = config[kCFNetworkProxiesHTTPProxy as String] as? String
            let httpPort = config[kCFNetworkProxiesHTTPPort as String] as? Int

            // ... 解析其他代理类型
        }
    }

    return nil
}

// 设置系统代理
func setSystemProxy(configuration: ProxyConfiguration) throws {
    // 需要管理员权限
    var authRef: AuthorizationRef?
    let status = AuthorizationCreate(nil, nil, [], &authRef)

    guard status == errAuthorizationSuccess, let auth = authRef else {
        throw AppError.proxyNotAuthorized
    }

    guard let preferences = SCPreferencesCreateWithAuthorization(
        nil,
        "SwiftProxy" as CFString,
        nil,
        auth
    ) else {
        throw AppError.proxyConfigurationInvalid("无法创建系统偏好设置")
    }

    // 设置代理...
}
```

### 4.2 Network Extension 数据流

#### 数据包处理流程
```
应用发起网络请求
    ↓
系统捕获数据包
    ↓
Network Extension 接收
    ↓
PacketProcessor 解析
    ↓
RuleEngine 匹配规则
    ↓
应用代理规则
    ↓
转发到目标/代理服务器
    ↓
接收响应
    ↓
返回给应用
```

#### PacketProcessor 实现
```swift
actor PacketProcessor {
    private var rules: [ProxyRule] = []
    private var statistics = PacketStatistics()

    func process(_ packet: Data, protocolFamily: Int32) async -> Data? {
        // 解析 IP 数据包
        guard let ipHeader = parseIPHeader(packet, protocolFamily: protocolFamily) else {
            return packet // 无法解析，直接返回
        }

        // 提取目标信息
        let destination = extractDestination(from: ipHeader)

        // 匹配规则
        let action = matchRule(destination: destination)

        // 应用规则
        switch action {
        case .direct:
            // 直连，不修改
            updateStatistics(packet: packet, action: .direct)
            return packet

        case .proxy:
            // 通过代理
            updateStatistics(packet: packet, action: .proxy)
            return modifyPacketForProxy(packet, destination: destination)

        case .reject:
            // 拒绝连接
            updateStatistics(packet: packet, action: .reject)
            return nil // 丢弃数据包
        }
    }

    private func parseIPHeader(_ packet: Data, protocolFamily: Int32) -> IPHeader? {
        guard packet.count >= 20 else { return nil }

        // 解析 IPv4 或 IPv6 头部
        if protocolFamily == AF_INET {
            return parseIPv4Header(packet)
        } else if protocolFamily == AF_INET6 {
            return parseIPv6Header(packet)
        }

        return nil
    }

    private func parseIPv4Header(_ packet: Data) -> IPHeader? {
        // IPv4 头部至少 20 字节
        guard packet.count >= 20 else { return nil }

        let versionAndHeaderLength = packet[0]
        let headerLength = Int(versionAndHeaderLength & 0x0F) * 4

        guard packet.count >= headerLength else { return nil }

        // 提取源地址和目标地址
        let sourceIP = packet[12..<16].map { String($0) }.joined(separator: ".")
        let destIP = packet[16..<20].map { String($0) }.joined(separator: ".")

        // 提取协议类型
        let protocolType = packet[9]

        var sourcePort: UInt16?
        var destPort: UInt16?

        // 如果是 TCP 或 UDP，提取端口号
        if protocolType == 6 || protocolType == 17 { // TCP = 6, UDP = 17
            if packet.count >= headerLength + 4 {
                sourcePort = UInt16(packet[headerLength]) << 8 | UInt16(packet[headerLength + 1])
                destPort = UInt16(packet[headerLength + 2]) << 8 | UInt16(packet[headerLength + 3])
            }
        }

        return IPHeader(
            version: 4,
            sourceAddress: sourceIP,
            destinationAddress: destIP,
            sourcePort: sourcePort,
            destinationPort: destPort,
            protocolType: protocolType
        )
    }

    private func extractDestination(from header: IPHeader) -> NetworkDestination {
        return NetworkDestination(
            host: header.destinationAddress,
            port: header.destinationPort ?? 0,
            protocol: header.protocolType
        )
    }

    private func matchRule(destination: NetworkDestination) -> RuleAction {
        // 按优先级匹配规则
        for rule in rules.sorted(by: { $0.priority > $1.priority }) {
            guard rule.isEnabled else { continue }

            if matches(rule: rule, destination: destination) {
                return rule.action
            }
        }

        // 默认策略
        return .direct
    }

    private func matches(rule: ProxyRule, destination: NetworkDestination) -> Bool {
        switch rule.ruleType {
        case .domain:
            return destination.host == rule.pattern

        case .domainSuffix:
            return destination.host.hasSuffix(rule.pattern)

        case .domainKeyword:
            return destination.host.contains(rule.pattern)

        case .ipCIDR:
            return matchesIPCIDR(ip: destination.host, cidr: rule.pattern)

        case .geoIP:
            return matchesGeoIP(ip: destination.host, country: rule.pattern)

        case .processName:
            // 需要额外的进程信息
            return false
        }
    }

    private func matchesIPCIDR(ip: String, cidr: String) -> Bool {
        // 实现 CIDR 匹配
        // 例如: 192.168.1.0/24
        let components = cidr.split(separator: "/")
        guard components.count == 2,
              let network = components.first,
              let prefixLength = Int(components.last ?? "") else {
            return false
        }

        // IP 地址转换为整数进行比较
        // ...

        return false // 简化实现
    }

    private func matchesGeoIP(ip: String, country: String) -> Bool {
        // 使用 GeoIP 数据库查询
        // 可以使用 MaxMind GeoLite2 数据库
        return false // 简化实现
    }

    private func updateStatistics(packet: Data, action: RuleAction) {
        statistics.totalPackets += 1
        statistics.totalBytes += Int64(packet.count)

        switch action {
        case .direct:
            statistics.directPackets += 1
        case .proxy:
            statistics.proxyPackets += 1
        case .reject:
            statistics.rejectedPackets += 1
        }
    }

    func updateRules(_ newRules: [ProxyRule]) {
        self.rules = newRules
    }

    func getStatistics() -> PacketStatistics {
        return statistics
    }

    func clearLogs() {
        statistics = PacketStatistics()
    }
}

struct IPHeader {
    let version: Int
    let sourceAddress: String
    let destinationAddress: String
    let sourcePort: UInt16?
    let destinationPort: UInt16?
    let protocolType: UInt8
}

struct NetworkDestination {
    let host: String
    let port: UInt16
    let `protocol`: UInt8
}

struct PacketStatistics: Codable {
    var totalPackets: Int64 = 0
    var totalBytes: Int64 = 0
    var directPackets: Int64 = 0
    var proxyPackets: Int64 = 0
    var rejectedPackets: Int64 = 0
}
```

### 4.3 App Group 通信

#### 主应用向 Extension 发送消息
```swift
import NetworkExtension

class ExtensionCommunicator {
    func sendMessage(_ message: ExtensionMessage) async throws -> Data? {
        guard let manager = try await getExtensionManager() else {
            throw AppError.extensionNotInstalled
        }

        guard let session = manager.connection as? NETunnelProviderSession else {
            throw AppError.extensionCommunicationFailed
        }

        let messageData = try JSONEncoder().encode(message)

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try session.sendProviderMessage(messageData) { responseData in
                    continuation.resume(returning: responseData)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func getExtensionManager() async throws -> NEVPNManager? {
        let managers = try await NEVPNManager.loadAllFromPreferences()
        return managers.first
    }

    func updateRules(_ rules: [ProxyRule]) async throws {
        let rulesData = try JSONEncoder().encode(rules)
        let message = ExtensionMessage(type: .updateRules, payload: rulesData)
        _ = try await sendMessage(message)
    }

    func getStatistics() async throws -> ExtensionStatistics {
        let message = ExtensionMessage(type: .getStatistics, payload: nil)
        guard let responseData = try await sendMessage(message) else {
            throw AppError.extensionCommunicationFailed
        }

        return try JSONDecoder().decode(ExtensionStatistics.self, from: responseData)
    }
}
```

#### 使用 App Group 共享数据
```swift
import Foundation

class SharedDataManager {
    private let groupIdentifier = "group.com.yourcompany.swiftproxy"

    func saveSharedData<T: Codable>(_ data: T, forKey key: String) throws {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) else {
            throw AppError.storageMigrationFailed("无法访问 App Group")
        }

        let fileURL = containerURL.appendingPathComponent("\(key).json")
        let encodedData = try JSONEncoder().encode(data)
        try encodedData.write(to: fileURL)
    }

    func loadSharedData<T: Codable>(forKey key: String) throws -> T? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) else {
            throw AppError.storageMigrationFailed("无法访问 App Group")
        }

        let fileURL = containerURL.appendingPathComponent("\(key).json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

### 4.4 数据持久化

#### StorageService 完整实现
```swift
import Foundation
import OSLog

final class StorageService: StorageProtocol {
    private let fileManager = FileManager.default
    private let logger: Logger
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // 存储路径
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var storageDirectory: URL {
        documentsDirectory.appendingPathComponent("SwiftProxy", isDirectory: true)
    }

    init(logger: Logger) {
        self.logger = logger
        createStorageDirectoryIfNeeded()
    }

    // MARK: - Generic Storage
    func save<T: Codable>(_ object: T, forKey key: StorageKey) async throws {
        let fileURL = storageDirectory.appendingPathComponent("\(key.rawValue).json")
        let data = try encoder.encode(object)

        try data.write(to: fileURL, options: .atomic)
        logger.info("Saved data for key: \(key.rawValue)")
    }

    func load<T: Codable>(forKey key: StorageKey) async throws -> T? {
        let fileURL = storageDirectory.appendingPathComponent("\(key.rawValue).json")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let object = try decoder.decode(T.self, from: data)

        logger.info("Loaded data for key: \(key.rawValue)")
        return object
    }

    func delete(forKey key: StorageKey) async throws {
        let fileURL = storageDirectory.appendingPathComponent("\(key.rawValue).json")

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            logger.info("Deleted data for key: \(key.rawValue)")
        }
    }

    func exists(forKey key: StorageKey) async -> Bool {
        let fileURL = storageDirectory.appendingPathComponent("\(key.rawValue).json")
        return fileManager.fileExists(atPath: fileURL.path)
    }

    // MARK: - Array Operations
    func saveArray<T: Codable>(_ array: [T], forKey key: StorageKey) async throws {
        try await save(array, forKey: key)
    }

    func loadArray<T: Codable>(forKey key: StorageKey) async throws -> [T] {
        return try await load(forKey: key) ?? []
    }

    func appendToArray<T: Codable>(_ item: T, forKey key: StorageKey) async throws {
        var array: [T] = try await loadArray(forKey: key)
        array.append(item)
        try await saveArray(array, forKey: key)
    }

    func removeFromArray<T: Codable & Identifiable>(id: T.ID, forKey key: StorageKey) async throws {
        var array: [T] = try await loadArray(forKey: key)
        array.removeAll { $0.id == id }
        try await saveArray(array, forKey: key)
    }

    // MARK: - Secure Storage (Keychain)
    func saveSecure(_ data: Data, forKey key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // 先删除旧数据
        SecItemDelete(query as CFDictionary)

        // 添加新数据
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw AppError.storageWriteFailed("Keychain error: \(status)")
        }

        logger.info("Saved secure data for key: \(key)")
    }

    func loadSecure(forKey key: String) async throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw AppError.storageReadFailed("Keychain error: \(status)")
        }

        logger.info("Loaded secure data for key: \(key)")
        return result as? Data
    }

    func deleteSecure(forKey key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppError.storageWriteFailed("Keychain error: \(status)")
        }

        logger.info("Deleted secure data for key: \(key)")
    }

    // MARK: - Cache Management
    func clearCache() async throws {
        let cacheKeys: [StorageKey] = [.connectionLogs]

        for key in cacheKeys {
            try await delete(forKey: key)
        }

        logger.info("Cache cleared")
    }

    func getCacheSize() async throws -> Int64 {
        var totalSize: Int64 = 0

        let enumerator = fileManager.enumerator(at: storageDirectory, includingPropertiesForKeys: [.fileSizeKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }

        return totalSize
    }

    // MARK: - Migration
    func migrateIfNeeded() async throws {
        // 实现数据迁移逻辑
        // 例如：从旧版本格式迁移到新版本
        logger.info("Migration check completed")
    }

    func exportData(to url: URL) async throws {
        // 导出所有数据到指定位置
        try fileManager.copyItem(at: storageDirectory, to: url)
        logger.info("Data exported to: \(url.path)")
    }

    func importData(from url: URL) async throws {
        // 从指定位置导入数据
        try fileManager.removeItem(at: storageDirectory)
        try fileManager.copyItem(at: url, to: storageDirectory)
        logger.info("Data imported from: \(url.path)")
    }

    // MARK: - Private
    private func createStorageDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            logger.info("Created storage directory")
        }
    }
}
```

---

## 5. UI 实现指南

### 5.1 SwiftUI 视图组件结构

#### 主窗口布局
```swift
struct ContentView: View {
    @EnvironmentObject var container: DependencyContainer
    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        NavigationSplitView {
            // 侧边栏
            SidebarView(selectedTab: $selectedTab)
                .frame(minWidth: 200, maxWidth: 250)
        } detail: {
            // 主内容区
            DetailView(selectedTab: selectedTab)
        }
        .navigationTitle("SwiftProxy")
    }

    enum Tab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case proxy = "Proxy"
        case monitor = "Monitor"
        case rules = "Rules"
        case statistics = "Statistics"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard: return "gauge"
            case .proxy: return "network"
            case .monitor: return "eye"
            case .rules: return "list.bullet"
            case .statistics: return "chart.bar"
            case .settings: return "gearshape"
            }
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        List(ContentView.Tab.allCases, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
    }
}

struct DetailView: View {
    @EnvironmentObject var container: DependencyContainer
    let selectedTab: ContentView.Tab

    var body: some View {
        Group {
            switch selectedTab {
            case .dashboard:
                DashboardView(viewModel: container.makeDashboardViewModel())
            case .proxy:
                ProxyControlView(viewModel: container.makeProxyControlViewModel())
            case .monitor:
                MonitorView(viewModel: container.makeMonitorViewModel())
            case .rules:
                RulesView(viewModel: container.makeRulesViewModel())
            case .statistics:
                StatisticsView(viewModel: container.makeStatisticsViewModel())
            case .settings:
                SettingsView()
            }
        }
    }
}
```

### 5.2 Dashboard 视图
```swift
struct DashboardView: View {
    @StateObject var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 代理状态卡片
                ProxyStatusCard(
                    isEnabled: viewModel.isProxyEnabled,
                    configuration: viewModel.currentConfiguration
                )

                // 实时统计
                HStack(spacing: 20) {
                    StatCard(
                        title: "Total Requests",
                        value: "\(viewModel.totalRequests)",
                        icon: "arrow.up.arrow.down",
                        color: .blue
                    )

                    StatCard(
                        title: "Active Connections",
                        value: "\(viewModel.activeConnections)",
                        icon: "link",
                        color: .green
                    )

                    StatCard(
                        title: "Data Transfer",
                        value: viewModel.formattedDataTransfer,
                        icon: "antenna.radiowaves.left.and.right",
                        color: .purple
                    )
                }

                // 实时速度图表
                RealtimeSpeedChart(speeds: viewModel.realtimeSpeedData)
                    .frame(height: 200)

                // 最近请求
                RecentRequestsList(requests: viewModel.recentRequests)
            }
            .padding()
        }
    }
}

struct ProxyStatusCard: View {
    let isEnabled: Bool
    let configuration: ProxyConfiguration?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(isEnabled ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)

                    Text(isEnabled ? "Proxy Enabled" : "Proxy Disabled")
                        .font(.headline)
                }

                if let config = configuration {
                    Text("\(config.type.rawValue) - \(config.host):\(config.port)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "network")
                .font(.system(size: 40))
                .foregroundColor(isEnabled ? .blue : .gray)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}
```

---

## 6. 测试策略

### 6.1 单元测试示例
```swift
import XCTest
import Combine
@testable import SwiftProxy

final class RuleEngineServiceTests: XCTestCase {
    var sut: RuleEngineService!
    var mockStorage: MockStorageService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockStorage = MockStorageService()
        sut = RuleEngineService(storage: mockStorage, logger: Logger.rules)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockStorage = nil
        super.tearDown()
    }

    func testAddRule_Success() async throws {
        // Given
        let rule = ProxyRule(
            id: UUID(),
            name: "Test Rule",
            ruleType: .domain,
            pattern: "example.com",
            action: .proxy,
            isEnabled: true,
            priority: 1,
            createdAt: Date(),
            updatedAt: Date()
        )

        // When
        try await sut.addRule(rule)

        // Then
        let rules = mockStorage.savedRules
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.name, "Test Rule")
    }

    func testMatchRule_DomainMatch() {
        // Given
        let rule = ProxyRule(
            id: UUID(),
            name: "Domain Rule",
            ruleType: .domain,
            pattern: "example.com",
            action: .proxy,
            isEnabled: true,
            priority: 1,
            createdAt: Date(),
            updatedAt: Date()
        )

        let request = NetworkRequest(
            id: UUID(),
            timestamp: Date(),
            method: .GET,
            url: URL(string: "https://example.com/path")!,
            host: "example.com",
            port: 443,
            status: .pending,
            bytesIn: 0,
            bytesOut: 0,
            processName: nil
        )

        // When
        let matched = sut.matchRule(for: request)

        // Then
        XCTAssertNotNil(matched)
        XCTAssertEqual(matched?.action, .proxy)
    }
}
```

---

## 7. 性能优化清单

### 7.1 内存优化
- [ ] 使用 Instruments 检测内存泄漏
- [ ] 限制日志缓存大小（环形缓冲区）
- [ ] 及时释放大对象
- [ ] 避免在主线程执行耗时操作

### 7.2 UI 性能
- [ ] 使用 LazyVStack/LazyHStack
- [ ] 避免在 View body 中执行复杂计算
- [ ] 使用 @ViewBuilder 优化视图组合
- [ ] 实现虚拟滚动（长列表）

### 7.3 网络性能
- [ ] 使用后台队列处理数据包
- [ ] 实现批量处理机制
- [ ] 优化规则匹配算法
- [ ] 缓存 DNS 查询结果

---

## 8. 安全最佳实践

### 8.1 权限最小化
- 只请求必要的系统权限
- 沙盒化应用
- 使用 Hardened Runtime

### 8.2 数据安全
- 敏感数据使用 Keychain 存储
- 日志脱敏（隐藏密码等）
- HTTPS 代理支持证书验证

### 8.3 代码安全
- 避免硬编码密钥
- 使用安全的随机数生成器
- 定期更新依赖库

---

## 9. 发布流程

### 9.1 代码签名
```bash
# 开发者证书
codesign --force --verify --verbose --sign "Developer ID Application: Your Name (TEAM_ID)" SwiftProxy.app

# Extension 单独签名
codesign --force --verify --verbose --sign "Developer ID Application: Your Name (TEAM_ID)" SwiftProxy.app/Contents/PlugIns/SwiftProxyExtension.appex
```

### 9.2 公证
```bash
# 创建 ZIP
ditto -c -k --keepParent SwiftProxy.app SwiftProxy.zip

# 上传公证
xcrun notarytool submit SwiftProxy.zip --keychain-profile "AC_PASSWORD" --wait

# 装订公证票据
xcrun stapler staple SwiftProxy.app
```

### 9.3 创建 DMG
```bash
# 使用 create-dmg 工具
create-dmg \
  --volname "SwiftProxy" \
  --volicon "icon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "SwiftProxy.app" 175 120 \
  --hide-extension "SwiftProxy.app" \
  --app-drop-link 425 120 \
  "SwiftProxy.dmg" \
  "SwiftProxy.app"
```

---

## 10. 常见问题

### Q1: Network Extension 无法激活？
**A**: 检查以下项目：
1. 是否已在系统偏好设置中授权
2. Extension 的 Bundle ID 是否正确
3. App Group 配置是否一致
4. 代码签名是否正确

### Q2: 系统代理设置失败？
**A**: 需要管理员权限，使用 `AuthorizationCreate` 请求权限。

### Q3: 数据包解析失败？
**A**: 确保正确处理 IPv4 和 IPv6 数据包头部，检查字节序。

### Q4: 规则匹配性能差？
**A**: 优化匹配算法，使用索引和缓存，考虑使用 Trie 树结构。

---

本文档提供了 SwiftProxy 的完整实现指南，涵盖从项目初始化到发布的所有关键步骤。
