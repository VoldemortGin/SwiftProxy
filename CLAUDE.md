# Claude Code 工作指南

## 项目概述

**SwiftProxy** - 高性能跨平台网络代理工具（类似 Surge）
- **版本**: v0.0.2 (开发中)
- **最后更新**: 2025-01-22
- **Swift 版本**: Swift 5.9+ (兼容 Swift 6)
- **平台支持**: macOS 13.0+, iOS 16.0+, tvOS 16.0+, watchOS 9.0+

## 项目架构概览

### 核心模块划分
```
SwiftProxy/
├── Shared/                    # 跨平台共享代码 (SwiftProxyCore)
│   ├── Core/                  # 核心功能
│   │   ├── NetworkEngine/    # 网络引擎 (23 个文件)
│   │   ├── Rules/            # 规则引擎
│   │   ├── Performance/      # 性能优化
│   │   └── GeoIP/            # 地理位置
│   ├── Models/               # 数据模型
│   ├── Services/             # 业务服务
│   └── Errors/               # 错误处理
└── Platform/                  # 平台特定代码
    └── macOS/                # macOS 平台 (25 个文件)
        ├── UI/               # SwiftUI 界面
        ├── ViewModels/       # 视图模型
        └── Utils/            # 工具类
```

### 技术栈
- **并发模型**: Swift 6 actor-based concurrency
- **网络框架**: Apple Network.framework
- **UI框架**: SwiftUI (macOS 13.0+)
- **测试框架**: XCTest
- **包管理**: Swift Package Manager

## 代码修改工作流程

每次对代码进行任何修改后，必须执行以下步骤确保编译成功：

### 1. 重新编译
每次代码修改后，立即使用以下命令重新编译：

```bash
make build     # Debug 构建（推荐开发时使用）
make release   # Release 构建
```

### 2. 验证编译结果
- ✅ 编译成功完成
- ✅ 没有错误信息
- ⚠️ 注意 Swift Package 警告（未处理的资源文件）

### 3. 运行测试
```bash
make test              # 运行所有测试
make test-unit         # 仅单元测试
make test-integration  # 仅集成测试
```

**已知问题**: 当前测试无法运行，因为：
- 测试文件导入 `@testable import SwiftProxy`
- 但实际模块名是 `SwiftProxyCore`
- 需要更新所有测试文件的导入语句

## 常用命令

| 命令 | 说明 |
|------|------|
| `make build` | **开发推荐** - 构建 Debug 版本 |
| `make run` | 构建并运行应用 |
| `make release` | 构建 Release 版本 |
| `make test` | 运行所有测试 |
| `make clean` | 清理构建文件 |
| `make doctor` | 检查开发环境 |
| `make info` | 显示项目信息 |
| `make xcode` | 在 Xcode 中打开项目 |

## 当前项目状态

### ✅ 已完成 (90%)

#### 核心功能
- ✅ 数据模型层 (100%)
  - ProxyConfiguration, ProxyRule, NetworkRequest, Connection, Statistics
- ✅ 网络引擎 (85%)
  - ProxyServer (HTTP/HTTPS/SOCKS5)
  - ConnectionPool (企业级连接池)
  - RetryHandler (智能重试+熔断器)
- ✅ 服务层 (90%)
  - ProxyService, ConfigurationService, RuleService, StatisticsService
- ✅ UI 层 (80%)
  - MainView, SettingsView, StatisticsView, ProxyConfigView
  - ViewModels 和组件

#### 工程质量
- ✅ 编译成功 (Debug 和 Release)
- ✅ Swift 6 并发安全
- ✅ 完整错误处理系统 (27种错误类型)
- ✅ 详细文档 (50+ markdown 文件)

### ⚠️ 已知问题

#### 1. 测试模块导入错误 (高优先级)
**问题**: 所有测试文件导入错误模块名
```swift
// 当前 (错误)
@testable import SwiftProxy

// 应该是
@testable import SwiftProxyCore
```
**影响文件**:
- `SwiftProxyTests/**/*.swift` (所有测试文件)
- `SwiftProxyIntegrationTests/**/*.swift` (所有集成测试)

#### 2. Package.swift 资源警告 (低优先级)
- 未处理的 .md 文件需要显式声明
- 禁用的 .swift.disabled 文件

#### 3. Makefile 缺少 `app` 目标
- CLAUDE.md 提到的 `make app` 命令不存在
- 需要添加构建 .app 包的目标

### 🚧 待完成功能

根据 [ROADMAP.md](./ROADMAP.md) 和 [TODO_LIST.md](./TODO_LIST.md)：

#### Phase 1: 修复和完善 (1-2周)
1. **修复测试导入** (1天) - 高优先级
2. **SSL/TLS 增强** (2-3天)
   - 证书验证逻辑
   - TLS 1.3 支持
   - ALPN 协议协商
3. **PacketHandler 完成** (1天)
   - 数据包缓冲
   - 流量整形
4. **PerformanceOptimizations 模块** (3-4天)
   - RateLimiter (令牌桶算法)
   - 内存池管理
   - 性能监控

#### Phase 2: 高级功能 (2-3周)
- Keychain 集成 (密码安全存储)
- PAC 支持
- 代理链
- GeoIP 规则匹配
- 实时流量图表

#### Phase 3: 系统集成 (1-2周)
- Network Extension
- 自动更新
- 菜单栏集成
- 深色模式优化

## 开发优先级

### 🔴 立即处理
1. **修复测试导入错误** - 阻塞测试运行
2. **添加 Makefile app 目标** - 文档一致性

### 🟡 高优先级
1. SSL/TLS 增强
2. PerformanceOptimizations 模块
3. Keychain 集成

### 🟢 中优先级
1. UI/UX 完善
2. 高级代理功能
3. 统计和监控增强

## 工作原则

1. **编译优先**：任何代码修改后，立即编译验证
2. **测试驱动**：修复测试导入后，保持所有测试通过
3. **增量开发**：小步提交，频繁验证
4. **文档同步**：代码和文档保持一致

## 项目信息

- **应用名称**: SwiftProxy
- **可执行文件**: SimpleSwiftProxy
- **核心库**: SwiftProxyCore
- **Bundle ID**: com.swiftproxy.app (待配置)
- **最低系统**: macOS 13.0 / iOS 16.0

## 资源链接

- 📋 [完整路线图](./ROADMAP.md)
- 📝 [任务清单](./TODO_LIST.md)
- 📚 [快速开始](./QUICK_START_GUIDE.md)
- 🏗️ [架构文档](./ARCHITECTURE.md)

## 注意事项

- ⚠️ 测试当前无法运行，需要先修复导入问题
- ⚠️ 某些 UI 功能有 TODO 标记，需要实现
- ✅ 核心代理功能已基本完成
- ✅ 代码质量良好，有完整的错误处理
