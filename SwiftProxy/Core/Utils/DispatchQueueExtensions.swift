import Foundation

// MARK: - DispatchQueue Async Extensions
// Unified extensions for all services to avoid conflicts

extension DispatchQueue {
    /// Execute async throwing work on queue and return result
    /// Use this method when your closure contains throwing operations (try/throw)
    func syncThrowing<T>(_ work: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
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

    /// Execute non-throwing work on queue and return result
    /// Use this method when your closure does not throw
    func sync<T>(_ work: @escaping () -> T) async -> T {
        return await withCheckedContinuation { continuation in
            self.async {
                let result = work()
                continuation.resume(returning: result)
            }
        }
    }
}
