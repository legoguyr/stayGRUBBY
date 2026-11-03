import Foundation
import Testing
@testable import StayGrubby

@MainActor private final class ActivityResponseState { var count = 0; var calls = 0; var offline = false }

@MainActor struct SocialActivityTests {
    @Test func remoteActivityUpdatesOneSharedUnreadCountWithoutLocalMutation() async throws {
        let coordinator = SocialActivityCoordinator(); let state = ActivityResponseState()
        let token = coordinator.connect { endpoint, action, _ in
            #expect(endpoint == "social_notifications" && action == "page"); state.calls += 1
            return try JSONEncoder().encode(SocialNotificationsPage(notifications: [], unread: state.count))
        }
        await coordinator.refresh(); #expect(coordinator.unread == 0)
        state.count = 2; await coordinator.refresh(); #expect(coordinator.unread == 2 && state.calls == 2)
        state.count = 0; await coordinator.refresh(); #expect(coordinator.unread == 0)
        coordinator.disconnect(token); #expect(coordinator.unread == 0)
    }
    @Test func earlierAccountResponseCannotPopulateNextAccount() async throws {
        let coordinator = SocialActivityCoordinator()
        var continuation: CheckedContinuation<Data, Never>?
        let old = coordinator.connect { _,_,_ in await withCheckedContinuation { continuation = $0 } }
        let task = Task { await coordinator.refresh() }; await Task.yield()
        while continuation == nil { await Task.yield() }
        let next = coordinator.connect { _,_,_ in try JSONEncoder().encode(SocialNotificationsPage(notifications: [], unread: 1)) }
        coordinator.disconnect(old)
        continuation?.resume(returning: try JSONEncoder().encode(SocialNotificationsPage(notifications: [], unread: 99)))
        await task.value; #expect(coordinator.unread == 0)
        await coordinator.refresh(); #expect(coordinator.unread == 1)
        coordinator.disconnect(next)
        coordinator.acceptUnread(99); #expect(coordinator.unread == 0)
    }
    @Test func failuresClearStaleCountsAndNormalRefreshRecovers() async throws {
        let coordinator = SocialActivityCoordinator(); let state = ActivityResponseState()
        _ = coordinator.connect { _,_,_ in
            if state.offline { throw URLError(.notConnectedToInternet) }
            return try JSONEncoder().encode(SocialNotificationsPage(notifications: [], unread: 3))
        }
        await coordinator.refresh(); #expect(coordinator.unread == 3)
        state.offline = true; await coordinator.refresh(); #expect(coordinator.failed && coordinator.unread == 0)
        state.offline = false; await coordinator.refresh(); #expect(!coordinator.failed && coordinator.unread == 3)
    }
    @Test func latePollCannotRestoreUnreadBadgeAfterSuccessfulReadAll() async throws {
        let coordinator = SocialActivityCoordinator()
        var continuation: CheckedContinuation<Data, Never>?
        _ = coordinator.connect { _,_,_ in await withCheckedContinuation { continuation = $0 } }
        let poll = Task { await coordinator.refresh() }
        while continuation == nil { await Task.yield() }
        coordinator.acceptUnread(0)
        continuation?.resume(returning: try JSONEncoder().encode(SocialNotificationsPage(notifications: [], unread: 6)))
        await poll.value
        #expect(coordinator.unread == 0 && !coordinator.failed && !coordinator.refreshing)
    }

}
