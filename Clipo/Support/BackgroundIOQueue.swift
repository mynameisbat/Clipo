import Foundation

actor BackgroundIOQueue {
    private let queue = DispatchQueue(
        label: "com.bat.clipo.io",
        qos: .utility,
        attributes: .concurrent
    )

    /// Execute a single I/O operation on background queue
    /// - Parameter operation: Throwing closure to execute
    /// - Returns: Result of the operation
    func execute<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Execute multiple I/O operations in parallel
    /// - Parameter operations: Array of throwing closures to execute
    /// - Returns: Array of results in original order
    func executeBatch<T: Sendable>(_ operations: [@Sendable () throws -> T]) async throws -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for (index, operation) in operations.enumerated() {
                group.addTask {
                    let result = try await self.execute(operation)
                    return (index, result)
                }
            }

            var results: [(Int, T)] = []
            for try await result in group {
                results.append(result)
            }

            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    /// Execute operation with timeout
    /// - Parameters:
    ///   - timeout: Maximum time to wait in seconds
    ///   - operation: Throwing closure to execute
    /// - Returns: Result of the operation
    /// - Throws: TimeoutError if operation exceeds timeout
    func executeWithTimeout<T: Sendable>(
        timeout: TimeInterval,
        operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await self.execute(operation)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }

            guard let result = try await group.next() else {
                throw TimeoutError()
            }

            group.cancelAll()
            return result
        }
    }

    /// Execute operation with retry logic
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts
    ///   - delay: Delay between retries in seconds
    ///   - operation: Throwing closure to execute
    /// - Returns: Result of the operation
    func executeWithRetry<T: Sendable>(
        maxRetries: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                return try await execute(operation)
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? IOError.unknownError
    }
}

// MARK: - Errors

enum IOError: Error {
    case unknownError
}

struct TimeoutError: Error {}
