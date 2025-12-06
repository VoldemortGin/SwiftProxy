// SwiftProxy - PacketHandler Usage Examples
// Demonstrates advanced packet handling features

import Foundation
import OSLog

// MARK: - Example 1: Basic Packet Buffering

func exampleBasicBuffering() async throws {
    let handler = PacketHandler()
    let connectionID = UUID()

    // Buffer packets with sequence numbers
    let packet1 = Data("Hello ".utf8)
    let packet2 = Data("World!".utf8)

    try await handler.bufferPacket(packet1, connectionID: connectionID, sequenceNumber: 1)
    try await handler.bufferPacket(packet2, connectionID: connectionID, sequenceNumber: 2)

    // Retrieve ordered packets
    let orderedPackets = await handler.getBufferedPackets(for: connectionID)
    print("Buffered \(orderedPackets.count) packets")

    // Get coalesced (merged) buffer
    if let merged = await handler.getCoalescedBuffer(for: connectionID) {
        if let message = String(data: merged, encoding: .utf8) {
            print("Merged message: \(message)")
        }
    }

    // Clean up
    await handler.clearBuffer(for: connectionID)
}

// MARK: - Example 2: Out-of-Order Packet Handling

func exampleOutOfOrderPackets() async throws {
    let handler = PacketHandler()
    let connectionID = UUID()

    // Receive packets out of order (common in UDP)
    let packets = [
        (Data("Third".utf8), UInt32(3)),
        (Data("First".utf8), UInt32(1)),
        (Data("Second".utf8), UInt32(2))
    ]

    // Buffer in random order
    for (data, seq) in packets {
        try await handler.bufferPacket(data, connectionID: connectionID, sequenceNumber: seq)
    }

    // Packets are automatically reordered
    let ordered = await handler.getBufferedPackets(for: connectionID)
    for (index, packet) in ordered.enumerated() {
        let text = String(data: packet, encoding: .utf8) ?? "unknown"
        print("Packet \(index + 1): \(text)")
    }
    // Output: Packet 1: First, Packet 2: Second, Packet 3: Third
}

// MARK: - Example 3: Traffic Shaping Configuration

func exampleTrafficShaping() async throws {
    // Create custom traffic shaping config
    let config = TrafficShapingConfig(
        maxBytesPerSecond: 5_000_000,  // 5 MB/s
        burstSize: 1_000_000,           // 1 MB burst
        enablePriorityQueues: true,
        queueCount: 3
    )

    let handler = PacketHandler(trafficShapingConfig: config)

    // High priority connection (e.g., video streaming)
    let videoPriority = UUID()
    try await handler.shapeTraffic(for: videoPriority, priorityClass: .high)

    // Normal priority (e.g., web browsing)
    let webPriority = UUID()
    try await handler.shapeTraffic(for: webPriority, priorityClass: .normal)

    // Low priority (e.g., background downloads)
    let downloadPriority = UUID()
    try await handler.shapeTraffic(for: downloadPriority, priorityClass: .low)

    // Monitor traffic shaping statistics
    let stats = await handler.getTrafficShapingStats()
    print("Passed: \(stats.passedPackets), Dropped: \(stats.droppedPackets)")
    print("Drop rate: \(stats.dropRate * 100)%")
}

// MARK: - Example 4: Dynamic Traffic Control

func exampleDynamicTrafficControl() async throws {
    let handler = PacketHandler()

    // Start with conservative limits
    var config = TrafficShapingConfig(
        maxBytesPerSecond: 1_000_000,  // 1 MB/s
        burstSize: 100_000,
        enablePriorityQueues: true,
        queueCount: 3
    )

    // Process traffic...
    // ... time passes ...

    // Detect good network conditions, increase limits
    config = TrafficShapingConfig(
        maxBytesPerSecond: 10_000_000,  // 10 MB/s
        burstSize: 2_000_000,
        enablePriorityQueues: true,
        queueCount: 3
    )

    await handler.updateTrafficShaping(config: config)
    print("Traffic limits increased due to good network conditions")
}

// MARK: - Example 5: Packet Size Optimization

func examplePacketSizeOptimization() async {
    let handler = PacketHandler()
    let connectionID = UUID()

    // Configure MTU for connection (e.g., detected via path MTU discovery)
    await handler.updateMTU(for: connectionID, mtu: 1500)

    // Get optimal packet size
    let optimalSize = await handler.getOptimalPacketSize(for: connectionID)
    print("Optimal packet size: \(optimalSize) bytes")  // ~1440 bytes

    // Large data to send
    let largeData = Data(count: 10_000)

    // Optimize into properly sized packets
    let packets = await handler.optimizePacketSize(for: connectionID, data: largeData)
    print("Split into \(packets.count) optimally-sized packets")

    // Send packets
    for (index, packet) in packets.enumerated() {
        print("Packet \(index + 1): \(packet.count) bytes")
        // await sendToNetwork(packet)
    }
}

// MARK: - Example 6: Nagle Algorithm for Small Packets

func exampleNagleAlgorithm() async {
    let handler = PacketHandler()
    let connectionID = UUID()

    // Enable Nagle algorithm to coalesce small packets
    await handler.setNagleEnabled(true, for: connectionID)

    // Send many small packets (e.g., keystrokes in SSH)
    let smallData1 = Data("a".utf8)  // 1 byte
    let smallData2 = Data("b".utf8)  // 1 byte
    let smallData3 = Data("c".utf8)  // 1 byte

    // These will be buffered until optimal size is reached
    var packets1 = await handler.optimizePacketSize(for: connectionID, data: smallData1)
    var packets2 = await handler.optimizePacketSize(for: connectionID, data: smallData2)
    var packets3 = await handler.optimizePacketSize(for: connectionID, data: smallData3)

    print("Small packets buffered (Nagle enabled)")
    print("Packets to send: \(packets1.count + packets2.count + packets3.count)")

    // Disable Nagle for immediate sending (e.g., real-time gaming)
    await handler.setNagleEnabled(false, for: connectionID)

    let packet4 = await handler.optimizePacketSize(for: connectionID, data: Data("d".utf8))
    print("Nagle disabled - immediate send: \(packet4.count) packet(s)")
}

// MARK: - Example 7: Jumbo Frames for High Throughput

func exampleJumboFrames() async {
    let handler = PacketHandler()
    let connectionID = UUID()

    // Use jumbo frames for high-speed networks (9000 byte MTU)
    await handler.updateMTU(for: connectionID, mtu: 9000)

    let optimalSize = await handler.getOptimalPacketSize(for: connectionID)
    print("Jumbo frame optimal size: \(optimalSize) bytes")  // ~8940 bytes

    // Send large file
    let fileData = Data(count: 1_000_000)  // 1 MB
    let packets = await handler.optimizePacketSize(for: connectionID, data: fileData)

    print("File split into \(packets.count) jumbo packets")
    // Far fewer packets than standard MTU
}

// MARK: - Example 8: Complete Proxy Connection Flow

func exampleCompleteFlow() async throws {
    // Initialize with production settings
    let config = TrafficShapingConfig(
        maxBytesPerSecond: 100_000_000,  // 100 MB/s
        burstSize: 10_000_000,            // 10 MB
        enablePriorityQueues: true,
        queueCount: 3
    )

    let handler = PacketHandler(
        maxBufferSize: 50_000_000,  // 50 MB
        trafficShapingConfig: config
    )

    let connectionID = UUID()

    // 1. Detect MTU
    await handler.updateMTU(for: connectionID, mtu: 1500)

    // 2. Enable Nagle for efficiency
    await handler.setNagleEnabled(true, for: connectionID)

    // 3. Set priority based on traffic type
    try await handler.shapeTraffic(for: connectionID, priorityClass: .high)

    // 4. Receive fragmented packets
    let fragment1 = Data(count: 1000)
    let fragment2 = Data(count: 1000)
    let fragment3 = Data(count: 500)

    try await handler.bufferPacket(fragment1, connectionID: connectionID, sequenceNumber: 1)
    try await handler.bufferPacket(fragment2, connectionID: connectionID, sequenceNumber: 2)
    try await handler.bufferPacket(fragment3, connectionID: connectionID, sequenceNumber: 3)

    // 5. Get complete reassembled data
    if let completeData = await handler.getCoalescedBuffer(for: connectionID) {
        print("Reassembled \(completeData.count) bytes")

        // 6. Optimize for sending
        let optimized = await handler.optimizePacketSize(
            for: connectionID,
            data: completeData
        )

        print("Ready to send \(optimized.count) optimized packets")
    }

    // 7. Monitor performance
    let stats = await handler.getTrafficShapingStats()
    print("Traffic stats - Pass: \(stats.passedPackets), Drop: \(stats.droppedPackets)")

    // 8. Cleanup
    await handler.clearBuffer(for: connectionID)
}

// MARK: - Example 9: Bandwidth-Limited Mobile Connection

func exampleMobileConnection() async throws {
    // Conservative settings for mobile
    let config = TrafficShapingConfig(
        maxBytesPerSecond: 500_000,    // 500 KB/s (4 Mbps)
        burstSize: 100_000,             // 100 KB burst
        enablePriorityQueues: true,
        queueCount: 3
    )

    let handler = PacketHandler(
        maxBufferSize: 5_000_000,  // 5 MB buffer
        trafficShapingConfig: config
    )

    // Prioritize critical traffic
    let criticalConnection = UUID()
    try await handler.shapeTraffic(for: criticalConnection, priorityClass: .high)

    // Use smaller MTU for mobile
    await handler.updateMTU(for: criticalConnection, mtu: 1280)

    // Enable aggressive Nagle to reduce packet count
    await handler.setNagleEnabled(true, for: criticalConnection)

    print("Mobile connection optimized for bandwidth efficiency")
}

// MARK: - Example 10: High-Performance Server Configuration

func exampleHighPerformanceServer() async throws {
    // Maximum performance settings
    let config = TrafficShapingConfig(
        maxBytesPerSecond: 1_000_000_000,  // 1 GB/s
        burstSize: 100_000_000,             // 100 MB
        enablePriorityQueues: false,        // Disable for max speed
        queueCount: 1
    )

    let handler = PacketHandler(
        maxBufferSize: 100_000_000,  // 100 MB buffer
        trafficShapingConfig: config
    )

    let connectionID = UUID()

    // Use jumbo frames for LAN
    await handler.updateMTU(for: connectionID, mtu: 9000)

    // Disable Nagle for low latency
    await handler.setNagleEnabled(false, for: connectionID)

    // Process large data transfer
    let bigData = Data(count: 100_000_000)  // 100 MB
    let packets = await handler.optimizePacketSize(for: connectionID, data: bigData)

    print("High-performance: \(packets.count) packets for 100MB transfer")
}

// MARK: - Example 11: Monitoring and Diagnostics

func exampleMonitoring() async throws {
    let handler = PacketHandler()

    // Get packet statistics
    let packetStats = handler.getStatistics()
    print("""
    Packet Statistics:
    - Total Packets: \(packetStats.totalPackets)
    - Total Bytes: \(packetStats.totalBytes)
    - Direct: \(packetStats.directPackets)
    - Proxied: \(packetStats.proxiedPackets)
    - Rejected: \(packetStats.rejectedPackets)
    - Dropped: \(packetStats.droppedPackets)
    - Packets/sec: \(packetStats.packetsPerSecond)
    """)

    // Get traffic shaping statistics
    let trafficStats = await handler.getTrafficShapingStats()
    print("""
    Traffic Shaping:
    - Passed: \(trafficStats.passedPackets)
    - Dropped: \(trafficStats.droppedPackets)
    - Pass Rate: \((1.0 - trafficStats.dropRate) * 100)%
    - Total Passed Bytes: \(trafficStats.totalPassedBytes)
    - Total Dropped Bytes: \(trafficStats.totalDroppedBytes)
    """)
}

// MARK: - Example 12: Error Handling

func exampleErrorHandling() async {
    let handler = PacketHandler(maxBufferSize: 1000)  // Very small for demo
    let connectionID = UUID()

    do {
        // Try to buffer too much data
        let largePacket = Data(count: 2000)
        try await handler.bufferPacket(largePacket, connectionID: connectionID)
    } catch {
        print("Error: \(error)")
        // Handle buffer overflow
        await handler.clearBuffer(for: connectionID)
        print("Buffer cleared due to overflow")
    }
}

// MARK: - Main Example Runner

@main
struct PacketHandlerExamples {
    static func main() async {
        print("SwiftProxy PacketHandler Usage Examples\n")
        print("=========================================\n")

        do {
            print("1. Basic Buffering:")
            try await exampleBasicBuffering()
            print()

            print("2. Out-of-Order Packets:")
            try await exampleOutOfOrderPackets()
            print()

            print("3. Traffic Shaping:")
            try await exampleTrafficShaping()
            print()

            print("4. Packet Size Optimization:")
            await examplePacketSizeOptimization()
            print()

            print("5. Complete Flow:")
            try await exampleCompleteFlow()
            print()

            print("\n✅ All examples completed successfully!")

        } catch {
            print("❌ Error running examples: \(error)")
        }
    }
}
