# SwiftProxy 快速参考卡片

## 🚀 一键启动

```bash
# 最快启动方式
./quick_start.sh

# Xcode 开发
make xcode

# 命令行运行
make run
```

---

## 📁 重要文件位置

| 文件 | 路径 |
|------|------|
| **Package.swift** | `/Users/linhan/startup/SwiftProxy/Package.swift` |
| **Info.plist** | `/Users/linhan/startup/SwiftProxy/Info.plist` |
| **Entitlements** | `/Users/linhan/startup/SwiftProxy/SwiftProxy.entitlements` |

---

## 🛠️ 常用命令

### Make 命令（推荐）
```bash
make run              # 构建并运行
make build            # 只构建
make test             # 运行测试
make release          # Release 构建
make clean            # 清理
make xcode            # 打开 Xcode
make doctor           # 检查环境
make help             # 显示所有命令
```

### 构建脚本
```bash
./build_and_run.sh                # Debug 模式
./build_and_run.sh --release      # Release 模式
./build_and_run.sh --clean        # 清理后构建
```

### Swift Package Manager
```bash
swift build                       # 构建
swift run                         # 运行
swift test                        # 测试
swift package clean               # 清理
```

---

## 🧪 测试命令

```bash
# 所有测试
make test
swift test

# 单元测试
make test-unit
swift test --filter SwiftProxyTests

# 集成测试
make test-integration
swift test --filter SwiftProxyIntegrationTests
```

---

## 📊 项目信息

| 项目 | 值 |
|------|-----|
| **名称** | SwiftProxy |
| **Bundle ID** | com.swiftproxy.app |
| **版本** | 1.0.0 |
| **平台** | macOS 13.0+ |
| **Swift** | 5.9+ |
| **Xcode** | 15.0+ |

---

## 🔧 故障排除

### 构建失败
```bash
make clean
swift package clean
rm -rf .build
swift build
```

### 端口占用
```bash
lsof -ti:8080 | xargs kill -9
```

### 查看日志
```bash
log stream --predicate 'subsystem == "com.swiftproxy.app"'
```

---

## 📚 文档导航

| 需求 | 阅读文档 |
|------|----------|
| 快速开始 | `XCODE_PROJECT_SETUP_COMPLETE.md` |
| 详细构建指南 | `README_RUN.md` |
| 配置详解 | `PROJECT_BUILD_GUIDE.md` |
| 文件索引 | `CONFIGURATION_FILES_INDEX.md` |

---

## ✅ 验证配置

```bash
./validate_config.sh    # 验证所有配置
make doctor             # 检查开发环境
```

---

## 🎯 常见任务

| 任务 | 命令 |
|------|------|
| 开始开发 | `make xcode` |
| 快速测试 | `make run` |
| 运行测试 | `make test` |
| 发布构建 | `make release` |
| 清理项目 | `make clean` |

---

**快速帮助**: 运行 `./quick_start.sh` 或 `make help`
