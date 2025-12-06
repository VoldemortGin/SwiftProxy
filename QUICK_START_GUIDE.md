# SwiftProxy 高级功能开发快速指南

## 🎯 当前状态

你已经完成：
- ✅ 布局问题修复（窗口和分栏调整）
- ✅ XCUITest 测试基础设施
- ✅ 基础的 HTTP/SOCKS5 代理管理

准备开始：
- 🚀 Phase 1: 订阅 URL 功能
- 🚀 Phase 2: Shadowsocks 协议
- 🚀 Phase 3: V2Ray 协议
- 🚀 Phase 4: 规则引擎

## 📋 详细路线图

完整的 8 周开发计划已经创建在：
👉 **`ADVANCED_PROXY_IMPLEMENTATION_ROADMAP.md`**

## 🚀 立即开始 - Phase 1 第一步

### Step 1: 添加依赖包（5分钟）

编辑 `Package.swift`，添加 YAML 解析库：

```swift
// Package.swift
dependencies: [
    // 现有依赖...

    // 新增：YAML 解析器（用于 Clash 订阅）
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
],
targets: [
    .target(
        name: "SwiftProxy",
        dependencies: [
            "Yams"  // 添加这一行
        ]
    ),
]
```

### Step 2: 实现订阅解析器（2-3小时）

创建 `SwiftProxy/Core/Services/SubscriptionParser.swift`

这个文件负责解析不同格式的订阅链接。

### Step 3: 实现订阅服务（2-3小时）

创建 `SwiftProxy/Core/Services/SubscriptionService.swift`

负责：
- 添加/删除订阅
- 更新订阅（HTTP 请求 + 解析）
- 自动更新定时器
- 持久化存储

### Step 4: 创建订阅管理 UI（3-4小时）

创建 `SwiftProxy/UI/Views/SubscriptionManagerView.swift`

包含：
- 订阅列表
- 添加订阅对话框
- 节点列表展示
- 更新/删除操作

### Step 5: 集成到主界面（1小时）

在 `MainView.swift` 中添加"订阅"标签页。

### Step 6: 测试（2小时）

使用真实的订阅链接测试各种格式：
- Clash 订阅
- V2Ray 订阅
- Shadowsocks SIP008 订阅
- Base64 订阅

## 📦 所需资源

### 测试订阅链接

你可以使用这些公开的免费订阅进行测试：

1. **测试用 Base64 订阅**：
   ```
   创建一个文本文件包含：
   ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ=@server1.com:8388
   ss://Y2hhY2hhMjAtcG9seTEzMDU6cGFzc3dvcmQ=@server2.com:8388

   然后 Base64 编码整个内容
   ```

2. **Clash 格式测试**：
   参考：https://github.com/Dreamacro/clash/wiki/configuration

3. **V2Ray 格式测试**：
   参考：https://github.com/2dust/v2rayN/wiki

### 开发工具

- **Postman/curl**: 测试订阅 URL 请求
- **在线 Base64**: https://www.base64decode.org/
- **YAML 验证器**: https://yamlchecker.com/
- **JSON 验证器**: https://jsonlint.com/

## 💻 代码示例速查

### 如何使用订阅数据模型

```swift
// 创建订阅
let subscription = Subscription(
    name: "boslife 机场",
    url: "https://example.com/sub?token=xxx",
    updateInterval: 86400  // 24小时
)

// 创建节点
let node = ProxyNode(
    name: "香港 01",
    type: .shadowsocks,
    server: "hk01.example.com",
    port: 8388,
    credentials: .shadowsocks(
        password: "your_password",
        method: "aes-256-gcm"
    )
)

// 添加节点到订阅
var sub = subscription
sub.nodes.append(node)
```

### 如何解析订阅（伪代码）

```swift
// 1. 获取订阅内容
let url = URL(string: subscription.url)!
let data = try await URLSession.shared.data(from: url).0

// 2. 检测格式
let format = detectFormat(data: data)

// 3. 解析
let parser: SubscriptionParser
switch format {
case .clash:
    parser = ClashParser()
case .v2ray:
    parser = V2RayParser()
case .base64:
    parser = Base64Parser()
// ...
}

let nodes = try parser.parse(data: data)

// 4. 更新订阅
subscription.nodes = nodes
subscription.lastUpdated = Date()
```

## 🎨 UI 设计参考

### 订阅管理界面布局

```
┌─────────────────────────────────────────┐
│  订阅管理                      [+ 添加]  │
├─────────────────────────────────────────┤
│                                         │
│  📡 boslife 机场              ✓ 已启用  │
│     https://sub.boslife.com/...         │
│     20 个节点 | 2小时前更新    [更新]   │
│     ──────────────────────────────────  │
│                                         │
│  📡 另一个订阅                 ✗ 已禁用  │
│     https://another.com/sub             │
│     15 个节点 | 1天前更新      [更新]   │
│                                         │
├─────────────────────────────────────────┤
│  节点列表                               │
├─────────────────────────────────────────┤
│  🇭🇰 香港 01    SS    12ms    [测试]    │
│  🇭🇰 香港 02    SS    45ms    [测试]    │
│  🇯🇵 日本 01    VMess 67ms    [测试]    │
│  🇺🇸 美国 01    Trojan 123ms  [测试]    │
│                                         │
└─────────────────────────────────────────┘
```

## 🐛 常见问题

### Q: 订阅链接请求失败？
A: 检查：
- URL 是否正确
- 网络连接
- SSL 证书验证（可能需要禁用验证）

### Q: 解析失败？
A: 检查：
- 订阅格式是否正确
- Base64 解码是否成功
- YAML/JSON 是否有效

### Q: 节点信息不完整？
A: 不同订阅格式可能缺少某些字段，需要设置默认值。

## 📚 参考资料

### 订阅格式规范
- Clash 配置: https://github.com/Dreamacro/clash/wiki
- V2Ray 配置: https://www.v2fly.org/config/
- SS SIP008: https://shadowsocks.org/doc/sip008.html

### Swift 开发
- CryptoKit: https://developer.apple.com/documentation/cryptokit
- Network Framework: https://developer.apple.com/documentation/network
- Codable: https://developer.apple.com/documentation/swift/codable

### 代理协议
- Shadowsocks AEAD: https://shadowsocks.org/doc/aead.html
- VMess 协议: https://www.v2fly.org/developer/protocols/vmess.html
- SOCKS5 RFC: https://www.rfc-editor.org/rfc/rfc1928

## 🎯 Phase 1 完成标准

当你完成以下所有功能，Phase 1 就算完成了：

- [ ] ✅ 可以添加订阅链接
- [ ] ✅ 可以自动解析 Clash/V2Ray/SS 订阅
- [ ] ✅ 可以查看解析出的节点列表
- [ ] ✅ 可以手动更新订阅
- [ ] ✅ 可以启用/禁用订阅
- [ ] ✅ 可以删除订阅
- [ ] ✅ 订阅数据持久化保存
- [ ] ✅ 至少支持一种真实的订阅链接

## 🚀 然后呢？

Phase 1 完成后，你将拥有：
- ✅ 从 boslife 导入节点列表的能力
- ✅ 但是还不能使用这些节点（因为协议还没实现）

接下来进入 **Phase 2: Shadowsocks 协议**：
- 实现加密算法
- 实现本地 SOCKS5 服务器
- 真正能够连接到 SS 节点！

---

**准备好了吗？让我们从 SubscriptionParser.swift 开始！** 🎉

如果需要我帮你实现任何部分的代码，随时告诉我！
