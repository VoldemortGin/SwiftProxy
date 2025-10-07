import XCTest
@testable import SwiftProxy

final class RetryHandlerTests: XCTestCase {
    var sut: RetryHandler!

    override func setUp() async throws {
        try await super.setUp()
        sut = RetryHandler(
            maxRetries: 3,
            baseDelay: 0.1, // Short delay for testing
            backoffMultiplier: 2.0,
            maxDelay: 5.0
        )
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Basic Retry Tests

    func testSuccessfulOperationNoRetry() async throws {
        // Given
        var callCount = 0

        // When
        let result = try await sut.execute {
            callCount += 1
            return "Success"
        }

        // Then
        XCTAssertEqual(result, "Success")
        XCTAssertEqual(callCount, 1)

        let stats = await sut.getStatistics()
        XCTAssertEqual(stats.totalRetries, 0)
        XCTAssertEqual(stats.totalSuccesses, 1)
    }

    func testRetryOnTransientError() async throws {
        // Given
        var callCount = 0

        // When
        let result = try await sut.execute {
            callCount += 1
            if callCount < 2 {
                throw AppError.connectionTimeout
            }
            return "Success after retry"
        }

        // Then
        XCTAssertEqual(result, "Success after retry")
        XCTAssertEqual(callCount, 2)

        let stats = await sut.getStatistics()
        XCTAssertGreaterThan(stats.totalRetries, 0)
    }

    func testMaxRetriesExceeded() async throws {
        // Given
        var callCount = 0

        // When/Then
        do {
            _ = try await sut.execute {
                callCount += 1
                throw AppError.connectionTimeout
            }
            XCTFail("Should throw error after max retries")
        } catch {
            XCTAssertEqual(callCount, 4) // Initial attempt + 3 retries
        }

        let stats = await sut.getStatistics()
        XCTAssertGreaterThan(stats.failedRetries, 0)
    }

    func testNonRetryableError() async throws {
        // Given
        var callCount = 0

        // When/Then
        do {
            _ = try await sut.execute {
                callCount += 1
                throw AppError.proxyNotAuthorized
            }
            XCTFail("Should throw non-retryable error immediately")
        } catch {
            XCTAssertEqual(callCount, 1) // Should not retry
        }

        let stats = await sut.getStatistics()
        XCTAssertGreaterThan(stats.nonRetryableErrors, 0)
    }

    // MARK: - Retry Policy Tests

    func testExponentialBackoffPolicy() async throws {
        // Given
        let policy = ExponentialBackoffPolicy(
            maxRetries: 2,
            baseDelay: 0.1,
            multiplier: 2.0
        )
        var callCount = 0

        // When
        let result = try await sut.executeWithPolicy(policy: policy) {
            callCount += 1
            if callCount < 2 {
                throw AppError.connectionTimeout
            }
            return "Success"
        }

        // Then
        XCTAssertEqual(result, "Success")
        XCTAssertEqual(callCount, 2)
    }

    func testLinearBackoffPolicy() async throws {
        // Given
        let policy = LinearBackoffPolicy(
            maxRetries: 2,
            delay: 0.1
        )
        var callCount = 0

        // When
        let result = try await sut.executeWithPolicy(policy: policy) {
            callCount += 1
            if callCount < 2 {
                throw AppError.networkUnavailable
            }
            return "Success"
        }

        // Then
        XCTAssertEqual(result, "Success")
    }

    func testImmediateRetryPolicy() async throws {
        // Given
        let policy = ImmediateRetryPolicy(maxRetries: 2)
        var callCount = 0

        // When
        let result = try await sut.executeWithPolicy(policy: policy) {
            callCount += 1
            if callCount < 2 {
                throw AppError.requestFailed("Transient error")
            }
            return "Success"
        }

        // Then
        XCTAssertEqual(result, "Success")
        XCTAssertEqual(callCount, 2)
    }

    // MARK: - Circuit Breaker Tests

    func testCircuitBreakerOpensAfterFailures() async throws {
        // Given - Create handler with low threshold
        let handler = RetryHandler(
            maxRetries: 1,
            baseDelay: 0.1,
            circuitBreakerThreshold: 2
        )

        // When - Cause multiple failures
        for _ in 0..<3 {
            do {
                _ = try await handler.execute {
                    throw AppError.connectionTimeout
                }
            } catch {
                // Expected to fail
            }
        }

        // Then - Circuit should be open
        let state = await handler.getCircuitBreakerState()
        XCTAssertTrue(state.isOpen)
    }

    func testCircuitBreakerReset() async throws {
        // Given - Handler with circuit breaker
        let handler = RetryHandler(
            maxRetries: 1,
            circuitBreakerThreshold: 2
        )

        // Trigger circuit breaker
        for _ in 0..<3 {
            _ = try? await handler.execute {
                throw AppError.connectionTimeout
            }
        }

        // When
        await handler.resetCircuitBreaker()

        // Then
        let state = await handler.getCircuitBreakerState()
        XCTAssertTrue(state.isClosed)
    }

    // MARK: - Statistics Tests

    func testGetStatistics() async throws {
        // Given
        _ = try await sut.execute {
            return "Success"
        }

        // When
        let stats = await sut.getStatistics()

        // Then
        XCTAssertGreaterThan(stats.totalSuccesses, 0)
    }

    func testResetStatistics() async throws {
        // Given
        _ = try await sut.execute {
            return "Success"
        }

        // When
        await sut.resetStatistics()
        let stats = await sut.getStatistics()

        // Then
        XCTAssertEqual(stats.totalSuccesses, 0)
        XCTAssertEqual(stats.totalRetries, 0)
    }

    func testRetryRate() async throws {
        // Given - Execute with one retry
        var callCount = 0
        _ = try await sut.execute {
            callCount += 1
            if callCount < 2 {
                throw AppError.connectionTimeout
            }
            return "Success"
        }

        // When
        let stats = await sut.getStatistics()

        // Then
        XCTAssertGreaterThan(stats.retryRate, 0)
    }

    func testSuccessRate() async throws {
        // Given
        _ = try await sut.execute { "Success 1" }

        var callCount = 0
        _ = try await sut.execute {
            callCount += 1
            if callCount < 2 {
                throw AppError.connectionTimeout
            }
            return "Success 2"
        }

        // When
        let stats = await sut.getStatistics()

        // Then
        XCTAssertGreaterThan(stats.successRate, 0)
        XCTAssertLessThanOrEqual(stats.successRate, 1.0)
    }
}
