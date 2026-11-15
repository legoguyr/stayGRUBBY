import Foundation
import Testing
import Supabase
@testable import StayGrubby

/// Bounded, jittered retries and server cooldowns (November 15, 2026).
struct SyncRetryPolicyTests {
    @Test func backoffIsExponentialJitteredAndCapped() {
        #expect(SyncRetryPolicy.backoff(attempt: 1, jitter: 1) == 2)
        #expect(SyncRetryPolicy.backoff(attempt: 4, jitter: 1) == 16)
        #expect(SyncRetryPolicy.backoff(attempt: 40, jitter: 1.2) == SyncRetryPolicy.maximumBackoff)
        let spread = Set((0..<20).map { _ in SyncRetryPolicy.backoff(attempt: 5) })
        #expect(spread.count > 1 && spread.allSatisfy { (25.6...38.4).contains($0) })
    }

    @Test func postgrestThrottleHonorsHintSecondsAndOtherErrorsAreNotCooldowns() {
        #expect(SyncRetryPolicy.cooldown(from: PostgrestError(hint: "retry after 90 seconds", code: "PT429", message: "busy")) == 90)
        #expect(SyncRetryPolicy.cooldown(from: PostgrestError(code: "PT503", message: "maintenance")) == SyncRetryPolicy.defaultCooldown)
        #expect(SyncRetryPolicy.cooldown(from: PostgrestError(hint: "99999", code: "PT429", message: "x")) == SyncRetryPolicy.maximumCooldown)
        #expect(SyncRetryPolicy.cooldown(from: PostgrestError(code: "PT409", message: "conflict")) == nil)
        #expect(SyncRetryPolicy.cooldown(from: PostgrestError(code: "42501", message: "denied")) == nil)
        #expect(SyncRetryPolicy.cooldown(from: URLError(.notConnectedToInternet)) == nil)
        #expect(SyncRetryPolicy.cooldown(from: CookingPhotoError.cooldown(45)) == 45)
    }

    @Test func gatewayRetryAfterHeaderSecondsAndHTTPDate() throws {
        let url = try #require(URL(string: "https://example.invalid/rest/v1/rpc/apply_cooking_operation"))
        let seconds = try #require(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "75"]))
        #expect(SyncRetryPolicy.cooldown(from: HTTPError(data: Data(), response: seconds)) == 75)
        let none = try #require(HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil))
        #expect(SyncRetryPolicy.cooldown(from: HTTPError(data: Data(), response: none)) == SyncRetryPolicy.defaultCooldown)
        let server = try #require(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: ["Retry-After": "75"]))
        #expect(SyncRetryPolicy.cooldown(from: HTTPError(data: Data(), response: server)) == nil)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(SyncRetryPolicy.retryAfter("Fri, 15 Jan 2027 08:01:40 GMT", now: now).map { $0 > 0 } == true)
        #expect(SyncRetryPolicy.retryAfter("soon") == nil)
    }

    @Test func nextAttemptNeverShortensAServerCooldown() {
        let now = Date(timeIntervalSince1970: 0)
        let throttled = SyncRetryPolicy.nextAttempt(after: PostgrestError(hint: "600", code: "PT429", message: "x"), attempt: 1, now: now, jitter: 1)
        #expect(throttled.timeIntervalSince(now) == 600)
        let offline = SyncRetryPolicy.nextAttempt(after: URLError(.timedOut), attempt: 3, now: now, jitter: 1)
        #expect(offline.timeIntervalSince(now) == 8)
    }

    @Test func onlyRegainedConnectivityTriggersASync() {
        let path = ReachabilityTransitions()
        #expect(!path.restored(true))   // first report while online
        #expect(!path.restored(true))   // route/interface change while online
        #expect(!path.restored(false))  // went offline
        #expect(path.restored(true))    // back online
        #expect(!path.restored(true))
    }

    @MainActor @Test func socialCleanupWriteRunsRoutinelyAtMostEveryTenMinutesButAlwaysAfterRetirement() async {
        final class Calls { var cleanup = 0 }
        let calls = Calls()
        let request: SocialRequest = { _, action, _ in
            if action == "cleanup" { calls.cleanup += 1 }
            return Data(#"{"paths":[]}"#.utf8)
        }
        let media: SocialMediaRequest = { _ in Data() }
        let start = Date(timeIntervalSince1970: 4_000_000_000)
        await SocialPhotoCleanup.run(request: request, media: media, now: start)
        await SocialPhotoCleanup.run(request: request, media: media, now: start.addingTimeInterval(60))
        #expect(calls.cleanup == 1, "A 30 s poll must not repeat the cleanup write")
        await SocialPhotoCleanup.run(request: request, media: media, afterRetirement: true, now: start.addingTimeInterval(90))
        #expect(calls.cleanup == 2, "Deleting/cancelling a post cleans its photo immediately")
        await SocialPhotoCleanup.run(request: request, media: media, now: start.addingTimeInterval(90 + SocialPhotoCleanup.routineInterval))
        #expect(calls.cleanup == 3)
    }
}
