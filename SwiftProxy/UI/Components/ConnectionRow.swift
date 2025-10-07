import SwiftUI

/// Displays a single network request in a list
/// Shows request details, status, and performance metrics
struct ConnectionRow: View {
    // MARK: - Properties

    let request: NetworkRequest
    let onSelect: (() -> Void)?

    @State private var isHovered = false

    // MARK: - Initialization

    init(request: NetworkRequest, onSelect: (() -> Void)? = nil) {
        self.request = request
        self.onSelect = onSelect
    }

    // MARK: - Body

    var body: some View {
        Button(action: { onSelect?() }) {
            HStack(spacing: 12) {
                // Method badge
                methodBadge

                // Request details
                VStack(alignment: .leading, spacing: 4) {
                    // URL
                    Text(request.host)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    // Path
                    Text(request.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Metrics
                HStack(spacing: 16) {
                    // Status code
                    if let statusCode = request.statusCode {
                        statusCodeBadge(statusCode)
                    }

                    // Latency
                    if let latencyMs = request.durationMs {
                        latencyIndicator(latencyMs)
                    }

                    // Size
                    sizeIndicator
                }

                // Status indicator
                statusIcon
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Subviews

    private var methodBadge: some View {
        Text(request.method.rawValue)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(methodColor)
            )
            .frame(width: 60)
    }

    private func statusCodeBadge(_ code: Int) -> some View {
        Text("\(code)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(statusCodeColor(code))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(statusCodeColor(code).opacity(0.15))
            )
    }

    private func latencyIndicator(_ latency: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.caption2)
            Text("\(latency)ms")
                .font(.caption)
        }
        .foregroundColor(latencyColor(latency))
    }

    private var sizeIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption2)
            Text(formatBytes(request.totalSize))
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }

    private var statusIcon: some View {
        Group {
            switch request.status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed, .timeout:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .rejected:
                Image(systemName: "slash.circle.fill")
                    .foregroundColor(.orange)
            case .pending, .inProgress:
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(width: 20)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                isHovered ?
                Color(nsColor: .controlBackgroundColor).opacity(0.8) :
                Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
    }

    // MARK: - Computed Properties

    private var methodColor: Color {
        switch request.method {
        case .GET:
            return .blue
        case .POST:
            return .green
        case .PUT:
            return .orange
        case .DELETE:
            return .red
        case .PATCH:
            return .purple
        default:
            return .gray
        }
    }

    private func statusCodeColor(_ code: Int) -> Color {
        switch code {
        case 200..<300:
            return .green
        case 300..<400:
            return .blue
        case 400..<500:
            return .orange
        case 500..<600:
            return .red
        default:
            return .gray
        }
    }

    private func latencyColor(_ latency: Int) -> Color {
        switch latency {
        case 0..<100:
            return .green
        case 100..<500:
            return .yellow
        case 500..<1000:
            return .orange
        default:
            return .red
        }
    }

    // MARK: - Helper Methods

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Previews

#Preview("Various Requests") {
    ScrollView {
        VStack(spacing: 8) {
            ConnectionRow(
                request: NetworkRequest(
                    method: .GET,
                    url: URL(string: "https://api.example.com/users")!
                )
            )

            ConnectionRow(
                request: {
                    var req = NetworkRequest(
                        method: .POST,
                        url: URL(string: "https://api.example.com/login")!
                    )
                    req.statusCode = 200
                    req.latency = 45.0 / 1000.0
                    req.responseSize = 1024
                    req.status = .completed
                    return req
                }()
            )

            ConnectionRow(
                request: {
                    var req = NetworkRequest(
                        method: .PUT,
                        url: URL(string: "https://cdn.example.com/upload/image.jpg")!
                    )
                    req.statusCode = 404
                    req.latency = 850.0 / 1000.0
                    req.responseSize = 524288
                    req.status = .failed
                    return req
                }()
            )

            ConnectionRow(
                request: {
                    var req = NetworkRequest(
                        method: .DELETE,
                        url: URL(string: "https://api.example.com/users/123")!
                    )
                    req.statusCode = 204
                    req.latency = 25.0 / 1000.0
                    req.status = .completed
                    return req
                }()
            )

            ConnectionRow(
                request: {
                    var req = NetworkRequest(
                        method: .GET,
                        url: URL(string: "https://slow.example.com/data")!
                    )
                    req.status = .inProgress
                    return req
                }()
            )
        }
        .padding()
    }
    .frame(width: 600, height: 400)
}

#Preview("Dark Mode") {
    ScrollView {
        VStack(spacing: 8) {
            ConnectionRow(
                request: {
                    var req = NetworkRequest(
                        method: .GET,
                        url: URL(string: "https://api.example.com/data")!
                    )
                    req.statusCode = 200
                    req.latency = 120.0 / 1000.0
                    req.responseSize = 2048
                    req.status = .completed
                    return req
                }()
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
    .frame(width: 600, height: 200)
}
