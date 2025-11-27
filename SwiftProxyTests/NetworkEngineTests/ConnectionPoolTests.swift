import XCTest
import Network
@testable import SwiftProxyCore

@available(macOS 12.0, *)
final class ConnectionPoolTests: XCTestCase {
    var sut: ConnectionPool!

    override func setUp() async throws {
        try await super.setUp()
        sut = ConnectionPool(
            maxConnections: 10,
            maxIdleTime: 300,
            healthCheckInterval: 60
        )
    }

    override func tearDown() async throws {
        await sut?.closeAll()
        await sut?.stopCleanup()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Connection Management Tests

    func testGetConnection() async throws {
        // When
        let connection = try await sut.getConnection(
            host: "example.com",
            port: 443,
            useTLS: true
        )

        // Then
        XCTAssertNotNil(connection)
    }

    func testConnectionReuse() async throws {
        // Given
        let host = "example.com"
        let port = 443

        // When
        let connection1 = try await sut.getConnection(host: host, port: port, useTLS: true)
        await sut.returnConnection(connection1, host: host, port: port, useTLS: true)

        let connection2 = try await sut.getConnection(host: host, port: port, useTLS: true)

        // Then - Statistics should show a pool hit
        let stats = await sut.getStatistics()
        XCTAssertGreaterThan(stats.poolHits, 0)
    }

    func testPoolMiss() async throws {
        // When
        _ = try await sut.getConnection(host: "example.com", port: 443, useTLS: true)

        // Then
        let stats = await sut.getStatistics()
        XCTAssertGreaterThan(stats.poolMisses, 0)
        XCTAssertEqual(stats.poolHits, 0)
    }

    func testMaxConnectionsLimit() async throws {
        // Given - Pool with max 2 connections
        let smallPool = ConnectionPool(maxConnections: 2)

        // When - Create and return 3 connections
        let conn1 = try await smallPool.getConnection(host: "example.com", port: 80, useTLS: false)
        await smallPool.returnConnection(conn1, host: "example.com", port: 80, useTLS: false)

        let conn2 = try await smallPool.getConnection(host: "example.com", port: 80, useTLS: false)
        await smallPool.returnConnection(conn2, host: "example.com", port: 80, useTLS: false)

        let conn3 = try await smallPool.getConnection(host: "example.com", port: 80, useTLS: false)
        await smallPool.returnConnection(conn3, host: "example.com", port: 80, useTLS: false)

        // Then - Should have dropped at least one connection
        let stats = await smallPool.getStatistics()
        XCTAssertGreaterThan(stats.droppedConnections, 0)

        await smallPool.closeAll()
    }

    // MARK: - Statistics Tests

    func testGetStatistics() async throws {
        // Given
        _ = try await sut.getConnection(host: "example.com", port: 443, useTLS: true)

        // When
        let stats = await sut.getStatistics()

        // Then
        XCTAssertGreaterThan(stats.totalCreated, 0)
        XCTAssertGreaterThan(stats.activeConnections, 0)
    }

    func testResetStatistics() async throws {
        // Given
        _ = try await sut.getConnection(host: "example.com", port: 443, useTLS: true)

        // When
        await sut.resetStatistics()
        let stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.poolHits, 0)
        XCTAssertEqual(stats.poolMisses, 0)
    }

    func testGetHitRate() async throws {
        // Given
        let connection = try await sut.getConnection(host: "example.com", port: 443, useTLS: true)
        await sut.returnConnection(connection, host: "example.com", port: 443, useTLS: true)

        // Create a pool hit
        _ = try await sut.getConnection(host: "example.com", port: 443, useTLS: true)

        // When
        let hitRate = await sut.getHitRate()

        // Then
        XCTAssertGreaterThan(hitRate, 0)
        XCTAssertLessThanOrEqual(hitRate, 1.0)
    }

    // MARK: - Pool Info Tests

    func testGetPoolInfo() async throws {
        // Given
        _ = try await sut.getConnection(host: "example.com", port: 443, useTLS: true)

        // When
        let info = await sut.getPoolInfo()

        // Then
        XCTAssertGreaterThan(info.activeConnectionCount, 0)
        XCTAssertEqual(info.maxConnections, 10)
    }

    // MARK: - Connection Cleanup Tests

    func testCloseAll() async throws {
        // Given
        _ = try await sut.getConnection(host: "example.com", port: 443, useTLS: true)
        _ = try await sut.getConnection(host: "google.com", port: 443, useTLS: true)

        // When
        await sut.closeAll()

        // Then
        let stats = await sut.getStatistics()
        XCTAssertEqual(stats.activeConnections, 0)
        XCTAssertEqual(stats.availableConnections, 0)
    }
}
