import Foundation

// MARK: - DispatchQueue Async Extensions

/// Unified DispatchQueue extensions for async/await bridge
/// These extensions allow running synchronous code on a specific queue from async contexts
extension DispatchQueue {

    /// Execute synchronous throwing work on queue and return result
    /// Use this method when your closure contains throwing operations (try/throw)
    func sync<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.async {
                do {
                    let result = try work()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Execute async work on queue and return result
    /// Use this method when your closure contains async operations (await)
    func sync<T>(_ work: @escaping () async -> T) async -> T {
        await withCheckedContinuation { continuation in
            self.async {
                Task {
                    let result = await work()
                    continuation.resume(returning: result)
                }
            }
        }
    }

    /// Execute async throwing work on queue and return result
    /// Use this method when your closure contains both async and throwing operations
    func sync<T>(_ work: @escaping () async throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.async {
                Task {
                    do {
                        let result = try await work()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
