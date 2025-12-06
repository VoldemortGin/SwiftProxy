import SwiftUI
import SwiftProxyCore
import Charts
import UniformTypeIdentifiers

/// Comprehensive statistics and analytics view
/// Displays charts, metrics, and insights about network traffic
struct StatisticsView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedTimeRange: TimeRange = .day
    @State private var selectedMetric: MetricType = .requests
    @State private var showingExportSheet = false
    @State private var exportConfiguration = ExportConfiguration()
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showingExportAlert = false

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerView

                // Time range selector
                timeRangeSelector

                // Main chart
                mainChart

                // Metrics grid
                metricsGrid

                // Top domains
                topDomainsList

                // Method distribution
                methodDistributionChart
            }
            .padding()
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportConfigurationView(
                configuration: $exportConfiguration,
                connections: convertNetworkRequestsToConnections(viewModel.recentRequests),
                statistics: convertTrafficStatistics(viewModel.statistics)
            ) { config in
                showingExportSheet = false
                performExport(with: config)
            }
        }
        .alert("Export Status", isPresented: $showingExportAlert) {
            Button("OK") {
                exportError = nil
            }
        } message: {
            if let error = exportError {
                Text(error)
            } else {
                Text("Statistics exported successfully!")
            }
        }
    }

    // MARK: - Subviews
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Statistics")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Network traffic analytics")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                showingExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(isExporting)
        }
    }

    private var timeRangeSelector: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach([TimeRange.hour, .day, .week, .month], id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var mainChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Metric selector
            Picker("Metric", selection: $selectedMetric) {
                Text("Requests").tag(MetricType.requests)
                Text("Data Transfer").tag(MetricType.data)
                Text("Latency").tag(MetricType.latency)
            }
            .pickerStyle(.segmented)

            // Chart
            StatChart(
                data: chartData,
                chartType: .area,
                timeRange: selectedTimeRange
            )
            .frame(height: 250)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            metricCard(
                title: "Total Requests",
                value: "\(viewModel.statistics.totalRequests)",
                icon: "arrow.up.arrow.down.circle.fill",
                color: .blue
            )

            metricCard(
                title: "Success Rate",
                value: successRate,
                icon: "checkmark.circle.fill",
                color: .green
            )

            metricCard(
                title: "Failed Requests",
                value: "\(viewModel.statistics.failedRequests)",
                icon: "xmark.circle.fill",
                color: .red
            )

            metricCard(
                title: "Data Downloaded",
                value: formatBytes(viewModel.statistics.totalBytesIn),
                icon: "arrow.down.circle.fill",
                color: .purple
            )

            metricCard(
                title: "Data Uploaded",
                value: formatBytes(viewModel.statistics.totalBytesOut),
                icon: "arrow.up.circle.fill",
                color: .orange
            )

            metricCard(
                title: "Avg Latency",
                value: formatLatency(viewModel.statistics.averageLatency),
                icon: "timer.circle.fill",
                color: .cyan
            )
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()

                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var topDomainsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Domains")
                .font(.headline)

            if topDomains.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topDomains.prefix(10)), id: \.key) { domain, count in
                        domainRow(domain: domain, count: count)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func domainRow(domain: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Text(domain)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            // Bar
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: geometry.size.width * domainPercentage(count))
            }
            .frame(width: 60, height: 8)
        }
    }

    private var methodDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Request Methods")
                .font(.headline)

            if methodDistribution.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Use bar chart instead of SectorMark (macOS 14.0+ only)
                Chart(methodDistribution, id: \.method) { item in
                    BarMark(
                        x: .value("Count", item.count)
                    )
                    .foregroundStyle(by: .value("Method", item.method.rawValue))
                }
                .frame(height: 200)
                .chartLegend(position: .trailing, alignment: .center)

                // Method breakdown
                VStack(spacing: 8) {
                    ForEach(methodDistribution, id: \.method) { item in
                        HStack {
                            Circle()
                                .fill(methodColor(item.method))
                                .frame(width: 10, height: 10)

                            Text(item.method.rawValue)
                                .font(.subheadline)

                            Spacer()

                            Text("\(item.count)")
                                .fontWeight(.semibold)

                            Text("(\(item.percentage)%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Computed Properties
    private var chartData: [StatChartDataPoint] {
        // Generate sample data based on recent requests
        let calendar = Calendar.current
        let now = Date()
        var dataPoints: [StatChartDataPoint] = []

        let intervals: Int
        let component: Calendar.Component

        switch selectedTimeRange {
        case .hour:
            intervals = 12
            component = .minute
        case .day:
            intervals = 24
            component = .hour
        case .week:
            intervals = 7
            component = .day
        case .month:
            intervals = 30
            component = .day
        }

        for i in 0..<intervals {
            let date = calendar.date(byAdding: component, value: -i, to: now) ?? now
            let value: Int

            switch selectedMetric {
            case .requests:
                value = Int.random(in: 10...100) // Mock data
            case .data:
                value = Int.random(in: 100...1000)
            case .latency:
                value = Int.random(in: 50...500)
            }

            dataPoints.append(StatChartDataPoint(
                timestamp: date,
                value: value,
                category: selectedMetric.rawValue
            ))
        }

        return dataPoints.reversed()
    }

    private var successRate: String {
        guard viewModel.statistics.totalRequests > 0 else { return "0%" }
        let rate = Double(viewModel.statistics.successfulRequests) / Double(viewModel.statistics.totalRequests) * 100
        return String(format: "%.1f%%", rate)
    }

    private var topDomains: [(key: String, value: Int)] {
        viewModel.statistics.requestsByHost
            .sorted { $0.value > $1.value }
    }

    private var methodDistribution: [MethodDistributionItem] {
        let total = viewModel.statistics.totalRequests
        guard total > 0 else { return [] }

        return viewModel.statistics.requestsByMethod.map { method, count in
            MethodDistributionItem(
                method: method,
                count: count,
                percentage: Int(Double(count) / Double(total) * 100)
            )
        }
        .sorted { $0.count > $1.count }
    }

    // MARK: - Helper Methods
    private func domainPercentage(_ count: Int) -> Double {
        guard let maxCount = topDomains.first?.value, maxCount > 0 else {
            return 0
        }
        return Double(count) / Double(maxCount)
    }

    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .GET: return .blue
        case .POST: return .green
        case .PUT: return .orange
        case .DELETE: return .red
        case .PATCH: return .purple
        default: return .gray
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }

    private func formatLatency(_ latency: TimeInterval) -> String {
        String(format: "%.0f ms", latency * 1000)
    }

    private func performExport(with configuration: ExportConfiguration) {
        // Show save panel
        let panel = NSSavePanel()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = dateFormatter.string(from: Date())
        panel.nameFieldStringValue = "swiftproxy_statistics_\(timestamp).\(configuration.format.fileExtension)"
        panel.allowedContentTypes = [configuration.format == .csv ? .commaSeparatedText : .json]
        panel.canCreateDirectories = true
        panel.showsTagField = true

        panel.begin { [self] response in
            guard response == .OK, let url = panel.url else { return }

            // Perform export asynchronously
            isExporting = true
            Task {
                do {
                    // Convert data for export
                    let connections = convertNetworkRequestsToConnections(viewModel.recentRequests)
                    let statistics = convertTrafficStatistics(viewModel.statistics)

                    // Export data
                    let data = try await ExportService.shared.exportStatistics(
                        statistics: statistics,
                        connections: connections,
                        configuration: configuration
                    )

                    // Write to file
                    try data.write(to: url, options: .atomic)

                    // Success
                    await MainActor.run {
                        isExporting = false
                        exportError = nil
                        showingExportAlert = true
                    }
                } catch {
                    // Error
                    await MainActor.run {
                        isExporting = false
                        exportError = "Failed to export: \(error.localizedDescription)"
                        showingExportAlert = true
                    }
                }
            }
        }
    }

    // MARK: - Data Conversion

    private func convertNetworkRequestsToConnections(_ requests: [NetworkRequest]) -> [Connection] {
        return requests.map { request in
            Connection(
                id: request.id,
                processName: request.processName,
                processID: request.processID,
                host: request.host,
                port: request.url.port ?? (request.url.scheme == "https" ? 443 : 80),
                protocol: convertProxyTypeToConnectionProtocol(request.proxyType),
                state: convertRequestStatusToConnectionState(request.status),
                startTime: request.startTime,
                endTime: request.endTime,
                bytesReceived: UInt64(request.responseSize),
                bytesSent: UInt64(request.requestSize),
                requestURL: request.url,
                requestMethod: request.method.rawValue,
                responseStatusCode: request.statusCode,
                error: request.error
            )
        }
    }

    private func convertTrafficStatistics(_ traffic: TrafficStatistics) -> Statistics {
        var statistics = Statistics()

        // Convert session statistics
        statistics.session = SessionStatistics(
            startTime: traffic.startTime,
            connectionCount: traffic.totalRequests,
            activeConnections: 0,
            successfulConnections: traffic.successfulRequests,
            failedConnections: traffic.failedRequests,
            rejectedConnections: traffic.rejectedRequests,
            bytesReceived: UInt64(traffic.totalBytesIn),
            bytesSent: UInt64(traffic.totalBytesOut),
            averageConnectionDuration: traffic.averageLatency,
            averageDataRate: 0
        )

        // Convert domain statistics
        for (host, count) in traffic.requestsByHost {
            statistics.domains[host] = DomainStatistics(
                domain: host,
                connectionCount: count
            )
        }

        return statistics
    }

    private func convertProxyTypeToConnectionProtocol(_ proxyType: ProxyType) -> ConnectionProtocol {
        switch proxyType {
        case .http:
            return .http
        case .https:
            return .https
        case .socks5:
            return .tcp
        case .direct, .proxy:
            return .tcp
        }
    }

    private func convertRequestStatusToConnectionState(_ status: RequestStatus) -> ConnectionState {
        switch status {
        case .pending:
            return .connecting
        case .inProgress:
            return .connected
        case .completed:
            return .closed
        case .failed, .timeout:
            return .failed
        case .rejected:
            return .rejected
        }
    }
}

// MARK: - Supporting Types
enum MetricType: String {
    case requests = "Requests"
    case data = "Data Transfer"
    case latency = "Latency"
}

struct MethodDistributionItem {
    let method: HTTPMethod
    let count: Int
    let percentage: Int
}

// MARK: - Previews
#Preview("Statistics View") {
    StatisticsView(viewModel: {
        let vm = MainViewModel.preview
        // Add sample data
        var stats = TrafficStatistics()
        stats.totalRequests = 1234
        stats.successfulRequests = 1100
        stats.failedRequests = 134
        stats.totalBytesIn = 52428800 // 50MB
        stats.totalBytesOut = 10485760 // 10MB
        stats.averageLatency = 0.125
        stats.requestsByMethod = [
            .GET: 800,
            .POST: 300,
            .PUT: 80,
            .DELETE: 54
        ]
        stats.requestsByHost = [
            "api.example.com": 450,
            "cdn.example.com": 320,
            "static.example.com": 200,
            "images.example.com": 150,
            "analytics.example.com": 114
        ]
        vm.statistics = stats
        return vm
    }())
    .frame(width: 900, height: 1000)
}

#Preview("Dark Mode") {
    StatisticsView(viewModel: .preview)
        .frame(width: 900, height: 1000)
        .preferredColorScheme(.dark)
}
