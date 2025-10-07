import XCTest
@testable import SwiftProxy

/// Comprehensive unit tests for Statistics model
final class StatisticsTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        // Given & When
        let stats = Statistics()

        // Then
        XCTAssertEqual(stats.session.connectionCount, 0)
        XCTAssertEqual(stats.session.activeConnections, 0)
        XCTAssertEqual(stats.session.bytesReceived, 0)
        XCTAssertEqual(stats.session.bytesSent, 0)
        XCTAssertTrue(stats.processes.isEmpty)
        XCTAssertTrue(stats.domains.isEmpty)
        XCTAssertTrue(stats.rules.isEmpty)
        XCTAssertNotNil(stats.lastUpdated)
    }

    // MARK: - Connection Recording Tests

    func testRecordConnection() {
        // Given
        var stats = Statistics()
        let connection = Connection(
            processName: "Safari",
            host: "example.com",
            port: 443,
            protocol: .https,
            state: .connected
        )

        // When
        stats.recordConnection(connection)

        // Then
        XCTAssertEqual(stats.session.connectionCount, 1)
        XCTAssertEqual(stats.session.activeConnections, 1)
        XCTAssertEqual(stats.processes.count, 1)
        XCTAssertEqual(stats.domains.count, 1)
        XCTAssertNotNil(stats.processes["Safari"])
        XCTAssertNotNil(stats.domains["example.com"])
    }

    func testRecordMultipleConnections() {
        // Given
        var stats = Statistics()

        // When
        for i in 0..<10 {
            let connection = Connection(
                processName: "Safari",
                host: "example\(i).com",
                port: 443
            )
            stats.recordConnection(connection)
        }

        // Then
        XCTAssertEqual(stats.session.connectionCount, 10)
        XCTAssertEqual(stats.processes.count, 1) // Same process
        XCTAssertEqual(stats.domains.count, 10) // Different domains
    }

    func testUpdateConnection() {
        // Given
        var stats = Statistics()
        var connection = Connection(host: "example.com", port: 443)
        stats.recordConnection(connection)

        // When
        connection.recordDataReceived(1024)
        connection.recordDataSent(512)
        stats.updateConnection(connection)

        // Then
        XCTAssertNotNil(stats.domains["example.com"])
    }

    // MARK: - Session Statistics Tests

    func testSessionUptime() {
        // Given
        var session = SessionStatistics()
        session.startTime = Date(timeIntervalSinceNow: -3600) // 1 hour ago

        // When
        let uptime = session.uptime

        // Then
        XCTAssertGreaterThanOrEqual(uptime, 3600)
        XCTAssertLessThan(uptime, 3610)
    }

    func testSessionSuccessRate() {
        // Given
        var session = SessionStatistics()
        session.connectionCount = 10
        session.successfulConnections = 8
        session.failedConnections = 2

        // When
        let rate = session.successRate

        // Then
        XCTAssertEqual(rate, 0.8, accuracy: 0.001)
    }

    func testSessionSuccessRateWithZeroConnections() {
        // Given
        let session = SessionStatistics()

        // When
        let rate = session.successRate

        // Then
        XCTAssertEqual(rate, 0)
    }

    func testSessionTotalBytes() {
        // Given
        var session = SessionStatistics()
        session.bytesReceived = 1024
        session.bytesSent = 512

        // When
        let total = session.totalBytes

        // Then
        XCTAssertEqual(total, 1536)
    }

    // MARK: - Domain Statistics Tests

    func testDomainStatisticsRecording() {
        // Given
        var domainStats = DomainStatistics(domain: "example.com")
        let connection = Connection(host: "example.com", port: 443)

        // When
        domainStats.recordConnection(connection)

        // Then
        XCTAssertEqual(domainStats.connectionCount, 1)
        XCTAssertNotNil(domainStats.lastAccessed)
    }

    func testDomainStatisticsTotalBytes() {
        // Given
        var domainStats = DomainStatistics(domain: "example.com")
        domainStats.bytesReceived = 2048
        domainStats.bytesSent = 1024

        // When
        let total = domainStats.totalBytes

        // Then
        XCTAssertEqual(total, 3072)
    }

    // MARK: - Process Statistics Tests

    func testProcessStatisticsRecording() {
        // Given
        var processStats = ProcessStatistics(processName: "Safari")
        let connection = Connection(
            processName: "Safari",
            host: "example.com",
            port: 443
        )

        // When
        processStats.recordConnection(connection)

        // Then
        XCTAssertEqual(processStats.connectionCount, 1)
        XCTAssertNotNil(processStats.lastActive)
    }

    func testProcessStatisticsTotalBytes() {
        // Given
        var processStats = ProcessStatistics(processName: "Safari")
        processStats.bytesReceived = 5120
        processStats.bytesSent = 2560

        // When
        let total = processStats.totalBytes

        // Then
        XCTAssertEqual(total, 7680)
    }

    // MARK: - Rule Statistics Tests

    func testRuleStatisticsRecording() {
        // Given
        let ruleID = UUID()
        var ruleStats = RuleStatistics(ruleID: ruleID)
        var connection = Connection(host: "example.com", port: 443)
        connection.matchedRuleID = ruleID

        // When
        ruleStats.recordConnection(connection)

        // Then
        XCTAssertEqual(ruleStats.matchCount, 1)
        XCTAssertNotNil(ruleStats.lastMatched)
    }

    // MARK: - Top Domains/Processes Tests

    func testTopDomains() {
        // Given
        var stats = Statistics()

        // Create connections to different domains
        let domains = ["google.com", "facebook.com", "apple.com"]
        for (index, domain) in domains.enumerated() {
            for _ in 0...(index + 1) {
                let connection = Connection(host: domain, port: 443)
                stats.recordConnection(connection)
            }
        }

        // When
        let topDomains = stats.topDomains(limit: 2)

        // Then
        XCTAssertEqual(topDomains.count, 2)
        XCTAssertEqual(topDomains[0].domain, "apple.com") // Most connections
    }

    func testTopProcesses() {
        // Given
        var stats = Statistics()

        // Create connections from different processes
        let processes = ["Safari", "Chrome", "Firefox"]
        for (index, process) in processes.enumerated() {
            for _ in 0...(index + 1) {
                let connection = Connection(
                    processName: process,
                    host: "example.com",
                    port: 443
                )
                stats.recordConnection(connection)
            }
        }

        // When
        let topProcesses = stats.topProcesses(limit: 2)

        // Then
        XCTAssertEqual(topProcesses.count, 2)
        XCTAssertEqual(topProcesses[0].process, "Firefox") // Most connections
    }

    // MARK: - Session Reset Tests

    func testResetSession() {
        // Given
        var stats = Statistics()
        for _ in 0..<5 {
            let connection = Connection(host: "example.com", port: 443)
            stats.recordConnection(connection)
        }
        XCTAssertEqual(stats.session.connectionCount, 5)

        // When
        stats.resetSession()

        // Then
        XCTAssertEqual(stats.session.connectionCount, 0)
        XCTAssertEqual(stats.session.activeConnections, 0)
        XCTAssertEqual(stats.session.bytesReceived, 0)
        XCTAssertEqual(stats.session.bytesSent, 0)
    }

    func testClearAll() {
        // Given
        var stats = Statistics()
        for _ in 0..<5 {
            let connection = Connection(
                processName: "Safari",
                host: "example.com",
                port: 443
            )
            stats.recordConnection(connection)
        }

        // When
        stats.clearAll()

        // Then
        XCTAssertEqual(stats.session.connectionCount, 0)
        XCTAssertTrue(stats.processes.isEmpty)
        XCTAssertTrue(stats.domains.isEmpty)
        XCTAssertTrue(stats.rules.isEmpty)
        XCTAssertTrue(stats.historical.dailyStats.isEmpty)
    }

    // MARK: - Historical Statistics Tests

    func testHistoricalArchiving() {
        // Given
        var historical = HistoricalStatistics()
        var session = SessionStatistics()
        session.connectionCount = 100
        session.successfulConnections = 90
        session.bytesReceived = 10240
        session.bytesSent = 5120

        // When
        historical.archiveSession(session)

        // Then
        XCTAssertEqual(historical.dailyStats.count, 1)
        XCTAssertEqual(historical.dailyStats[0].connectionCount, 100)
    }

    // MARK: - Formatting Tests

    func testFormattedBytes() {
        // Given
        let stats = Statistics()

        // Then
        XCTAssertEqual(stats.formattedBytes(1024), "1 KB")
        XCTAssertEqual(stats.formattedBytes(1048576), "1 MB")
        XCTAssertEqual(stats.formattedBytes(1073741824), "1 GB")
    }

    func testFormattedDataRate() {
        // Given
        let stats = Statistics()

        // Then
        let rate = stats.formattedDataRate(1024)
        XCTAssertTrue(rate.contains("KB/s"))
    }

    func testFormattedDuration() {
        // Given
        let stats = Statistics()

        // Then
        let duration = stats.formattedDuration(3665) // 1h 1m 5s
        XCTAssertTrue(duration.contains("1h") || duration.contains("1 hr"))
    }

    func testFormattedPercentage() {
        // Given
        let stats = Statistics()

        // Then
        let percentage = stats.formattedPercentage(0.756)
        XCTAssertTrue(percentage.contains("75") || percentage.contains("76"))
    }

    // MARK: - Codable Tests

    func testEncodingDecoding() throws {
        // Given
        var stats = Statistics()
        for i in 0..<5 {
            let connection = Connection(
                processName: "Safari",
                host: "example\(i).com",
                port: 443
            )
            stats.recordConnection(connection)
        }

        // When - encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(stats)

        // Then - decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Statistics.self, from: data)

        // Verify
        XCTAssertEqual(decoded.session.connectionCount, stats.session.connectionCount)
        XCTAssertEqual(decoded.processes.count, stats.processes.count)
        XCTAssertEqual(decoded.domains.count, stats.domains.count)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        // Given
        let stats1 = Statistics()
        var stats2 = Statistics()

        // Then - initially equal
        XCTAssertEqual(stats1, stats2)

        // When - modify one
        let connection = Connection(host: "example.com", port: 443)
        stats2.recordConnection(connection)

        // Then
        XCTAssertNotEqual(stats1, stats2)
    }

    // MARK: - Performance Tests

    func testPerformanceRecordManyConnections() {
        // Given
        var stats = Statistics()

        // Measure performance
        measure {
            for i in 0..<1000 {
                let connection = Connection(
                    processName: "Process\(i % 10)",
                    host: "example\(i % 100).com",
                    port: 443
                )
                stats.recordConnection(connection)
            }
        }
    }

    // MARK: - Edge Cases

    func testRecordConnectionWithoutProcess() {
        // Given
        var stats = Statistics()
        let connection = Connection(
            processName: nil,
            host: "example.com",
            port: 443
        )

        // When
        stats.recordConnection(connection)

        // Then
        XCTAssertEqual(stats.session.connectionCount, 1)
        XCTAssertTrue(stats.processes.isEmpty) // No process recorded
        XCTAssertEqual(stats.domains.count, 1)
    }

    func testRecordConnectionWithRuleMatch() {
        // Given
        var stats = Statistics()
        let ruleID = UUID()
        var connection = Connection(host: "example.com", port: 443)
        connection.matchedRuleID = ruleID

        // When
        stats.recordConnection(connection)

        // Then
        XCTAssertNotNil(stats.rules[ruleID])
        XCTAssertEqual(stats.rules[ruleID]?.matchCount, 1)
    }

    func testMultipleUpdatesToSameConnection() {
        // Given
        var stats = Statistics()
        var connection = Connection(host: "example.com", port: 443)
        stats.recordConnection(connection)

        // When - multiple updates
        for _ in 0..<5 {
            connection.recordDataReceived(100)
            stats.updateConnection(connection)
        }

        // Then
        XCTAssertEqual(stats.session.connectionCount, 1) // Still just one connection
    }

    // MARK: - DailyStatistics Tests

    func testDailyStatisticsCreation() {
        // Given
        var session = SessionStatistics()
        session.connectionCount = 50
        session.successfulConnections = 45
        session.bytesReceived = 5120
        session.bytesSent = 2560
        let date = Date()

        // When
        let daily = DailyStatistics(date: date, session: session)

        // Then
        XCTAssertEqual(daily.date, date)
        XCTAssertEqual(daily.connectionCount, 50)
        XCTAssertEqual(daily.bytesTransferred, 7680)
    }

    func testDailyStatisticsMerge() {
        // Given
        var session1 = SessionStatistics()
        session1.connectionCount = 50
        session1.successfulConnections = 45
        session1.bytesReceived = 5120
        session1.bytesSent = 2560

        var session2 = SessionStatistics()
        session2.connectionCount = 30
        session2.successfulConnections = 28
        session2.bytesReceived = 3072
        session2.bytesSent = 1536

        var daily = DailyStatistics(date: Date(), session: session1)

        // When
        daily.merge(session: session2)

        // Then
        XCTAssertEqual(daily.connectionCount, 80)
        XCTAssertEqual(daily.bytesTransferred, 12288)
    }
}
