# SwiftProxy UI 布局问题分析与修复

## 问题描述

用户反馈：**子模块拉宽后总体应用宽度没变，看起来很奇怪**

## 根本原因分析

### 1. NavigationSplitView 配置不当

**当前代码 (MainView.swift:20-26)**:
```swift
NavigationSplitView {
    sidebarView
} detail: {
    contentView
}
```

**问题**:
- ❌ 没有设置 `columnVisibility` 来控制分栏显示行为
- ❌ 没有配置侧边栏的理想宽度，只有 `minWidth: 220`
- ❌ detail 视图没有任何 frame 约束
- ❌ 没有设置 `navigationSplitViewStyle` 来定义分栏行为

### 2. 窗口尺寸配置不完整

**当前代码 (SwiftProxyApp.swift:28-31)**:
```swift
WindowGroup {
    MainView(viewModel: viewModel)
        .frame(minWidth: 800, minHeight: 600)
}
```

**问题**:
- ❌ 只设置了 `minWidth/minHeight` (最小尺寸)
- ❌ 没有设置 `idealWidth/idealHeight` (默认尺寸)
- ❌ 没有设置 `maxWidth/maxHeight` (最大尺寸)
- ❌ 窗口首次打开时大小不确定

**结果**: 当用户拖动侧边栏分隔线时，因为窗口没有理想尺寸和最大尺寸约束，整个窗口不会自动调整，导致内容被挤压或拉伸。

### 3. 子视图缺少适当的布局约束

**ProxyConfigView.swift**:
```swift
var body: some View {
    VStack(spacing: 0) {
        ProxyToggle(...)
            .padding()
        Divider()
        configurationsSection  // ❌ 没有frame约束
    }
}
```

**问题**:
- VStack 没有设置 `maxWidth(.infinity)` 来填充可用空间
- ScrollView 没有正确的 frame 约束
- 内容可能不会自动扩展以填充调整后的窗口空间

### 4. 侧边栏宽度约束不合理

**MainView.swift:90**:
```swift
.listStyle(.sidebar)
.frame(minWidth: 220)  // ❌ 只有最小宽度
```

**问题**:
- 没有 `idealWidth` - macOS 不知道侧边栏应该默认多宽
- 没有 `maxWidth` - 侧边栏可能被拉得过宽
- 用户拖动时行为不可预测

## 解决方案

### 修复 1: 完善 NavigationSplitView 配置

```swift
// MainView.swift
@State private var columnVisibility: NavigationSplitViewVisibility = .all

var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
        // Sidebar
        sidebarView
            .navigationSplitViewColumnWidth(
                min: 200,
                ideal: 250,
                max: 350
            )
    } detail: {
        // Content
        contentView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .navigationSplitViewStyle(.balanced)  // 或 .prominentDetail
    .navigationTitle("SwiftProxy")
    // ... rest of code
}
```

**改进**:
- ✅ 添加 `columnVisibility` 状态管理
- ✅ 使用 `navigationSplitViewColumnWidth` 精确控制侧边栏宽度范围
- ✅ detail 视图设置 `maxWidth/maxHeight: .infinity` 确保填充空间
- ✅ 使用 `.balanced` 样式实现平衡的分栏布局

### 修复 2: 设置合理的窗口尺寸

```swift
// SwiftProxyApp.swift
WindowGroup {
    MainView(viewModel: viewModel)
        .frame(
            minWidth: 800,
            idealWidth: 1200,
            maxWidth: .infinity,
            minHeight: 600,
            idealHeight: 800,
            maxHeight: .infinity
        )
}
.windowResizability(.contentSize)  // 允许根据内容调整大小
.defaultSize(width: 1200, height: 800)  // 设置默认窗口大小
```

**改进**:
- ✅ 设置 `idealWidth: 1200` - 首次打开时的默认宽度
- ✅ 设置 `idealHeight: 800` - 首次打开时的默认高度
- ✅ 设置 `maxWidth/maxHeight: .infinity` - 允许用户自由调整
- ✅ 使用 `.defaultSize` 明确指定默认窗口大小

### 修复 3: 改进子视图布局

```swift
// ProxyConfigView.swift
var body: some View {
    VStack(spacing: 0) {
        ProxyToggle(...)
            .padding()

        Divider()

        configurationsSection
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

private var configurationsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        // Header
        HStack { /* ... */ }

        // List
        if viewModel.savedConfigurations.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.savedConfigurations) { config in
                        configurationRow(config)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)  // ✅ 添加
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)  // ✅ 添加
}
```

**改进**:
- ✅ 在所有关键 VStack 上添加 `frame(maxWidth: .infinity, maxHeight: .infinity)`
- ✅ ScrollView 也设置相同的 frame 约束
- ✅ 确保内容会自动扩展以填充可用空间

### 修复 4: 改进侧边栏布局

```swift
// MainView.swift
private var sidebarView: some View {
    List(selection: $selectedTab) {
        // ... sections
    }
    .listStyle(.sidebar)
    // ❌ 删除：.frame(minWidth: 220)
    // ✅ 宽度现在通过 navigationSplitViewColumnWidth 控制
}
```

**改进**:
- ✅ 移除侧边栏上的 `.frame(minWidth: 220)`
- ✅ 使用 NavigationSplitView 的 `columnWidth` 来统一管理宽度
- ✅ 避免冲突的布局约束

## 完整的修复代码

### MainView.swift (修复后)

```swift
import SwiftUI

struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @State private var selectedTab: Tab = .proxy
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(viewModel: MainViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            sidebarView
                .navigationSplitViewColumnWidth(
                    min: 200,
                    ideal: 250,
                    max: 350
                )
        } detail: {
            // Content
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("SwiftProxy")
        .toolbar {
            toolbarContent
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    private var sidebarView: some View {
        List(selection: $selectedTab) {
            Section("Proxy") {
                ForEach(Tab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.icon)
                    }
                }
            }

            Section("Status") {
                // Status info
                HStack {
                    StatusIndicator(
                        status: proxyConnectionStatus,
                        showLabel: false
                    )

                    Text(viewModel.isProxyEnabled ? "Active" : "Inactive")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let config = viewModel.currentConfiguration {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(config.name)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(config.address)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Statistics") {
                statisticsSection
            }
        }
        .listStyle(.sidebar)
        // ❌ 删除：.frame(minWidth: 220)
    }

    // ... rest of implementation
}
```

### SwiftProxyApp.swift (修复后)

```swift
import SwiftUI
import OSLog

@main
struct SwiftProxyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel: MainViewModel

    init() {
        Logger.configure()
        let proxyService = ProxyService(logger: Logger.proxyLog)
        _viewModel = StateObject(wrappedValue: MainViewModel(proxyService: proxyService))
    }

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .frame(
                    minWidth: 800,
                    idealWidth: 1200,
                    maxWidth: .infinity,
                    minHeight: 600,
                    idealHeight: 800,
                    maxHeight: .infinity
                )
        }
        .commands {
            proxyCommands
            viewCommands
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView(viewModel: viewModel)
                .frame(
                    minWidth: 700,
                    idealWidth: 800,
                    minHeight: 500,
                    idealHeight: 600
                )
        }
    }

    // ... commands implementation
}
```

### ProxyConfigView.swift (修复后)

```swift
struct ProxyConfigView: View {
    @ObservedObject var viewModel: MainViewModel
    // ... state properties

    var body: some View {
        VStack(spacing: 0) {
            // Proxy toggle
            ProxyToggle(
                isEnabled: $viewModel.isProxyEnabled,
                configuration: viewModel.currentConfiguration,
                onToggle: { Task { await viewModel.toggleProxy() } }
            )
            .padding()

            Divider()

            // Configuration list
            configurationsSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingEditor) {
            configurationEditor
        }
    }

    private var configurationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Saved Configurations")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: createNewConfiguration) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("AddConfigurationButton")
            }
            .padding(.horizontal)
            .padding(.top)

            // List
            if viewModel.savedConfigurations.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.savedConfigurations) { config in
                            configurationRow(config)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ... rest of implementation
}
```

## 修复优先级

### 高优先级 (必须修复)
1. ✅ **MainView.swift**: 添加 `navigationSplitViewColumnWidth` 和 `columnVisibility`
2. ✅ **SwiftProxyApp.swift**: 设置 `idealWidth/idealHeight` 和 `.defaultSize`
3. ✅ **所有子视图**: 添加 `frame(maxWidth: .infinity, maxHeight: .infinity)`

### 中优先级 (建议修复)
4. ✅ 使用 `.navigationSplitViewStyle(.balanced)` 改善分栏行为
5. ✅ 添加 `.windowResizability(.contentSize)` 改善窗口调整行为

### 低优先级 (可选优化)
6. 考虑添加窗口大小持久化 (记住用户的窗口大小偏好)
7. 添加键盘快捷键来切换侧边栏显示/隐藏

## 测试验证

修复后需要测试的场景:

1. **窗口首次打开**
   - ✅ 应该以 1200x800 的尺寸打开
   - ✅ 侧边栏应该是 250 宽

2. **拖动侧边栏分隔线**
   - ✅ 侧边栏应该在 200-350 之间调整
   - ✅ 窗口总宽度应该保持不变或合理调整
   - ✅ detail 视图内容应该自动重排

3. **调整窗口大小**
   - ✅ 窗口应该可以缩小到 800x600
   - ✅ 窗口应该可以无限放大
   - ✅ 内容应该自动适应新尺寸

4. **不同子模块切换**
   - ✅ Proxy、Connections、Statistics、Settings 都应该正常显示
   - ✅ 每个视图都应该填充可用空间

## 预期效果

修复后的行为:

- ✅ **窗口初始尺寸固定**: 1200x800
- ✅ **侧边栏宽度可控**: 200-350px 之间拖动
- ✅ **内容区域自适应**: 自动填充剩余空间
- ✅ **调整窗口大小流畅**: 内容自动重排
- ✅ **拖动分隔线合理**: 不会导致奇怪的布局问题

## 相关文档

- [Apple Human Interface Guidelines - Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [NavigationSplitView Documentation](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [WindowGroup Documentation](https://developer.apple.com/documentation/swiftui/windowgroup)
