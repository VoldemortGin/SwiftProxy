# SwiftProxy 项目文档索引

## 📚 核心文档

### 1. 架构设计文档
**文件**: [ARCHITECTURE.md](./ARCHITECTURE.md)

**内容概要**:
- 项目概述和技术栈
- 完整的目录结构设计
- 核心模块划分和职责
- 数据流架构
- 关键类和协议设计
- 依赖注入方案
- 错误处理策略
- 测试架构
- 性能优化策略
- 安全考虑

**适用人群**: 架构师、技术负责人、全体开发人员

**阅读优先级**: ⭐⭐⭐⭐⭐

---

### 2. 代码结构文档
**文件**: [CODE_STRUCTURE.md](./CODE_STRUCTURE.md)

**内容概要**:
- 应用入口和依赖注入实现
- 核心协议定义（完整代码）
- ViewModel 实现示例
- Service 实现示例
- Network Extension 实现
- 数据持久化实现
- UI 实现指南

**适用人群**: 开发人员

**阅读优先级**: ⭐⭐⭐⭐⭐

---

### 3. 实现指南
**文件**: [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)

**内容概要**:
- 项目初始化步骤
- 依赖管理配置
- 核心功能实现顺序（16周计划）
- 关键技术实现细节
  - 系统代理配置
  - Network Extension 数据流
  - App Group 通信
  - 数据持久化
- UI 实现指南
- 测试策略
- 性能优化清单
- 安全最佳实践
- 发布流程
- 常见问题解答

**适用人群**: 开发人员、测试人员

**阅读优先级**: ⭐⭐⭐⭐⭐

---

### 4. 架构审查报告
**文件**: [ARCHITECTURE_REVIEW.md](./ARCHITECTURE_REVIEW.md)

**内容概要**:
- 架构质量评估（5个维度）
- 核心模块深度分析
- 数据流分析
- 技术风险评估
- 代码质量标准
- 性能基准
- 部署清单
- 未来扩展建议
- 竞争对手分析
- 总体评分：9.3/10

**适用人群**: 技术负责人、项目经理、架构师

**阅读优先级**: ⭐⭐⭐⭐

---

### 5. 快速开始指南
**文件**: [QUICK_START.md](./QUICK_START.md)

**内容概要**:
- 初始设置步骤
- 开发阶段计划
- 常用命令
- 资源链接

**适用人群**: 新加入的开发人员

**阅读优先级**: ⭐⭐⭐⭐⭐

---

## 🛠️ 工具和脚本

### 项目设置脚本
**文件**: [setup_project.sh](./setup_project.sh)

**功能**:
- 自动创建完整的目录结构
- 生成配置文件（.gitignore, .swiftlint.yml, Package.swift）
- 创建占位符文件（Info.plist, Entitlements）
- 生成项目文档

**使用方法**:
```bash
cd /Users/linhan/startup/SwiftProxy
./setup_project.sh
```

**执行后效果**:
- ✅ 完整的项目目录结构
- ✅ 所有必需的配置文件
- ✅ README、CHANGELOG 等文档
- ✅ 准备就绪，可以创建 Xcode 项目

---

## 📋 项目管理文档

### README
**文件**: [README.md](./README.md)

**内容**:
- 项目简介
- 核心功能列表
- 系统要求
- 架构概览
- 安装和使用
- 文档链接

---

### CHANGELOG
**文件**: [CHANGELOG.md](./CHANGELOG.md)

**内容**:
- 版本历史
- 功能变更记录
- Bug 修复记录

---

## 📖 推荐阅读路径

### 新加入项目的开发人员

1. **第一天**: 了解项目
   - ✅ README.md
   - ✅ QUICK_START.md
   - ✅ ARCHITECTURE.md (概览部分)

2. **第二天**: 深入架构
   - ✅ ARCHITECTURE.md (完整阅读)
   - ✅ ARCHITECTURE_REVIEW.md
   - ✅ 运行 setup_project.sh

3. **第三天**: 开始编码
   - ✅ CODE_STRUCTURE.md (核心协议)
   - ✅ IMPLEMENTATION_GUIDE.md (对应模块)
   - ✅ 开始实现第一个模块

---

### 架构师/技术负责人

1. **架构评估**:
   - ✅ ARCHITECTURE.md
   - ✅ ARCHITECTURE_REVIEW.md

2. **技术决策**:
   - ✅ IMPLEMENTATION_GUIDE.md (技术细节)
   - ✅ CODE_STRUCTURE.md (接口设计)

3. **风险管理**:
   - ✅ ARCHITECTURE_REVIEW.md (风险评估)

---

### 测试人员

1. **测试策略**:
   - ✅ ARCHITECTURE.md (测试架构)
   - ✅ IMPLEMENTATION_GUIDE.md (测试策略)

2. **测试实现**:
   - ✅ CODE_STRUCTURE.md (测试示例)

---

## 🗂️ 文件组织结构

```
SwiftProxy/
├── 📄 README.md                    # 项目简介
├── 📄 QUICK_START.md               # 快速开始
├── 📄 ARCHITECTURE.md              # 架构设计（最重要）
├── 📄 CODE_STRUCTURE.md            # 代码实现（最重要）
├── 📄 IMPLEMENTATION_GUIDE.md      # 实现指南（最重要）
├── 📄 ARCHITECTURE_REVIEW.md       # 架构审查
├── 📄 PROJECT_INDEX.md             # 本文件
├── 📄 CHANGELOG.md                 # 版本历史
├── 📄 .gitignore                   # Git 忽略规则
├── 📄 .swiftlint.yml               # 代码风格配置
├── 📄 Package.swift                # 依赖管理
└── 🔧 setup_project.sh             # 项目设置脚本
```

---

## 🎯 核心概念速查

### 架构模式: MVVM

```
Model ←→ ViewModel ←→ View
  ↓         ↓          ↓
Domain   Business   SwiftUI
Models    Logic      UI
```

### 依赖注入: DependencyContainer

```swift
DependencyContainer
    ├── ProxyService
    ├── NetworkMonitorService
    ├── RuleEngineService
    ├── TrafficAnalyzerService
    └── StorageService
```

### 数据流: Combine

```
Service (Publisher)
    ↓
ViewModel (@Published)
    ↓
View (Subscriber)
```

### 通信机制: App Group

```
Main App ←→ Shared Container ←→ Network Extension
```

---

## 🔑 关键接口速查

### ProxyServiceProtocol
```swift
func enable(configuration: ProxyConfiguration) async throws
func disable() async throws
func toggle() async throws
var isEnabled: AnyPublisher<Bool, Never> { get }
```

### NetworkMonitorProtocol
```swift
func startMonitoring() async throws
func stopMonitoring() async throws
var requests: AnyPublisher<[NetworkRequest], Never> { get }
```

### RuleEngineProtocol
```swift
func addRule(_ rule: ProxyRule) async throws
func matchRule(for request: NetworkRequest) -> ProxyRule?
var rules: AnyPublisher<[ProxyRule], Never> { get }
```

### TrafficAnalyzerProtocol
```swift
func analyzeTraffic(timeRange: TimeRange) async -> TrafficAnalysis
var statistics: AnyPublisher<TrafficStatistics, Never> { get }
```

---

## 📊 项目统计

### 文档统计
- **总文档数**: 8 个核心文档
- **总行数**: 约 5,000+ 行
- **代码示例**: 50+ 个
- **图表**: 10+ 个

### 架构覆盖
- ✅ 应用层
- ✅ 视图层
- ✅ 视图模型层
- ✅ 服务层
- ✅ 模型层
- ✅ Extension 层
- ✅ 存储层

### 功能模块
- ✅ 代理服务 (ProxyService)
- ✅ 网络监控 (NetworkMonitor)
- ✅ 规则引擎 (RuleEngine)
- ✅ 流量分析 (TrafficAnalyzer)
- ✅ 数据存储 (Storage)
- ✅ Network Extension

---

## 🚀 开发进度跟踪

### Phase 1: 基础架构 (Week 1-2)
- [ ] 项目初始化
- [ ] 核心协议定义
- [ ] 数据模型实现
- [ ] 依赖注入容器
- [ ] 存储服务

### Phase 2: 代理服务 (Week 3-4)
- [ ] ProxyService 实现
- [ ] 系统代理配置
- [ ] ProxyControlViewModel
- [ ] ProxyControlView

### Phase 3: 网络监控 (Week 5-6)
- [ ] NetworkMonitorService
- [ ] Network Extension
- [ ] MonitorViewModel
- [ ] MonitorView

### Phase 4: 规则引擎 (Week 7-8)
- [ ] RuleEngineService
- [ ] 规则匹配算法
- [ ] RulesViewModel
- [ ] RulesView

### Phase 5: 流量统计 (Week 9-10)
- [ ] TrafficAnalyzerService
- [ ] 统计算法
- [ ] StatisticsViewModel
- [ ] StatisticsView

### Phase 6: Dashboard (Week 11-12)
- [ ] DashboardViewModel
- [ ] DashboardView
- [ ] 功能整合
- [ ] 菜单栏

### Phase 7: 测试 (Week 13-14)
- [ ] 单元测试
- [ ] UI 测试
- [ ] 性能优化
- [ ] Bug 修复

### Phase 8: 发布 (Week 15-16)
- [ ] 代码签名
- [ ] 公证
- [ ] 文档完善
- [ ] 发布

---

## 🔗 相关链接

### Apple 官方文档
- [NetworkExtension Framework](https://developer.apple.com/documentation/networkextension)
- [SystemConfiguration Framework](https://developer.apple.com/documentation/systemconfiguration)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [Combine](https://developer.apple.com/documentation/combine)

### 开发工具
- [Xcode](https://developer.apple.com/xcode/)
- [SwiftLint](https://github.com/realm/SwiftLint)
- [Instruments](https://developer.apple.com/instruments/)

### 最佳实践
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Code Signing](https://developer.apple.com/support/code-signing/)

---

## 💡 使用技巧

### 快速查找

1. **查找某个功能的实现**:
   - 先看 ARCHITECTURE.md 了解模块职责
   - 再看 CODE_STRUCTURE.md 找具体代码
   - 最后看 IMPLEMENTATION_GUIDE.md 了解实现细节

2. **解决技术问题**:
   - 查看 IMPLEMENTATION_GUIDE.md 的"常见问题"部分
   - 参考 CODE_STRUCTURE.md 的实现示例
   - 查阅 ARCHITECTURE_REVIEW.md 的风险评估

3. **开始新功能开发**:
   - 阅读 ARCHITECTURE.md 了解整体设计
   - 查看 CODE_STRUCTURE.md 的接口定义
   - 按照 IMPLEMENTATION_GUIDE.md 的步骤实现

### 文档维护

- **定期更新**: 随着代码实现，更新文档中的实现状态
- **补充示例**: 添加实际遇到的问题和解决方案
- **版本控制**: 重大架构变更时更新版本号

---

## 📞 支持

### 问题反馈
- 技术问题: 查看 IMPLEMENTATION_GUIDE.md 的常见问题
- 架构疑问: 参考 ARCHITECTURE_REVIEW.md
- 实现细节: 查看 CODE_STRUCTURE.md

### 贡献指南
1. 阅读相关文档
2. 遵循代码规范（SwiftLint）
3. 编写单元测试
4. 提交 Pull Request

---

**文档索引版本**: 1.0
**最后更新**: $(date +%Y-%m-%d)
**维护人员**: 项目团队

---

## 附录: 文档更新日志

### 2025-XX-XX
- ✅ 创建初始文档索引
- ✅ 添加所有核心文档链接
- ✅ 编写阅读路径建议
- ✅ 添加快速参考部分
