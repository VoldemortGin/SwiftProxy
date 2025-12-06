import SwiftUI

/// 订阅管理视图
/// 管理所有订阅源和代理节点
struct SubscriptionManagerView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: SubscriptionViewModel
    @State private var showingAddDialog = false
    @State private var selectedSubscription: Subscription?
    @State private var selectedNode: ProxyNode?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()

            Divider()

            // Content
            if viewModel.subscriptions.isEmpty {
                emptyStateView
            } else {
                HSplitView {
                    // 左侧：订阅列表
                    subscriptionsList
                        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)

                    // 右侧：节点列表
                    nodesView
                        .frame(minWidth: 400, maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAddDialog) {
            AddSubscriptionDialog(viewModel: viewModel)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("订阅管理")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(viewModel.subscriptions.count) 个订阅 | \(viewModel.totalNodesCount) 个节点")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { showingAddDialog = true }) {
                Label("添加订阅", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var subscriptionsList: some View {
        VStack(spacing: 0) {
            // 列表标题
            HStack {
                Text("订阅列表")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)

                Spacer()
            }

            Divider()
                .padding(.vertical, 8)

            // 订阅列表
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.subscriptions) { subscription in
                        SubscriptionRow(
                            subscription: subscription,
                            isSelected: selectedSubscription?.id == subscription.id,
                            onSelect: { selectedSubscription = subscription },
                            onUpdate: { viewModel.updateSubscription(subscription) },
                            onDelete: { viewModel.deleteSubscription(subscription.id) },
                            onToggle: { viewModel.toggleSubscription(subscription.id) }
                        )
                    }
                }
                .padding()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var nodesView: some View {
        VStack(spacing: 0) {
            // 节点列表标题
            HStack {
                if let subscription = selectedSubscription {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscription.name)
                            .font(.headline)

                        Text("\(subscription.nodes.count) 个节点")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("所有节点")
                        .font(.headline)
                }

                Spacer()

                if selectedSubscription != nil {
                    Button(action: { selectedSubscription = nil }) {
                        Label("显示所有", systemImage: "list.bullet")
                    }
                }
            }
            .padding()

            Divider()

            // 节点列表
            let nodes = selectedSubscription?.nodes ?? viewModel.allNodes

            if nodes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("暂无节点")
                        .font(.headline)

                    Text("添加订阅后将自动获取节点列表")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(nodes) { node in
                            NodeRow(
                                node: node,
                                isSelected: selectedNode?.id == node.id,
                                onSelect: { selectedNode = node },
                                onTest: { await viewModel.testNode(node.id) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("还没有订阅")
                .font(.title2)
                .fontWeight(.semibold)

            Text("添加你的第一个订阅源来获取代理节点")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { showingAddDialog = true }) {
                Label("添加订阅", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Subscription Row

struct SubscriptionRow: View {
    let subscription: Subscription
    let isSelected: Bool
    let onSelect: () -> Void
    let onUpdate: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 顶部：名称和状态
            HStack {
                Image(systemName: subscription.isEnabled ? "link.circle.fill" : "link.circle")
                    .foregroundColor(subscription.isEnabled ? .green : .secondary)

                Text(subscription.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()
            }

            // 节点数量和更新时间
            HStack {
                Label("\(subscription.activeNodesCount)", systemImage: "server.rack")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let lastUpdated = subscription.lastUpdated {
                    Text(lastUpdated, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("未更新")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 操作按钮
            HStack(spacing: 8) {
                Button(action: onUpdate) {
                    Label("更新", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Button(action: onToggle) {
                    Label(subscription.isEnabled ? "禁用" : "启用",
                          systemImage: subscription.isEnabled ? "pause.circle" : "play.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Node Row

struct NodeRow: View {
    let node: ProxyNode
    let isSelected: Bool
    let onSelect: () -> Void
    let onTest: () async -> Void

    @State private var isTesting = false

    var body: some View {
        HStack(spacing: 12) {
            // 协议图标
            Image(systemName: node.type.systemImageName)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)

            // 节点信息
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // 协议类型
                    Text(node.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.2))
                        )

                    // 地址
                    Text(node.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 延迟
            if let latency = node.latency {
                latencyBadge(latency)
            } else {
                Text("未测试")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 测试按钮
            Button(action: {
                isTesting = true
                Task {
                    await onTest()
                    isTesting = false
                }
            }) {
                if isTesting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "speedometer")
                }
            }
            .buttonStyle(.borderless)
            .disabled(isTesting)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        )
        .onTapGesture(perform: onSelect)
    }

    private func latencyBadge(_ latency: TimeInterval) -> some View {
        let status = node.latencyStatus
        let color: Color

        switch status {
        case .excellent:
            color = .green
        case .good:
            color = .blue
        case .fair:
            color = .orange
        case .poor:
            color = .red
        case .unknown:
            color = .gray
        }

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text("\(Int(latency))ms")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Add Subscription Dialog

struct AddSubscriptionDialog: View {
    @ObservedObject var viewModel: SubscriptionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var url = ""
    @State private var updateInterval: TimeInterval = 86400  // 24 hours
    @State private var errorMessage: String?
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            Form {
                Section("订阅信息") {
                    TextField("名称", text: $name)
                        .help("为这个订阅起一个容易识别的名字")

                    TextField("订阅 URL", text: $url, axis: .vertical)
                        .lineLimit(3...5)
                        .help("粘贴订阅链接")
                        .autocorrectionDisabled()
                }

                Section("自动更新") {
                    Picker("更新频率", selection: $updateInterval) {
                        Text("6 小时").tag(TimeInterval(21600))
                        Text("12 小时").tag(TimeInterval(43200))
                        Text("24 小时").tag(TimeInterval(86400))
                        Text("48 小时").tag(TimeInterval(172800))
                        Text("不自动更新").tag(TimeInterval.infinity)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("添加订阅")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        addSubscription()
                    }
                    .disabled(name.isEmpty || url.isEmpty || isAdding)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func addSubscription() {
        errorMessage = nil
        isAdding = true

        Task {
            do {
                try await viewModel.addSubscription(
                    name: name,
                    url: url,
                    updateInterval: updateInterval
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAdding = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("With Subscriptions") {
    SubscriptionManagerView(viewModel: {
        let vm = SubscriptionViewModel.preview
        return vm
    }())
    .frame(width: 1000, height: 700)
}

#Preview("Empty") {
    SubscriptionManagerView(viewModel: SubscriptionViewModel.preview)
        .frame(width: 1000, height: 700)
}
