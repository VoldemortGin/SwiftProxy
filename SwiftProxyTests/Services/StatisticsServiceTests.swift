import XCTest
import Combine
@testable import SwiftProxyCore

/// Comprehensive unit tests for StatisticsService
final class StatisticsServiceTests: XCTestCase {

    var sut: StatisticsService!
    var cancellables: Set<AnyCancellable>!
    var tempDirectory: URL!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        cancellables = Set<AnyCancellable>()
        sut = try StatisticsService(fileManager: .default)
    }

    override func tearDownWithError() throws {
        cancellables = nil
        sut = nil

        // Clean up temp directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func testInitialization() throws {
        // Then
        XCTAssertNotNil(sut)
    }

    // MARK: - Connection Recording Tests

    func testRecordConnection() async {
        // Given
        let connection = Connection(
            processName: "Safari",
            host: "example.com",
            port: 443,
            protocol: .https
        )

        // When
        await sut.recordConnection(connection)
        let stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.session.connectionCount, 1)
        XCTAssertEqual(stats.session.activeConnections, 1)
    }

    func testRecordMultipleConnections() async {
        // Given & When
        for i in 0..<10 {
            let connection = Connection(
                processName: "Safari",
                host: "example\(i).com",
                port: 443
            )
            await sut.recordConnection(connection)
        }

        let stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.session.connectionCount, 10)
        XCTAssertEqual(stats.domains.count, 10)
    }

    func testUpdateConnection() async {
        // Given
        var connection = Connection(host: "example.com", port: 443)
        await sut.recordConnection(connection)

        // When
        connection.recordDataReceived(1024)
        connection.recordDataSent(512)
        await sut.updateConnection(connection)

        let stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.session.connectionCount, 1)
    }

    func testRemoveConnection() async {
        // Given
        let connection = Connection(host: "example.com", port: 443)
        await sut.recordConnection(connection)

        var stats = await sut.getStatistics()
        XCTAssertEqual(stats.session.activeConnections, 1)

        // When
        await sut.removeConnection(id: connection.id)

        stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.session.activeConnections, 0)
    }

    // MARK: - Session Management Tests

    func testResetSession() async {
        // Given
        for _ in 0..<5 {
            let connection = Connection(host: "example.com", port: 443)
            await sut.recordConnection(connection)
        }

        var stats = await sut.getStatistics()
        XCTAssertEqual(stats.session.connectionCount, 5)

        // When
        await sut.resetSession()

        stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.session.connectionCount, 0)
        XCTAssertEqual(stats.session.activeConnections, 0)
    }

    // MARK: - Query Tests

    func testGetTopDomains() async {
        // Given
        let domains = ["google.com", "facebook.com", "apple.com"]
        for (index, domain) in domains.enumerated() {
            // Create more connections for later domains
            for _ in 0...index {
                let connection = Connection(host: domain, port: 443)
                await sut.recordConnection(connection)
            }
        }

        // When
        let topDomains = await sut.getTopDomains(limit: 2)

        // Then
        XCTAssertEqual(topDomains.count, 2)
        XCTAssertEqual(topDomains[0].domain, "apple.com")
    }

    func testGetTopProcesses() async {
        // Given
        let processes = ["Safari", "Chrome", "Firefox"]
        for (index, process) in processes.enumerated() {
            for _ in 0...index {
                let connection = Connection(
                    processName: process,
                    host: "example.com",
                    port: 443
                )
                await sut.recordConnection(connection)
            }
        }

        // When
        let topProcesses = await sut.getTopProcesses(limit: 2)

        // Then
        XCTAssertEqual(topProcesses.count, 2)
        XCTAssertEqual(topProcesses[0].process, "Firefox")
    }

    func testGetRuleStatistics() async {
        // Given
        let ruleID = UUID()
        var connection = Connection(host: "example.com", port: 443)
        connection.matchedRuleID = ruleID
        await sut.recordConnection(connection)

        // When
        let ruleStats = await sut.getRuleStatistics(ruleID: ruleID)

        // Then
        XCTAssertNotNil(ruleStats)
        XCTAssertEqual(ruleStats?.matchCount, 1)
    }

    // MARK: - Publisher Tests

    func testStatisticsPublisher() async {
        // Given
        let expectation = XCTestExpectation(description: "Statistics updated")
        var receivedStats: Statistics?

        sut.statistics
            .dropFirst() // Skip initial value
            .sink { stats in
                receivedStats = stats
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        let connection = Connection(host: "example.com", port: 443)
        await sut.recordConnection(connection)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedStats)
        XCTAssertEqual(receivedStats?.session.connectionCount, 1)
    }

    func testSessionStatsPublisher() async {
        // Given
        let expectation = XCTestExpectation(description: "Session stats updated")
        var receivedSession: SessionStatistics?

        sut.sessionStats
            .dropFirst()
            .sink { session in
                receivedSession = session
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        let connection = Connection(host: "example.com", port: 443)
        await sut.recordConnection(connection)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedSession)
        XCTAssertEqual(receivedSession?.connectionCount, 1)
    }

    // MARK: - Persistence Tests

    func testSaveAndLoadStatistics() async throws {
        // Given
        for i in 0..<5 {
            let connection = Connection(
                processName: "Safari",
                host: "example\(i).com",
                port: 443
            )
            await sut.recordConnection(connection)
        }

        // When - save
        try await sut.saveStatistics()

        // Create new service instance to load
        let newService = try StatisticsService(fileManager: .default)
        try await newService.loadStatistics()

        let loadedStats = await newService.getStatistics()

        // Then
        XCTAssertEqual(loadedStats.session.connectionCount, 5)
        XCTAssertEqual(loadedStats.domains.count, 5)
    }

    func testExportStatistics() async throws {
        // Given
        for i in 0..<3 {
            let connection = Connection(host: "example\(i).com", port: 443)
            await sut.recordConnection(connection)
        }

        // When
        let data = try await sut.exportStatistics()

        // Then
        XCTAssertFalse(data.isEmpty)

        // Verify it's valid JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let stats = try decoder.decode(Statistics.self, from: data)
        XCTAssertEqual(stats.session.connectionCount, 3)
    }

    func testClearAllStatistics() async throws {
        // Given
        for _ in 0..<5 {
            let connection = Connection(host: "example.com", port: 443)
            await sut.recordConnection(connection)
        }

        var stats = await sut.getStatistics()
        XCTAssertEqual(stats.session.connectionCount, 5)

        // When
        try await sut.clearAllStatistics()

        stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.session.connectionCount, 0)
        XCTAssertTrue(stats.processes.isEmpty)
        XCTAssertTrue(stats.domains.isEmpty)
    }

    // MARK: - Report Generation Tests

    func testGenerateReport() async {
        // Given
        let processes = ["Safari", "Chrome"]
        let domains = ["google.com", "facebook.com", "apple.com"]

        for process in processes {
            for domain in domains {
                let connection = Connection(
                    processName: process,
                    host: domain,
                    port: 443
                )
                await sut.recordConnection(connection)
            }
        }

        // When
        let report = await sut.generateReport()

        // Then
        XCTAssertNotNil(report.generatedAt)
        XCTAssertEqual(report.totalConnectionCount, 6)
        XCTAssertFalse(report.topDomains.isEmpty)
        XCTAssertFalse(report.topProcesses.isEmpty)
    }

    func testReportFormattedText() async {
        // Given
        for i in 0..<3 {
            let connection = Connection(
                processName: "Safari",
                host: "example\(i).com",
                port: 443
            )
            await sut.recordConnection(connection)
        }

        // When
        let report = await sut.generateReport()
        let text = report.formattedText()

        // Then
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("SwiftProxy Statistics Report"))
        XCTAssertTrue(text.contains("Session Summary"))
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentRecording() async {
        // Given & When
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let connection = Connection(
                        host: "example\(i % 10).com",
                        port: 443
                    )
                    await self.sut.recordConnection(connection)
                }
            }
        }

        let stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.session.connectionCount, 100)
    }

    // MARK: - Performance Tests

    func testPerformanceRecordConnections() {
        // Measure
        measure {
            let expectation = XCTestExpectation(description: "Record connections")

            Task {
                for i in 0..<100 {
                    let connection = Connection(
                        processName: "Process\(i % 5)",
                        host: "example\(i % 20).com",
                        port: 443
                    )
                    await sut.recordConnection(connection)
                }
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - Edge Cases

    func testRecordConnectionWithoutProcess() async {
        // Given
        let connection = Connection(
            processName: nil,
            host: "example.com",
            port: 443
        )

        // When
        await sut.recordConnection(connection)
        let stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.session.connectionCount, 1)
        XCTAssertTrue(stats.processes.isEmpty)
    }

    func testUpdateNonExistentConnection() async {
        // Given
        let connection = Connection(host: "example.com", port: 443)

        // When - update without recording first
        await sut.updateConnection(connection)

        let stats = await sut.getStatistics()

        // Then - should handle gracefully
        XCTAssertEqual(stats.session.connectionCount, 0)
    }

    func testRemoveNonExistentConnection() async {
        // Given
        let nonExistentID = UUID()

        // When
        await sut.removeConnection(id: nonExistentID)

        // Then - should handle gracefully without crashing
        let stats = await sut.getStatistics()
        XCTAssertEqual(stats.session.activeConnections, 0)
    }

    func testZeroBytesTransfer() async {
        // Given
        let connection = Connection(host: "example.com", port: 443)

        // When
        await sut.recordConnection(connection)
        let stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.session.bytesReceived, 0)
        XCTAssertEqual(stats.session.bytesSent, 0)
        XCTAssertEqual(stats.session.totalBytes, 0)
    }
}
