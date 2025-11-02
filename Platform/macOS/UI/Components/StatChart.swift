import SwiftUI
import Charts

/// Interactive chart component for displaying traffic statistics
/// Supports multiple chart types and time periods
struct StatChart: View {
    // MARK: - Properties

    let data: [ChartDataPoint]
    let chartType: ChartType
    let timeRange: TimeRange

    @State private var selectedDataPoint: ChartDataPoint?

    // MARK: - Initialization

    init(
        data: [ChartDataPoint],
        chartType: ChartType = .line,
        timeRange: TimeRange = .hour
    ) {
        self.data = data
        self.chartType = chartType
        self.timeRange = timeRange
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView

            // Chart
            chartView
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatAxisDate(date))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text(formatYAxisValue(intValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartLegend(position: .top, alignment: .leading)

            // Stats summary
            if let selected = selectedDataPoint {
                selectedPointInfo(selected)
            } else {
                summaryStats
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Traffic")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(timeRange.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            chartTypePicker
        }
    }

    @ViewBuilder
    private var chartView: some View {
        switch chartType {
        case .line:
            lineChart
        case .bar:
            barChart
        case .area:
            areaChart
        }
    }

    private var lineChart: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Requests", point.value)
            )
            .foregroundStyle(by: .value("Type", point.category))
            .interpolationMethod(.catmullRom)

            if let selected = selectedDataPoint, selected.id == point.id {
                PointMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Requests", point.value)
                )
                .foregroundStyle(.accentColor)
                .symbolSize(100)
            }
        }
        .chartAngleSelection(value: $selectedDataPoint)
    }

    private var barChart: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Time", point.timestamp),
                y: .value("Requests", point.value)
            )
            .foregroundStyle(by: .value("Type", point.category))
            .opacity(selectedDataPoint?.id == point.id ? 1.0 : 0.7)
        }
        .chartAngleSelection(value: $selectedDataPoint)
    }

    private var areaChart: some View {
        Chart(data) { point in
            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value("Requests", point.value)
            )
            .foregroundStyle(by: .value("Type", point.category))
            .interpolationMethod(.catmullRom)
            .opacity(0.3)

            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Requests", point.value)
            )
            .foregroundStyle(by: .value("Type", point.category))
            .interpolationMethod(.catmullRom)
        }
        .chartAngleSelection(value: $selectedDataPoint)
    }

    private var chartTypePicker: some View {
        Picker("Chart Type", selection: .constant(chartType)) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .tag(ChartType.line)
                .help("Line Chart")

            Image(systemName: "chart.bar.fill")
                .tag(ChartType.bar)
                .help("Bar Chart")

            Image(systemName: "chart.xyaxis.line")
                .tag(ChartType.area)
                .help("Area Chart")
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
    }

    private func selectedPointInfo(_ point: ChartDataPoint) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Selected Time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatTimestamp(point.timestamp))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(point.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(point.value)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.1))
        )
    }

    private var summaryStats: some View {
        HStack(spacing: 32) {
            statItem(
                label: "Total",
                value: "\(totalRequests)",
                icon: "sum"
            )

            statItem(
                label: "Average",
                value: "\(averageRequests)",
                icon: "chart.bar"
            )

            statItem(
                label: "Peak",
                value: "\(peakRequests)",
                icon: "arrow.up.right"
            )
        }
        .padding(.horizontal)
    }

    private func statItem(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Computed Properties

    private var totalRequests: Int {
        data.reduce(0) { $0 + $1.value }
    }

    private var averageRequests: Int {
        guard !data.isEmpty else { return 0 }
        return totalRequests / data.count
    }

    private var peakRequests: Int {
        data.map(\.value).max() ?? 0
    }

    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .hour:
            return .minute
        case .day:
            return .hour
        case .week:
            return .day
        case .month:
            return .day
        }
    }

    // MARK: - Helper Methods

    private func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()

        switch timeRange {
        case .hour:
            formatter.dateFormat = "HH:mm"
        case .day:
            formatter.dateFormat = "HH:mm"
        case .week:
            formatter.dateFormat = "E"
        case .month:
            formatter.dateFormat = "d"
        }

        return formatter.string(from: date)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatYAxisValue(_ value: Int) -> String {
        if value >= 1000 {
            return "\(value / 1000)k"
        }
        return "\(value)"
    }
}

// MARK: - Supporting Types

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Int
    let category: String
}

enum ChartType {
    case line
    case bar
    case area
}

enum TimeRange {
    case hour
    case day
    case week
    case month

    var displayName: String {
        switch self {
        case .hour: return "Last Hour"
        case .day: return "Last 24 Hours"
        case .week: return "Last Week"
        case .month: return "Last Month"
        }
    }
}

// MARK: - Previews

#Preview("Line Chart") {
    StatChart(
        data: generateSampleData(count: 24),
        chartType: .line,
        timeRange: .day
    )
    .frame(width: 600, height: 350)
    .padding()
}

#Preview("Bar Chart") {
    StatChart(
        data: generateSampleData(count: 7),
        chartType: .bar,
        timeRange: .week
    )
    .frame(width: 600, height: 350)
    .padding()
}

#Preview("Area Chart") {
    StatChart(
        data: generateSampleData(count: 30),
        chartType: .area,
        timeRange: .month
    )
    .frame(width: 600, height: 350)
    .padding()
}

#Preview("Dark Mode") {
    StatChart(
        data: generateSampleData(count: 24),
        chartType: .area,
        timeRange: .day
    )
    .frame(width: 600, height: 350)
    .padding()
    .preferredColorScheme(.dark)
}

// Helper function for previews
private func generateSampleData(count: Int) -> [ChartDataPoint] {
    let now = Date()
    return (0..<count).map { i in
        ChartDataPoint(
            timestamp: now.addingTimeInterval(TimeInterval(-i * 3600)),
            value: Int.random(in: 10...100),
            category: "Requests"
        )
    }.reversed()
}
