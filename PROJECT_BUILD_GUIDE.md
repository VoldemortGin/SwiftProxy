# SwiftProxy - 项目构建配置指南

## 📋 项目配置文件总览

### 核心配置文件

| 文件名 | 用途 | 位置 |
|--------|------|------|
| `Package.swift` | Swift Package Manager 配置 | `/Users/linhan/startup/SwiftProxy/` |
| `Info.plist` | 应用程序信息配置 | `/Users/linhan/startup/SwiftProxy/` |
| `SwiftProxy.entitlements` | 应用程序权限配置 | `/Users/linhan/startup/SwiftProxy/` |
| `.gitignore` | Git 忽略文件配置 | `/Users/linhan/startup/SwiftProxy/` |

### 构建和运行脚本

| 脚本名 | 用途 | 命令 |
|--------|------|------|
| `build_and_run.sh` | 完整的构建和运行脚本 | `./build_and_run.sh` |
| `quick_start.sh` | 交互式快速启动脚本 | `./quick_start.sh` |
| `Makefile` | Make 命令集合 | `make <command>` |
| `run_tests.sh` | 测试运行脚本（已存在） | `./run_tests.sh` |

## 🚀 快速开始

### 方法一：一键启动（推荐新手）

```bash
cd /Users/linhan/startup/SwiftProxy
./quick_start.sh
```

然后选择你想要的操作：
1. 在 Xcode 中打开并运行
2. 命令行构建并运行（Debug）
3. 构建 Release 版本
4. 运行测试
5. 检查开发环境

### 方法二：使用 Makefile（推荐开发）

```bash
# 查看所有可用命令
make help

# 构建并运行
make run

# 只构建
make build

# 构建 Release 版本
make release

# 运行所有测试
make test

# 运行单元测试
make test-unit

# 运行集成测试
make test-integration

# 清理构建产物
make clean

# 在 Xcode 中打开
make xcode

# 检查开发环境
make doctor
```

### 方法三：使用构建脚本

```bash
# Debug 构建并运行
./build_and_run.sh

# Release 构建并运行
./build_and_run.sh --release

# 只构建不运行
./build_and_run.sh --no-run

# 清理后构建
./build_and_run.sh --clean

# 查看帮助
./build_and_run.sh --help
```

### 方法四：直接使用 Swift Package Manager

```bash
# Debug 构建
swift build

# Release 构建
swift build -c release

# 构建并运行
swift run

# 运行测试
swift test
```

## 📁 项目结构

```
SwiftProxy/
├── Package.swift                          # SPM 配置文件 ✅
├── Info.plist                             # 应用信息 ✅
├── SwiftProxy.entitlements                # 应用权限 ✅
├── .gitignore                             # Git 配置 ✅
├── Makefile                               # Make 命令 ✅
├── build_and_run.sh                       # 构建脚本 ✅
├── quick_start.sh                         # 快速启动 ✅
├── README_RUN.md                          # 运行指南 ✅
├── PROJECT_BUILD_GUIDE.md                 # 本文件 ✅
│
├── SwiftProxy/                            # 主代码目录
│   ├── SwiftProxyApp.swift               # 应用入口
│   ├── Core/                             # 核心功能
│   │   ├── NetworkEngine/               # 网络引擎
│   │   ├── Models/                      # 数据模型
│   │   ├── Services/                    # 服务层
│   │   ├── Protocols/                   # 协议定义
│   │   ├── Errors/                      # 错误类型
│   │   └── Utils/                       # 工具类
│   ├── UI/                              # 用户界面
│   │   ├── Views/                       # SwiftUI 视图
│   │   ├── Components/                  # 可复用组件
│   │   └── ViewModels/                  # 视图模型
│   └── ViewModels/                      # 额外视图模型
│
├── SwiftProxyTests/                       # 单元测试
└── SwiftProxyIntegrationTests/            # 集成测试
```

## ⚙️ 配置详解

### 1. Package.swift - Swift Package Manager 配置

**关键配置项：**

```swift
// 平台要求
platforms: [
    .macOS(.v13)  // macOS 13.0 (Ventura) 或更高
]

// 产品定义
products: [
    .executable(name: "SwiftProxy", targets: ["SwiftProxy"])
]

// Swift 编译选项
swiftSettings: [
    .enableUpcomingFeature("StrictConcurrency"),  // 严格并发检查
    .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))  // Release 模式警告视为错误
]
```

**功能：**
- 定义项目名称和平台要求
- 配置编译目标（可执行文件、测试）
- 设置 Swift 语言特性和编译选项
- 管理依赖关系

### 2. Info.plist - 应用程序信息

**关键配置项：**

```xml
<!-- Bundle ID -->
<key>CFBundleIdentifier</key>
<string>com.swiftproxy.app</string>

<!-- 最低系统版本 -->
<key>LSMinimumSystemVersion</key>
<string>13.0</string>

<!-- 网络权限 -->
<key>NSLocalNetworkUsageDescription</key>
<string>SwiftProxy needs access to the local network to function as a proxy server.</string>
```

**功能：**
- 定义应用 Bundle ID
- 设置版本号和构建号
- 配置网络权限说明
- 设置应用类别和显示属性

### 3. SwiftProxy.entitlements - 应用权限

**关键权限：**

```xml
<!-- 网络客户端 -->
<key>com.apple.security.network.client</key>
<true/>

<!-- 网络服务器 -->
<key>com.apple.security.network.server</key>
<true/>

<!-- 出站连接 -->
<key>com.apple.security.network.outbound</key>
<true/>

<!-- 入站连接 -->
<key>com.apple.security.network.inbound</key>
<true/>
```

**功能：**
- 启用应用沙盒
- 配置网络访问权限
- 设置文件访问权限
- 配置 Keychain 访问

## 🔧 开发工作流

### 日常开发流程

```bash
# 1. 打开 Xcode 开发
make xcode

# 2. 或使用命令行快速迭代
make build && make test && make run
```

### 发布流程

```bash
# 1. 清理并构建 Release 版本
make clean
make release

# 2. 运行所有测试
make test

# 3. 创建分发归档
make archive
```

### 代码质量检查

```bash
# 格式化代码（需要 swift-format）
make format

# 代码检查（需要 swiftlint）
make lint

# 检查环境
make doctor
```

## 📊 构建配置

### Debug 模式
- **优化级别**: 无优化 (`-Onone`)
- **调试符号**: 完整
- **断言**: 启用
- **二进制位置**: `.build/debug/SwiftProxy`
- **用途**: 开发、调试

### Release 模式
- **优化级别**: 完全优化 (`-O`)
- **调试符号**: 最小化
- **断言**: 禁用
- **警告处理**: 警告视为错误
- **二进制位置**: `.build/release/SwiftProxy`
- **用途**: 生产部署

## 🧪 测试

### 运行所有测试
```bash
make test
# 或
swift test
```

### 运行特定测试套件
```bash
# 单元测试
make test-unit
swift test --filter SwiftProxyTests

# 集成测试
make test-integration
swift test --filter SwiftProxyIntegrationTests
```

### 测试覆盖率
```bash
make coverage
```

## 🐛 故障排除

### 构建失败

**问题**: 找不到模块或编译错误

**解决方案**:
```bash
# 清理并重新构建
make clean
swift package clean
rm -rf .build
swift build
```

### 权限问题

**问题**: 应用无法访问网络

**解决方案**:
1. 检查 `SwiftProxy.entitlements` 文件
2. 在系统偏好设置中授予网络权限
3. 检查防火墙设置

### 端口占用

**问题**: 端口 8080 已被占用

**解决方案**:
```bash
# 查找占用端口的进程
lsof -ti:8080

# 终止进程
lsof -ti:8080 | xargs kill -9

# 或在应用设置中更改端口
```

## 📝 系统要求

| 组件 | 最低版本 | 推荐版本 |
|------|----------|----------|
| macOS | 13.0 (Ventura) | 14.0 (Sonoma) |
| Xcode | 15.0 | 15.2+ |
| Swift | 5.9 | 5.9+ |
| 架构 | x86_64, arm64 | arm64 (Apple Silicon) |

## 🔍 调试和日志

### 查看应用日志

```bash
# 实时查看所有日志
log stream --predicate 'subsystem == "com.swiftproxy.app"' --level debug

# 查看代理相关日志
log stream --predicate 'subsystem == "com.swiftproxy.app" AND category == "proxy"'

# 查看网络相关日志
log stream --predicate 'subsystem == "com.swiftproxy.app" AND category == "network"'

# 查看 UI 相关日志
log stream --predicate 'subsystem == "com.swiftproxy.app" AND category == "ui"'
```

### 性能分析

1. 在 Xcode 中：
   - 打开项目：`make xcode`
   - 选择 Product > Profile (⌘I)
   - 选择 Instruments 工具

2. 命令行：
   ```bash
   # 构建 Release 版本进行性能测试
   make release
   ```

## 🎯 下一步

### 立即开始开发

```bash
# 1. 快速启动
./quick_start.sh

# 2. 选择在 Xcode 中打开（选项 1）

# 3. 开始编码！
```

### 学习资源

- [Swift Package Manager 文档](https://swift.org/package-manager/)
- [SwiftUI 文档](https://developer.apple.com/documentation/swiftui/)
- [Network Framework](https://developer.apple.com/documentation/network/)

## 📞 技术支持

如遇到问题：

1. **检查环境**: `make doctor`
2. **查看日志**: 使用上面的日志命令
3. **清理重建**: `make clean && make build`
4. **阅读文档**: `README_RUN.md`

---

**最后更新**: 2024-10-06
**项目版本**: 1.0.0
**配置作者**: Senior Backend TypeScript Architect
