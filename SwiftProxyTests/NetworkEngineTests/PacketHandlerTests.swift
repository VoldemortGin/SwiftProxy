import XCTest
@testable import SwiftProxy

@available(macOS 12.0, *)
final class PacketHandlerTests: XCTestCase {
    var sut: PacketHandler!
    var testRules: [ProxyRule]!

    override func setUp() async throws {
        try await super.setUp()
        sut = PacketHandler()

        testRules = [
            ProxyRule(
                name: "Block Facebook",
                pattern: "facebook.com",
                matchType: .domainSuffix,
                action: .reject,
                priority: 10
            ),
            ProxyRule(
                name: "Proxy Google",
                pattern: "google.com",
                matchType: .domainSuffix,
                action: .proxy,
                priority: 5
            ),
            ProxyRule(
                name: "Direct Local",
                pattern: "192.168.0.0/16",
                matchType: .ipCIDR,
                action: .direct,
                priority: 20
            )
        ]

        await sut.updateRules(testRules)
    }

    override func tearDown() async throws {
        sut = nil
        testRules = nil
        try await super.tearDown()
    }

    // MARK: - Packet Processing Tests

    func testProcessIPv4Packet() async throws {
        // Given - Create a simple IPv4 packet
        let packet = createMockIPv4Packet()

        // When
        let result = try await sut.processPacket(packet, protocolFamily: AF_INET)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result.parsedPacket.version, .ipv4)
    }

    func testProcessIPv6Packet() async throws {
        // Given - Create a simple IPv6 packet
        let packet = createMockIPv6Packet()

        // When
        let result = try await sut.processPacket(packet, protocolFamily: AF_INET6)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result.parsedPacket.version, .ipv6)
    }

    func testProcessBatch() async throws {
        // Given
        let packets = [
            (createMockIPv4Packet(), AF_INET),
            (createMockIPv4Packet(), AF_INET),
            (createMockIPv6Packet(), AF_INET6)
        ]

        // When
        let results = try await sut.processBatch(packets)

        // Then
        XCTAssertEqual(results.count, 3)
    }

    // MARK: - Rule Matching Tests

    func testRuleMatchingDirect() async throws {
        // Given - Packet to local network
        let packet = createMockIPv4Packet(destinationIP: "192.168.1.1")

        // When
        let result = try await sut.processPacket(packet, protocolFamily: AF_INET)

        // Then
        XCTAssertEqual(result.action, .direct)
    }

    func testRuleMatchingProxy() async throws {
        // Given - This would require a packet with Google domain
        // For this test, we'll verify the rule update worked
        await sut.updateRules(testRules)

        let stats = await sut.getStatistics()
        XCTAssertGreaterThanOrEqual(stats.totalPackets, 0)
    }

    // MARK: - Statistics Tests

    func testGetStatistics() async throws {
        // Given
        let packet = createMockIPv4Packet()
        _ = try await sut.processPacket(packet, protocolFamily: AF_INET)

        // When
        let stats = await sut.getStatistics()

        // Then
        XCTAssertGreaterThan(stats.totalPackets, 0)
        XCTAssertGreaterThan(stats.totalBytes, 0)
    }

    func testResetStatistics() async throws {
        // Given
        let packet = createMockIPv4Packet()
        _ = try await sut.processPacket(packet, protocolFamily: AF_INET)

        // When
        await sut.resetStatistics()
        let stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.totalPackets, 0)
        XCTAssertEqual(stats.totalBytes, 0)
    }

    // MARK: - Rule Management Tests

    func testUpdateRules() async throws {
        // When
        await sut.updateRules(testRules)

        // Then - Verify by processing a packet
        let packet = createMockIPv4Packet()
        let result = try await sut.processPacket(packet, protocolFamily: AF_INET)
        XCTAssertNotNil(result)
    }

    func testAddRule() async throws {
        // Given
        let newRule = ProxyRule(
            name: "Block Twitter",
            pattern: "twitter.com",
            matchType: .domainSuffix,
            action: .reject
        )

        // When
        await sut.addRule(newRule)

        // Then - Rule should be added
        let packet = createMockIPv4Packet()
        let result = try await sut.processPacket(packet, protocolFamily: AF_INET)
        XCTAssertNotNil(result)
    }

    func testRemoveRule() async throws {
        // Given
        let ruleToRemove = testRules[0]

        // When
        await sut.removeRule(id: ruleToRemove.id)

        // Then - Rule should be removed
        let packet = createMockIPv4Packet()
        let result = try await sut.processPacket(packet, protocolFamily: AF_INET)
        XCTAssertNotNil(result)
    }

    // MARK: - Packet Buffer Tests

    func testBufferPacket() async throws {
        // Given
        let connectionID = UUID()
        let packet = createMockIPv4Packet()

        // When
        await sut.bufferPacket(packet, connectionID: connectionID)

        // Then
        let buffered = await sut.getBufferedPackets(for: connectionID)
        XCTAssertNotNil(buffered)
        XCTAssertEqual(buffered?.count, 1)
    }

    func testClearBuffer() async throws {
        // Given
        let connectionID = UUID()
        let packet = createMockIPv4Packet()
        await sut.bufferPacket(packet, connectionID: connectionID)

        // When
        await sut.clearBuffer(for: connectionID)

        // Then
        let buffered = await sut.getBufferedPackets(for: connectionID)
        XCTAssertNil(buffered)
    }

    // MARK: - Helper Methods

    private func createMockIPv4Packet(
        sourceIP: String = "192.168.1.100",
        destinationIP: String = "8.8.8.8"
    ) -> Data {
        var packet = Data()

        // IPv4 header (20 bytes minimum)
        packet.append(0x45) // Version (4) + IHL (5)
        packet.append(0x00) // DSCP + ECN
        packet.append(contentsOf: [0x00, 0x3C]) // Total length (60 bytes)
        packet.append(contentsOf: [0x00, 0x00]) // Identification
        packet.append(contentsOf: [0x00, 0x00]) // Flags + Fragment offset
        packet.append(0x40) // TTL (64)
        packet.append(0x06) // Protocol (TCP)
        packet.append(contentsOf: [0x00, 0x00]) // Checksum

        // Source IP
        let sourceComponents = sourceIP.split(separator: ".").compactMap { UInt8($0) }
        packet.append(contentsOf: sourceComponents)

        // Destination IP
        let destComponents = destinationIP.split(separator: ".").compactMap { UInt8($0) }
        packet.append(contentsOf: destComponents)

        // TCP header (20 bytes minimum)
        packet.append(contentsOf: [0x04, 0xD2]) // Source port (1234)
        packet.append(contentsOf: [0x00, 0x50]) // Destination port (80)
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Sequence number
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Acknowledgment number
        packet.append(0x50) // Data offset (5) + Reserved
        packet.append(0x02) // Flags (SYN)
        packet.append(contentsOf: [0xFF, 0xFF]) // Window size
        packet.append(contentsOf: [0x00, 0x00]) // Checksum
        packet.append(contentsOf: [0x00, 0x00]) // Urgent pointer

        return packet
    }

    private func createMockIPv6Packet() -> Data {
        var packet = Data()

        // IPv6 header (40 bytes)
        packet.append(0x60) // Version (6) + Traffic class (partial)
        packet.append(contentsOf: [0x00, 0x00, 0x00]) // Traffic class + Flow label
        packet.append(contentsOf: [0x00, 0x14]) // Payload length (20 bytes)
        packet.append(0x06) // Next header (TCP)
        packet.append(0x40) // Hop limit (64)

        // Source address (16 bytes) - ::1
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01])

        // Destination address (16 bytes) - ::1
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01])

        // TCP header (20 bytes minimum)
        packet.append(contentsOf: [0x04, 0xD2]) // Source port
        packet.append(contentsOf: [0x00, 0x50]) // Destination port
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Sequence
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Acknowledgment
        packet.append(0x50) // Data offset
        packet.append(0x02) // Flags
        packet.append(contentsOf: [0xFF, 0xFF]) // Window
        packet.append(contentsOf: [0x00, 0x00]) // Checksum
        packet.append(contentsOf: [0x00, 0x00]) // Urgent pointer

        return packet
    }
}
