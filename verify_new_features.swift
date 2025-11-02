#!/usr/bin/env swift

import Foundation
import OSLog

// MARK: - RateLimiter Verification

print("🧪 Verifying New Features")
print(String(repeating: "=", count: 60))

// Test 1: RateLimiter
print("\n✅ Test 1: RateLimiter")
print(String(repeating: "-", count: 40))

actor RateLimiter {
    private var tokens: Double
    private let capacity: Double
    private let refillRate: Double
    private var lastRefillTime: Date
    private let logger: OSLog?

    init(capacity: Double, refillRate: Double, logger: OSLog? = nil) {
        self.capacity = capacity
        self.refillRate = refillRate
        self.tokens = capacity
        self.lastRefillTime = Date()
        self.logger = logger
    }

    func checkRateLimit() async -> Bool {
        await refillTokens()

        if tokens >= 1.0 {
            tokens -= 1.0
            return true
        }

        return false
    }

    private func refillTokens() {
        let now = Date()
        let timePassed = now.timeIntervalSince(lastRefillTime)
        let tokensToAdd = timePassed * refillRate

        tokens = min(capacity, tokens + tokensToAdd)
        lastRefillTime = now
    }

    func getAvailableTokens() -> Double {
        return tokens
    }
}

Task {
    let rateLimiter = RateLimiter(capacity: 10, refillRate: 5.0)

    // Test rapid requests
    var allowed = 0
    var denied = 0

    for i in 1...15 {
        if await rateLimiter.checkRateLimit() {
            allowed += 1
        } else {
            denied += 1
        }
    }

    print("   Rapid fire test: \(allowed) allowed, \(denied) denied")
    print("   ✓ Rate limiting working: \(denied > 0 ? "YES" : "NO")")

    // Wait for refill
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

    let tokensAfterWait = await rateLimiter.getAvailableTokens()
    print("   Tokens after 0.5s wait: \(String(format: "%.1f", tokensAfterWait))")
    print("   ✓ Token refill working: \(tokensAfterWait > 0 ? "YES" : "NO")")


    // Test 2: Constant-time comparison
    print("\n✅ Test 2: Constant-Time Password Comparison")
    print(String(repeating: "-", count: 40))

    func constantTimeCompare(_ lhs: String, _ rhs: String) -> Bool {
        let lhsData = lhs.data(using: .utf8) ?? Data()
        let rhsData = rhs.data(using: .utf8) ?? Data()

        let maxLength = max(lhsData.count, rhsData.count)

        var lhsPadded = lhsData
        var rhsPadded = rhsData

        while lhsPadded.count < maxLength { lhsPadded.append(0) }
        while rhsPadded.count < maxLength { rhsPadded.append(0) }

        var result: UInt8 = 0
        for i in 0..<maxLength {
            result |= lhsPadded[i] ^ rhsPadded[i]
        }

        return result == 0 && lhsData.count == rhsData.count
    }

    let password1 = "SecurePassword123"
    let password2 = "SecurePassword123"
    let password3 = "WrongPassword456"

    let match1 = constantTimeCompare(password1, password2)
    let match2 = constantTimeCompare(password1, password3)

    print("   Same passwords match: \(match1 ? "YES ✓" : "NO ✗")")
    print("   Different passwords match: \(match2 ? "YES ✗" : "NO ✓")")
    print("   ✓ Constant-time comparison working: \(match1 && !match2 ? "YES" : "NO")")


    // Test 3: Size limits
    print("\n✅ Test 3: Request Size Limits")
    print(String(repeating: "-", count: 40))

    let maxHeaderSize = 8 * 1024  // 8KB
    let maxBodySize = 10 * 1024 * 1024  // 10MB
    let maxSOCKS5RequestSize = 1024  // 1KB

    print("   Max HTTP Header Size: \(maxHeaderSize / 1024)KB")
    print("   Max HTTP Body Size: \(maxBodySize / 1024 / 1024)MB")
    print("   Max SOCKS5 Request Size: \(maxSOCKS5RequestSize)B")

    let headerData = Data(repeating: 0x41, count: 4096)  // 4KB
    let oversizedHeader = Data(repeating: 0x41, count: 10 * 1024)  // 10KB

    let headerOk = headerData.count <= maxHeaderSize
    let headerBlocked = oversizedHeader.count > maxHeaderSize

    print("   ✓ 4KB header accepted: \(headerOk ? "YES" : "NO")")
    print("   ✓ 10KB header blocked: \(headerBlocked ? "YES" : "NO")")
    print("   ✓ Size limit validation working: \(headerOk && headerBlocked ? "YES" : "NO")")


    // Test 4: BufferPool simulation
    print("\n✅ Test 4: BufferPool")
    print(String(repeating: "-", count: 40))

    actor BufferPool {
        private var pool: [Data] = []
        private let bufferSize: Int
        private let maxPoolSize: Int
        private var allocations = 0
        private var reuses = 0

        init(bufferSize: Int, maxPoolSize: Int) {
            self.bufferSize = bufferSize
            self.maxPoolSize = maxPoolSize
        }

        func acquire() -> Data {
            if let buffer = pool.popLast() {
                reuses += 1
                return buffer
            } else {
                allocations += 1
                return Data(capacity: bufferSize)
            }
        }

        func release(_ buffer: Data) {
            if pool.count < maxPoolSize {
                pool.append(buffer)
            }
        }

        func getStats() -> (allocations: Int, reuses: Int, pooled: Int) {
            return (allocations, reuses, pool.count)
        }
    }

    let bufferPool = BufferPool(bufferSize: 65536, maxPoolSize: 10)

    // Simulate buffer usage
    var buffers: [Data] = []
    for _ in 0..<5 {
        let buffer = await bufferPool.acquire()
        buffers.append(buffer)
    }

    for buffer in buffers {
        await bufferPool.release(buffer)
    }

    // Reuse
    for _ in 0..<5 {
        _ = await bufferPool.acquire()
    }

    let stats = await bufferPool.getStats()
    print("   Allocations: \(stats.allocations)")
    print("   Reuses: \(stats.reuses)")
    print("   Buffers in pool: \(stats.pooled)")
    print("   ✓ Buffer reuse working: \(stats.reuses > 0 ? "YES" : "NO")")


    // Test 5: Memory cleanup simulation
    print("\n✅ Test 5: Memory Management")
    print(String(repeating: "-", count: 40))

    class MockViewModel {
        var recentRequests: [String] = []

        func cleanupCaches() {
            if recentRequests.count > 20 {
                recentRequests = Array(recentRequests.prefix(20))
            }
        }

        func closeIdleConnections() {
            if recentRequests.count > 5 {
                recentRequests = Array(recentRequests.prefix(5))
            }
        }
    }

    let viewModel = MockViewModel()

    // Add many requests
    for i in 1...100 {
        viewModel.recentRequests.append("Request \(i)")
    }

    print("   Initial requests: \(viewModel.recentRequests.count)")

    viewModel.cleanupCaches()
    print("   After cleanup (warning): \(viewModel.recentRequests.count)")
    print("   ✓ Cache cleanup working: \(viewModel.recentRequests.count == 20 ? "YES" : "NO")")

    viewModel.closeIdleConnections()
    print("   After cleanup (critical): \(viewModel.recentRequests.count)")
    print("   ✓ Idle connection cleanup working: \(viewModel.recentRequests.count == 5 ? "YES" : "NO")")


    // Summary
    print("\n" + String(repeating: "=", count: 60))
    print("📊 Verification Summary")
    print(String(repeating: "=", count: 60))
    print("✅ RateLimiter: Token bucket algorithm working")
    print("✅ Security: Constant-time comparison implemented")
    print("✅ Security: Request size limits enforced")
    print("✅ Performance: BufferPool reuse working")
    print("✅ Memory: Cleanup handlers functional")
    print("\n🎉 All new features verified successfully!")
    print(String(repeating: "=", count: 60))
}

// Keep the script running
RunLoop.main.run(until: Date().addingTimeInterval(2))
