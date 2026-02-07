import Foundation

/// Exponential backoff retry policy for GET requests.
public struct RetryPolicy: Sendable {
    /// Maximum number of retry attempts.
    public let maxAttempts: Int

    /// Base delay in seconds before the first retry.
    public let baseDelay: TimeInterval

    /// Maximum delay in seconds between retries.
    public let maxDelay: TimeInterval

    public init(maxAttempts: Int = 3, baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 8.0) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    /// Calculates the delay before retry attempt `attempt` (0-indexed).
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let delay = baseDelay * pow(2.0, Double(attempt))
        return min(delay, maxDelay)
    }
}
