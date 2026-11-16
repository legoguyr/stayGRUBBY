import Foundation
import Supabase

/// One retry policy for structured sync, photo backup and library refresh (November 15, 2026).
/// - Automatic retries back off exponentially with jitter, capped at five minutes, so a failing
///   request can never become a storm (the November 11 incident) and many devices don't retry in step.
/// - A server cooldown (HTTP 429/503 with `Retry-After`, or PostgREST `PT429`/`PT503` with the delay in
///   seconds in the error hint) is honored as a recoverable pause, never a permanent rejection.
/// - After `automaticAttemptLimit` consecutive failures automatic timers stop; local work stays queued
///   and resumes on connectivity recovery, returning to the foreground, a new local change or Retry.
nonisolated enum SyncRetryPolicy {
    static let maximumBackoff: TimeInterval = 300
    static let defaultCooldown: TimeInterval = 30
    static let maximumCooldown: TimeInterval = 3_600
    static let automaticAttemptLimit = 8

    /// Exponential backoff for the given (1-based) attempt, with ±20% jitter.
    static func backoff(attempt: Int, jitter: Double = .random(in: 0.8...1.2)) -> TimeInterval {
        let base = min(maximumBackoff, pow(2, Double(min(max(attempt, 1), 9))))
        return min(maximumBackoff, base * jitter)
    }

    /// When the next automatic attempt may run after `error`.
    static func nextAttempt(after error: Error, attempt: Int, now: Date = .now,
                            jitter: Double = .random(in: 0.8...1.2)) -> Date {
        let delay = backoff(attempt: attempt, jitter: jitter)
        return now.addingTimeInterval(cooldown(from: error).map { max($0, delay) } ?? delay)
    }

    /// The server-requested pause in seconds when `error` is a cooldown/throttle response, else nil.
    static func cooldown(from error: Error) -> TimeInterval? {
        if let error = error as? CookingPhotoError, case .cooldown(let seconds) = error { return seconds }
        if let error = error as? PostgrestError, let code = error.code, ["PT429", "PT503"].contains(code) {
            return clamp(seconds(in: error.hint) ?? seconds(in: error.detail) ?? defaultCooldown)
        }
        if let error = error as? HTTPError, [429, 503].contains(error.response.statusCode) {
            return clamp(retryAfter(error.response.value(forHTTPHeaderField: "Retry-After")) ?? defaultCooldown)
        }
        if let error = error as? StorageError, let status = error.statusCode, ["429", "503"].contains(status) {
            return defaultCooldown
        }
        return nil
    }

    /// `Retry-After` is delta-seconds or an HTTP date (RFC 9110 §10.2.3).
    static func retryAfter(_ value: String?, now: Date = .now) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let seconds = TimeInterval(value), seconds >= 0 { return seconds }
        let format = DateFormatter(); format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = TimeZone(identifier: "GMT"); format.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return format.date(from: value).map { max(0, $0.timeIntervalSince(now)) }
    }

    private static func seconds(in text: String?) -> TimeInterval? {
        guard let text, let match = text.range(of: #"\d+"#, options: .regularExpression) else { return nil }
        return TimeInterval(text[match])
    }
    private static func clamp(_ value: TimeInterval) -> TimeInterval { min(maximumCooldown, max(1, value)) }
}
