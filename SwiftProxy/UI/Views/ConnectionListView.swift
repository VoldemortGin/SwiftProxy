import SwiftUI

/// Displays a live list of network connections
/// Supports filtering, searching, and detailed inspection
struct ConnectionListView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: MainViewModel
    @State private var searchText = ""
    @State private var selectedStatus: RequestStatus?
    @State private var selectedRequest: NetworkRequest?
    @State private var showingDetails = false
    @State private var sortOrder: SortOrder = .timeDescending

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()

            Divider()

            // Filters
            filterBar
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Content
            if filteredRequests.isEmpty {
                emptyStateView
            } else {
                connectionsList
            }
        }
        .sheet(isPresented: $showingDetails) {
            if let request = selectedRequest {
                RequestDetailsView(request: request)
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Connections")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(filteredRequests.count) requests")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: clearConnections) {
                Label("Clear", systemImage: "trash")
            }
            .disabled(viewModel.recentRequests.isEmpty)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search host...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            // Status filter
            Menu {
                Button("All") {
                    selectedStatus = nil
                }

                Divider()

                ForEach([RequestStatus.completed, .failed, .rejected, .inProgress], id: \.self) { status in
                    Button(status.rawValue.capitalized) {
                        selectedStatus = status
                    }
                }
            } label: {
                Label(
                    selectedStatus?.rawValue.capitalized ?? "All Status",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }
            .frame(width: 150)

            // Sort order
            Menu {
                Button("Time (Newest)") {
                    sortOrder = .timeDescending
                }
                Button("Time (Oldest)") {
                    sortOrder = .timeAscending
                }
                Button("Latency (High)") {
                    sortOrder = .latencyDescending
                }
                Button("Latency (Low)") {
                    sortOrder = .latencyAscending
                }
                Button("Size (Large)") {
                    sortOrder = .sizeDescending
                }
                Button("Size (Small)") {
                    sortOrder = .sizeAscending
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .frame(width: 120)
        }
    }

    private var connectionsList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(sortedRequests) { request in
                    ConnectionRow(request: request) {
                        selectedRequest = request
                        showingDetails = true
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding()
        }
        .animation(.easeInOut(duration: 0.2), value: filteredRequests.count)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.recentRequests.isEmpty ? "network" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(viewModel.recentRequests.isEmpty ? "No Connections Yet" : "No Matching Connections")
                .font(.headline)

            Text(viewModel.recentRequests.isEmpty ?
                 "Network requests will appear here when the proxy is active" :
                 "Try adjusting your search or filter criteria"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

            if !viewModel.recentRequests.isEmpty {
                Button("Clear Filters") {
                    searchText = ""
                    selectedStatus = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Computed Properties

    private var filteredRequests: [NetworkRequest] {
        var requests = viewModel.recentRequests

        // Apply search filter
        if !searchText.isEmpty {
            requests = requests.filter { request in
                request.host.localizedCaseInsensitiveContains(searchText) ||
                request.path.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply status filter
        if let status = selectedStatus {
            requests = requests.filter { $0.status == status }
        }

        return requests
    }

    private var sortedRequests: [NetworkRequest] {
        filteredRequests.sorted { lhs, rhs in
            switch sortOrder {
            case .timeAscending:
                return lhs.timestamp < rhs.timestamp
            case .timeDescending:
                return lhs.timestamp > rhs.timestamp
            case .latencyAscending:
                return (lhs.latency ?? 0) < (rhs.latency ?? 0)
            case .latencyDescending:
                return (lhs.latency ?? 0) > (rhs.latency ?? 0)
            case .sizeAscending:
                return lhs.totalSize < rhs.totalSize
            case .sizeDescending:
                return lhs.totalSize > rhs.totalSize
            }
        }
    }

    // MARK: - Methods

    private func clearConnections() {
        withAnimation {
            viewModel.clearRequests()
        }
    }
}

// MARK: - Sort Order

enum SortOrder {
    case timeAscending
    case timeDescending
    case latencyAscending
    case latencyDescending
    case sizeAscending
    case sizeDescending
}

// MARK: - Request Details View

struct RequestDetailsView: View {
    let request: NetworkRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    summarySection

                    Divider()

                    // Request details
                    detailsSection("Request", items: requestDetails)

                    if request.statusCode != nil {
                        Divider()
                        detailsSection("Response", items: responseDetails)
                    }

                    if !request.headers.isEmpty {
                        Divider()
                        headersSection("Request Headers", headers: request.headers)
                    }

                    if let responseHeaders = request.responseHeaders, !responseHeaders.isEmpty {
                        Divider()
                        headersSection("Response Headers", headers: responseHeaders)
                    }
                }
                .padding()
            }
            .navigationTitle("Request Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(request.method.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )

                if let statusCode = request.statusCode {
                    Text("\(statusCode)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(statusColor(statusCode))
                        )
                }

                Spacer()

                Image(systemName: statusIcon)
                    .foregroundColor(statusIconColor)
                    .font(.title2)
            }

            Text(request.url.absoluteString)
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }

    private func detailsSection(_ title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(item.1)
                            .textSelection(.enabled)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func headersSection(_ title: String, headers: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(Array(headers.sorted(by: { $0.key < $1.key })), id: \.key) { header in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(header.key)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(header.value)
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var requestDetails: [(String, String)] {
        var items: [(String, String)] = [
            ("Host", request.host),
            ("Path", request.path),
            ("Timestamp", formatDate(request.timestamp)),
            ("Size", formatBytes(request.requestSize))
        ]

        if let processName = request.processName {
            items.append(("Process", processName))
        }

        return items
    }

    private var responseDetails: [(String, String)] {
        var items: [(String, String)] = []

        if let statusCode = request.statusCode {
            items.append(("Status Code", "\(statusCode)"))
        }

        items.append(("Size", formatBytes(request.responseSize)))

        if let latency = request.latency {
            items.append(("Latency", String(format: "%.0f ms", latency * 1000)))
        }

        if let endTime = request.endTime {
            items.append(("Completed", formatDate(endTime)))
        }

        return items
    }

    private var statusIcon: String {
        switch request.status {
        case .completed:
            return "checkmark.circle.fill"
        case .failed, .timeout:
            return "xmark.circle.fill"
        case .rejected:
            return "slash.circle.fill"
        default:
            return "clock.fill"
        }
    }

    private var statusIconColor: Color {
        switch request.status {
        case .completed:
            return .green
        case .failed, .timeout:
            return .red
        case .rejected:
            return .orange
        default:
            return .gray
        }
    }

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }
}

// MARK: - Previews

#Preview("With Data") {
    ConnectionListView(viewModel: {
        let vm = MainViewModel.preview
        // Add sample requests
        for i in 0..<10 {
            var req = NetworkRequest(
                method: [HTTPMethod.GET, .POST, .PUT][i % 3],
                url: URL(string: "https://api\(i).example.com/data/endpoint")!
            )
            req.statusCode = [200, 404, 500][i % 3]
            req.latency = Double(Int.random(in: 50...500)) / 1000.0
            req.responseSize = Int64.random(in: 1024...1048576)
            req.status = [.completed, .failed, .rejected][i % 3]
            vm.addRequest(req)
        }
        return vm
    }())
    .frame(width: 800, height: 600)
}

#Preview("Empty") {
    ConnectionListView(viewModel: .preview)
        .frame(width: 800, height: 600)
}

#Preview("Dark Mode") {
    ConnectionListView(viewModel: .preview)
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
}
