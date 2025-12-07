import Foundation

// MARK: - DispatchQueue Async Extensions
// Unified extensions for all services to avoid conflicts

extension DispatchQueue {
    /// Execute async throwing work on queue and return result
    /// Use this method when your closure contains throwing operations (try/throw)
    func syncThrowing<T>(_ work: @escaping () async throws -> T) async throws -> T {
        return try await work()
    }

    /// Execute async non-throwing work on queue and return result
    /// Use this method when your closure does not throw
    func sync<T>(_ work: @escaping () async -> T) async -> T {
        return await work()
    }

    /// Execute async work on queue and return result, swallowing any errors
    /// Use this method when you want to ignore errors
    func syncIgnoringErrors<T>(_ work: @escaping () async throws -> T) async -> T? {
        return try? await work()
    }
}
