import Foundation
import OSLog

/// Handles retry logic for network operations with exponential backoff
/// Provides configurable retry strategies, circuit breaking, and error classification
public actor RetryHandler {
    // MARK: - Properties

    private let logger: OSLog
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    private let backoffMultiplier: Double
    private let maxDelay: TimeInterval

    // Circuit breaker state
    private var circuitBreaker: CircuitBreaker

    // Retry statistics
    private var statistics: RetryStatistics = RetryStatistics()

    // Error classifier
    private let errorClassifier: ErrorClassifier

    // MARK: - Initialization

    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        maxDelay: TimeInterval = 30.0,
        circuitBreakerThreshold: Int = 5,
        circuitBreakerTimeout: TimeInterval = 60.0,
        logger: OSLog = OSLog(subsystem: "com.swiftproxy", category: "RetryHandler")
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.backoffMultiplier = backoffMultiplier
        self.maxDelay = maxDelay
        self.logger = logger
        self.circuitBreaker = CircuitBreaker(
            failureThreshold: circuitBreakerThreshold,
            resetTimeout: circuitBreakerTimeout
        )
        self.errorClassifier = ErrorClassifier()
    }

    // MARK: - Retry Execution

    /// Execute an operation with retry logic
    public func execute<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        // Check circuit breaker
        guard await circuitBreaker.allowRequest() else {
            os_log(.default, log: logger, "Circuit breaker is open, rejecting request")
            throw AppError.requestFailed("Circuit breaker open")
        }

        var lastError: Error?
        var attempt = 0

        while attempt <= maxRetries {
            do {
                // Execute the operation
                let result = try await operation()

                // Operation succeeded
                if attempt > 0 {
                    os_log(.info, log: logger, "Operation succeeded after \(attempt) retries")
                    statistics.successfulRetries += 1
                }

                await circuitBreaker.recordSuccess()
                statistics.totalSuccesses += 1

                return result

            } catch {
                lastError = error
                attempt += 1

                // Classify error to determine if we should retry
                let classification = errorClassifier.classify(error)

                guard classification.isRetryable else {
                    os_log(.error, log: logger, "Non-retryable error: \(error.localizedDescription)")
                    statistics.nonRetryableErrors += 1
                    await circuitBreaker.recordFailure()
                    throw error
                }

                // Check if we've exhausted retries
                guard attempt <= self.maxRetries else {
                    os_log(.error, log: self.logger, "Max retries (\(self.maxRetries)) exceeded")
                    statistics.failedRetries += 1
                    await circuitBreaker.recordFailure()
                    throw error
                }

                // Calculate delay with exponential backoff
                let delay = calculateDelay(attempt: attempt)

                os_log(.default, log: logger, "Attempt \(attempt) failed, retrying in \(delay)s: \(error.localizedDescription)")
                statistics.totalRetries += 1

                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        // This should never be reached, but just in case
        throw lastError ?? AppError.unknown(NSError(domain: "RetryHandler", code: -1))
    }

    /// Execute with custom retry policy
    public func executeWithPolicy<T>(
        policy: RetryPolicy,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var attempt = 0

        while attempt <= policy.maxRetries {
            do {
                let result = try await operation()

                if attempt > 0 {
                    statistics.successfulRetries += 1
                }

                return result

            } catch {
                lastError = error
                attempt += 1

                // Check if error is retryable according to policy
                guard policy.shouldRetry(error, attempt: attempt) else {
                    throw error
                }

                guard attempt <= policy.maxRetries else {
                    throw error
                }

                // Apply policy-specific delay
                let delay = policy.delayForAttempt(attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? AppError.unknown(NSError(domain: "RetryHandler", code: -1))
    }

    // MARK: - Delay Calculation

    private func calculateDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff: baseDelay * (backoffMultiplier ^ (attempt - 1))
        let exponentialDelay = baseDelay * pow(backoffMultiplier, Double(attempt - 1))

        // Add jitter to prevent thundering herd
        let jitter = Double.random(in: 0...0.3) * exponentialDelay

        // Cap at maximum delay
        return min(exponentialDelay + jitter, maxDelay)
    }

    // MARK: - Circuit Breaker

    /// Reset the circuit breaker
    public func resetCircuitBreaker() async {
        await circuitBreaker.reset()
        os_log(.info, log: logger, "Circuit breaker reset")
    }

    /// Get circuit breaker state
    public func getCircuitBreakerState() async -> CircuitBreakerState {
        await circuitBreaker.getState()
    }

    // MARK: - Statistics

    public func getStatistics() -> RetryStatistics {
        statistics
    }

    public func resetStatistics() {
        statistics = RetryStatistics()
    }
}

// MARK: - Retry Policy

public protocol RetryPolicy {
    var maxRetries: Int { get }
    func shouldRetry(_ error: Error, attempt: Int) -> Bool
    func delayForAttempt(_ attempt: Int) -> TimeInterval
}

// MARK: - Built-in Retry Policies

public struct ExponentialBackoffPolicy: RetryPolicy {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let multiplier: Double

    public init(maxRetries: Int = 3, baseDelay: TimeInterval = 1.0, multiplier: Double = 2.0) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.multiplier = multiplier
    }

    public func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        ErrorClassifier().classify(error).isRetryable
    }

    public func delayForAttempt(_ attempt: Int) -> TimeInterval {
        baseDelay * pow(multiplier, Double(attempt - 1))
    }
}

public struct LinearBackoffPolicy: RetryPolicy {
    public let maxRetries: Int
    public let delay: TimeInterval

    public init(maxRetries: Int = 3, delay: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.delay = delay
    }

    public func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        ErrorClassifier().classify(error).isRetryable
    }

    public func delayForAttempt(_ attempt: Int) -> TimeInterval {
        delay * Double(attempt)
    }
}

public struct ImmediateRetryPolicy: RetryPolicy {
    public let maxRetries: Int

    public init(maxRetries: Int = 3) {
        self.maxRetries = maxRetries
    }

    public func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        ErrorClassifier().classify(error).isRetryable
    }

    public func delayForAttempt(_ attempt: Int) -> TimeInterval {
        0
    }
}

// MARK: - Error Classification

struct ErrorClassifier {
    func classify(_ error: Error) -> ErrorClassification {
        // Classify AppError
        if let appError = error as? AppError {
            return classifyAppError(appError)
        }

        // Classify as NSError (all Swift errors can be bridged to NSError)
        let nsError = error as NSError
        return classifyNSError(nsError)
    }

    private func classifyAppError(_ error: AppError) -> ErrorClassification {
        switch error {
        // Network errors - retryable
        case .connectionTimeout, .networkUnavailable, .requestFailed:
            return ErrorClassification(
                isRetryable: true,
                severity: .medium,
                category: .network
            )

        // Proxy errors - some retryable
        case .proxyConnectionFailed, .proxyServerUnreachable:
            return ErrorClassification(
                isRetryable: true,
                severity: .high,
                category: .proxy
            )

        case .proxyNotAuthorized, .proxyConfigurationInvalid, .proxyAuthenticationFailed:
            return ErrorClassification(
                isRetryable: false,
                severity: .critical,
                category: .proxy
            )

        // SSL errors - not retryable
        case .sslError:
            return ErrorClassification(
                isRetryable: false,
                severity: .high,
                category: .ssl
            )

        // Storage errors - not retryable
        case .storageReadFailed, .storageWriteFailed, .storageCorrupted:
            return ErrorClassification(
                isRetryable: false,
                severity: .high,
                category: .storage
            )

        default:
            return ErrorClassification(
                isRetryable: false,
                severity: .medium,
                category: .unknown
            )
        }
    }

    private func classifyNSError(_ error: NSError) -> ErrorClassification {
        switch error.domain {
        case NSURLErrorDomain:
            return classifyURLError(error)

        case NSPOSIXErrorDomain:
            return classifyPOSIXError(error)

        default:
            return ErrorClassification(
                isRetryable: false,
                severity: .medium,
                category: .unknown
            )
        }
    }

    private func classifyURLError(_ error: NSError) -> ErrorClassification {
        let retryableCodes: Set<Int> = [
            NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorInternationalRoamingOff,
            NSURLErrorCallIsActive,
            NSURLErrorDataNotAllowed
        ]

        return ErrorClassification(
            isRetryable: retryableCodes.contains(error.code),
            severity: .medium,
            category: .network
        )
    }

    private func classifyPOSIXError(_ error: NSError) -> ErrorClassification {
        let retryableCodes: Set<Int> = [
            Int(ETIMEDOUT),
            Int(ECONNREFUSED),
            Int(EHOSTUNREACH),
            Int(ENETUNREACH)
        ]

        return ErrorClassification(
            isRetryable: retryableCodes.contains(error.code),
            severity: .medium,
            category: .network
        )
    }
}

// MARK: - Error Classification Types

struct ErrorClassification {
    let isRetryable: Bool
    let severity: ErrorSeverity
    let category: ErrorCategory
}

enum ErrorCategory {
    case network
    case proxy
    case ssl
    case storage
    case authentication
    case unknown
}

// MARK: - Circuit Breaker

actor CircuitBreaker {
    enum State {
        case closed  // Normal operation
        case open    // Failing, reject requests
        case halfOpen // Testing if service recovered
    }

    private var state: State = .closed
    private let failureThreshold: Int
    private let resetTimeout: TimeInterval
    private var failureCount: Int = 0
    private var lastFailureTime: Date?
    private var successCount: Int = 0

    init(failureThreshold: Int, resetTimeout: TimeInterval) {
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
    }

    func allowRequest() -> Bool {
        switch state {
        case .closed:
            return true

        case .open:
            // Check if we should transition to half-open
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) >= resetTimeout {
                state = .halfOpen
                return true
            }
            return false

        case .halfOpen:
            return true
        }
    }

    func recordSuccess() {
        switch state {
        case .halfOpen:
            successCount += 1
            if successCount >= 2 {
                // Service recovered, close circuit
                state = .closed
                failureCount = 0
                successCount = 0
            }

        case .open:
            break

        case .closed:
            failureCount = 0
        }
    }

    func recordFailure() {
        lastFailureTime = Date()
        successCount = 0

        switch state {
        case .halfOpen:
            // Failed while testing, back to open
            state = .open

        case .closed:
            failureCount += 1
            if failureCount >= failureThreshold {
                state = .open
            }

        case .open:
            break
        }
    }

    func reset() {
        state = .closed
        failureCount = 0
        successCount = 0
        lastFailureTime = nil
    }

    func getState() -> CircuitBreakerState {
        CircuitBreakerState(
            state: state,
            failureCount: failureCount,
            successCount: successCount,
            lastFailureTime: lastFailureTime
        )
    }
}

// MARK: - Circuit Breaker State

public struct CircuitBreakerState {
    let state: CircuitBreaker.State
    let failureCount: Int
    let successCount: Int
    let lastFailureTime: Date?

    public var isOpen: Bool {
        if case .open = state { return true }
        return false
    }

    public var isClosed: Bool {
        if case .closed = state { return true }
        return false
    }
}

// MARK: - Retry Statistics

public struct RetryStatistics: Codable {
    public var totalRetries: Int = 0
    public var successfulRetries: Int = 0
    public var failedRetries: Int = 0
    public var nonRetryableErrors: Int = 0
    public var totalSuccesses: Int = 0

    public var retryRate: Double {
        let total = totalSuccesses + failedRetries
        guard total > 0 else { return 0 }
        return Double(totalRetries) / Double(total)
    }

    public var successRate: Double {
        let totalAttempts = successfulRetries + failedRetries
        guard totalAttempts > 0 else { return 0 }
        return Double(successfulRetries) / Double(totalAttempts)
    }
}
