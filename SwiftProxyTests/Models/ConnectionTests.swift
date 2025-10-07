import XCTest
@testable import SwiftProxy

/// Unit tests for Connection model
final class ConnectionTests: XCTestCase {

    // MARK: - Test Lifecycle

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func testConnectionInitialization() {
        // Given
        let host = "example.com"
        let port = 443

        // When
        let connection = Connection(host: host, port: port, protocol: .https)

        // Then
        XCTAssertNotNil(connection.id)
        XCTAssertEqual(connection.host, host)
        XCTAssertEqual(connection.port, port)
        XCTAssertEqual(connection.protocol, .https)
        XCTAssertEqual(connection.state, .connecting)
        XCTAssertEqual(connection.bytesReceived, 0)
        XCTAssertEqual(connection.bytesSent, 0)
    }

    // MARK: - State Management Tests

    func testUpdateState() {
        // Given
        var connection = Connection(host: "example.com", port: 80)

        // When
        connection.updateState(.connected)

        // Then
        XCTAssertEqual(connection.state, .connected)
        XCTAssertNil(connection.endTime) // Not a terminal state

        // When - terminal state
        connection.updateState(.closed)

        // Then
        XCTAssertEqual(connection.state, .closed)
        XCTAssertNotNil(connection.endTime)
    }

    func testCloseConnection() {
        // Given
        var connection = Connection(host: "example.com", port: 80)
        connection.updateState(.connected)

        // When - close without error
        connection.close()

        // Then
        XCTAssertEqual(connection.state, .closed)
        XCTAssertNotNil(connection.endTime)
        XCTAssertNil(connection.error)

        // When - close with error
        var connection2 = Connection(host: "example.com", port: 80)
        connection2.close(error: "Connection timeout")

        // Then
        XCTAssertEqual(connection2.state, .failed)
        XCTAssertEqual(connection2.error, "Connection timeout")
    }

    // MARK: - Data Tracking Tests

    func testRecordDataTransfer() {
        // Given
        var connection = Connection(host: "example.com", port: 80)

        // When
        connection.recordDataReceived(1024)
        connection.recordDataSent(512)

        // Then
        XCTAssertEqual(connection.bytesReceived, 1024)
        XCTAssertEqual(connection.bytesSent, 512)
        XCTAssertEqual(connection.totalBytes, 1536)
    }

    func testAverageDataRate() {
        // Given
        var connection = Connection(host: "example.com", port: 80)
        connection.startTime = Date(timeIntervalSinceNow: -10) // 10 seconds ago
        connection.recordDataReceived(10240) // 10 KB

        // When
        let rate = connection.averageDataRate

        // Then
        XCTAssertGreaterThan(rate, 0)
        // Should be approximately 1024 bytes/sec
        XCTAssertEqual(rate, 1024, accuracy: 50)
    }

    // MARK: - Computed Properties Tests

    func testAddress() {
        // Given
        let connection = Connection(host: "example.com", port: 8080)

        // When
        let address = connection.address

        // Then
        XCTAssertEqual(address, "example.com:8080")
    }

    func testIsActive() {
        // Given
        var connection = Connection(host: "example.com", port: 80)

        // Then - initially connecting
        XCTAssertTrue(connection.isActive)

        // When - connected
        connection.updateState(.connected)

        // Then
        XCTAssertTrue(connection.isActive)

        // When - closed
        connection.updateState(.closed)

        // Then
        XCTAssertFalse(connection.isActive)
    }

    func testDuration() {
        // Given
        var connection = Connection(host: "example.com", port: 80)
        connection.startTime = Date(timeIntervalSinceNow: -5) // 5 seconds ago

        // When - connection still active
        let activeDuration = connection.duration

        // Then
        XCTAssertGreaterThanOrEqual(activeDuration, 5)
        XCTAssertLessThan(activeDuration, 6)

        // When - connection closed
        connection.endTime = Date()
        let closedDuration = connection.duration

        // Then
        XCTAssertGreaterThanOrEqual(closedDuration, 5)
        XCTAssertLessThan(closedDuration, 6)
    }

    // MARK: - Filtering Tests

    func testConnectionFilterMatching() {
        // Given
        let connection = Connection(
            processName: "Safari",
            host: "example.com",
            port: 443,
            protocol: .https,
            state: .connected
        )

        // Test state filter
        let stateFilter = ConnectionFilter(states: [.connected])
        XCTAssertTrue(connection.matches(filter: stateFilter))

        let wrongStateFilter = ConnectionFilter(states: [.closed])
        XCTAssertFalse(connection.matches(filter: wrongStateFilter))

        // Test protocol filter
        let protocolFilter = ConnectionFilter(protocols: [.https])
        XCTAssertTrue(connection.matches(filter: protocolFilter))

        // Test process filter
        let processFilter = ConnectionFilter(processName: "Safari")
        XCTAssertTrue(connection.matches(filter: processFilter))

        let wrongProcessFilter = ConnectionFilter(processName: "Chrome")
        XCTAssertFalse(connection.matches(filter: wrongProcessFilter))

        // Test host filter
        let hostFilter = ConnectionFilter(host: "example")
        XCTAssertTrue(connection.matches(filter: hostFilter))
    }

    // MARK: - Codable Tests

    func testConnectionCoding() throws {
        // Given
        let connection = Connection(
            processName: "Safari",
            host: "example.com",
            port: 443,
            protocol: .https,
            state: .connected
        )

        // When - encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(connection)

        // Then - decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Connection.self, from: data)

        // Verify
        XCTAssertEqual(decoded.id, connection.id)
        XCTAssertEqual(decoded.host, connection.host)
        XCTAssertEqual(decoded.port, connection.port)
        XCTAssertEqual(decoded.protocol, connection.protocol)
        XCTAssertEqual(decoded.state, connection.state)
    }

    // MARK: - Comparable Tests

    func testConnectionSorting() {
        // Given
        let connection1 = Connection(host: "a.com", port: 80)
        sleep(1)
        let connection2 = Connection(host: "b.com", port: 80)
        sleep(1)
        let connection3 = Connection(host: "c.com", port: 80)

        // When
        let sorted = [connection1, connection3, connection2].sorted()

        // Then - should be sorted by startTime, most recent first
        XCTAssertEqual(sorted[0].host, "c.com")
        XCTAssertEqual(sorted[1].host, "b.com")
        XCTAssertEqual(sorted[2].host, "a.com")
    }

    // MARK: - Formatting Tests

    func testFormattedBytes() {
        // Given
        let connection = Connection(host: "example.com", port: 80)

        // When/Then
        XCTAssertEqual(connection.formattedBytes(1024), "1 KB")
        XCTAssertEqual(connection.formattedBytes(1048576), "1 MB")
        XCTAssertEqual(connection.formattedBytes(0), "0 bytes")
    }
}
