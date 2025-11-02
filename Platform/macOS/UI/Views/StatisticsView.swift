import SwiftUI
import SwiftProxyCore
import Charts

/// Comprehensive statistics and analytics view
/// Displays charts, metrics, and insights about network traffic
struct StatisticsView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedTimeRange: TimeRange = .day
    @State private var selectedMetric: MetricType = .requests
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
            Spacer()
            Menu {
                Button("Export CSV") {
                    exportStatistics()
                }
                Button("Export JSON") {
                    exportStatistics(format: .json)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
    private var timeRangeSelector: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach([TimeRange.hour, .day, .week, .month], id: \.self) { range in
                Text(range.displayName).tag(range)
        .pickerStyle(.segmented)
    private var mainChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Metric selector
            Picker("Metric", selection: $selectedMetric) {
                Text("Requests").tag(MetricType.requests)
                Text("Data Transfer").tag(MetricType.data)
                Text("Latency").tag(MetricType.latency)
            .pickerStyle(.segmented)
            // Chart
            StatChart(
                data: chartData,
                chartType: .area,
                timeRange: selectedTimeRange
            )
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
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
                title: "Success Rate",
                value: successRate,
                icon: "checkmark.circle.fill",
                color: .green
                title: "Failed Requests",
                value: "\(viewModel.statistics.failedRequests)",
                icon: "xmark.circle.fill",
                color: .red
                title: "Data Downloaded",
                value: formatBytes(viewModel.statistics.totalBytesIn),
                icon: "arrow.down.circle.fill",
                color: .purple
                title: "Data Uploaded",
                value: formatBytes(viewModel.statistics.totalBytesOut),
                icon: "arrow.up.circle.fill",
                color: .orange
                title: "Avg Latency",
                value: formatLatency(viewModel.statistics.averageLatency),
                icon: "timer.circle.fill",
                color: .cyan
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
                Text(value)
                Text(title)
                    .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    private var topDomainsList: some View {
            Text("Top Domains")
                .font(.headline)
            if topDomains.isEmpty {
                Text("No data available")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topDomains.prefix(10)), id: \.key) { domain, count in
                        domainRow(domain: domain, count: count)
                    }
    private func domainRow(domain: String, count: Int) -> some View {
            Text(domain)
                .font(.subheadline)
                .lineLimit(1)
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            // Bar
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: geometry.size.width * domainPercentage(count))
            .frame(width: 60, height: 8)
    private var methodDistributionChart: some View {
            Text("Request Methods")
            if methodDistribution.isEmpty {
                Chart(methodDistribution, id: \.method) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Method", item.method.rawValue))
                    .cornerRadius(4)
                .frame(height: 200)
                .chartLegend(position: .trailing, alignment: .center)
                // Method breakdown
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
                .padding(.top, 8)
    // MARK: - Computed Properties
    private var chartData: [ChartDataPoint] {
        // Generate sample data based on recent requests
        let calendar = Calendar.current
        let now = Date()
        var dataPoints: [ChartDataPoint] = []
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
            dataPoints.append(ChartDataPoint(
                timestamp: date,
                value: value,
                category: selectedMetric.rawValue
            ))
        return dataPoints.reversed()
    private var successRate: String {
        guard viewModel.statistics.totalRequests > 0 else { return "0%" }
        let rate = Double(viewModel.statistics.successfulRequests) / Double(viewModel.statistics.totalRequests) * 100
        return String(format: "%.1f%%", rate)
    private var topDomains: [(key: String, value: Int)] {
        viewModel.statistics.requestsByHost
            .sorted { $0.value > $1.value }
    private var methodDistribution: [MethodDistributionItem] {
        let total = viewModel.statistics.totalRequests
        guard total > 0 else { return [] }
        return viewModel.statistics.requestsByMethod.map { method, count in
            MethodDistributionItem(
                method: method,
                count: count,
                percentage: Int(Double(count) / Double(total) * 100)
        .sorted { $0.count > $1.count }
    // MARK: - Helper Methods
    private func domainPercentage(_ count: Int) -> Double {
        guard let maxCount = topDomains.first?.value, maxCount > 0 else {
            return 0
        return Double(count) / Double(maxCount)
    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .GET: return .blue
        case .POST: return .green
        case .PUT: return .orange
        case .DELETE: return .red
        case .PATCH: return .purple
        default: return .gray
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    private func formatLatency(_ latency: TimeInterval) -> String {
        String(format: "%.0f ms", latency * 1000)
    private func exportStatistics(format: ExportFormat = .csv) {
        // TODO: Implement export functionality
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "statistics.\(format.rawValue)"
        panel.allowedContentTypes = [format.contentType]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // Export data
                print("Export to \(url)")
}
// MARK: - Supporting Types
enum MetricType: String {
    case requests = "Requests"
    case data = "Data Transfer"
    case latency = "Latency"
struct MethodDistributionItem {
    let method: HTTPMethod
    let count: Int
    let percentage: Int
enum ExportFormat: String {
    case csv
    case json
    var contentType: UTType {
        switch self {
        case .csv: return .commaSeparatedText
        case .json: return .json
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
        vm.statistics = stats
        return vm
    }())
    .frame(width: 900, height: 1000)
#Preview("Dark Mode") {
    StatisticsView(viewModel: .preview)
        .frame(width: 900, height: 1000)
        .preferredColorScheme(.dark)
