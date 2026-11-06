import Foundation
import Testing
@testable import StayGrubby

@MainActor struct V1FinalUXTests {
    func person(_ name: String, relationship: SocialRelationship = .friends) -> SocialPerson {
        .init(id: UUID(), displayName: name, username: name.lowercased(), relationship: relationship)
    }
    @Test func multiRecipientRetryUsesStableKeysAndDoesNotResendSuccesses() async throws {
        let a = person("A"), b = person("B"), blocked = person("Blocked", relationship: .blocked)
        let batch = SocialSendBatch(), content = SocialSendContent.recipe(UUID())
        batch.toggle(a); batch.toggle(b); batch.toggle(blocked)
        #expect(batch.selected.count == 2)
        var calls: [UUID: [UUID]] = [:], deliveredOnServer = Set<UUID>(), firstB = true
        let request: SocialRequest = { area, action, payload in
            #expect(area == "social_send" && action == "send" && payload.targetID == content.target)
            let peer = try #require(payload.peerID), origin = try #require(payload.originID)
            calls[peer, default: []].append(origin); deliveredOnServer.insert(origin)
            if peer == b.id && firstB { firstB = false; throw URLError(.networkConnectionLost) }
            return Data("{\"sent\":true}".utf8)
        }
        await batch.send(content: content, request: request)
        #expect(batch.delivered == [a.id] && batch.failed == [b.id] && !batch.complete)
        await batch.send(content: content, request: request)
        #expect(batch.complete && batch.delivered == [a.id, b.id] && batch.failed.isEmpty)
        #expect(calls[a.id]?.count == 1 && calls[b.id]?.count == 2)
        #expect(Set(calls[b.id] ?? []).count == 1 && deliveredOnServer.count == 2)
        await batch.send(content: content, request: request)
        #expect(calls[a.id]?.count == 1 && calls[b.id]?.count == 2)
    }
    @Test func failedEligibilityDoesNotGrantAccessAndBackgroundRetryKeepsOrigin() async throws {
        let a = person("A"), batch = SocialSendBatch(), content = SocialSendContent.post(UUID())
        batch.toggle(a)
        var origins: [UUID] = []
        await batch.send(content: content) { _, _, payload in
            origins.append(try #require(payload.originID)); return Data("{\"sent\":false}".utf8)
        }
        #expect(batch.delivered.isEmpty && batch.failed == [a.id])
        batch.suspend(); #expect(batch.selected.isEmpty)
        batch.toggle(a)
        await batch.send(content: content) { _, _, payload in
            origins.append(try #require(payload.originID)); return Data("{\"sent\":true}".utf8)
        }
        #expect(Set(origins).count == 1 && batch.complete)
    }
    @Test func rankingRequiresNameKnownDateAndValidTextButNotOptionalMetadata() {
        var draft = CookingDraft()
        #expect(!draft.validForRanking)
        draft.dishName = "  Dinner  "
        #expect(draft.validForRanking && draft.category == .main && !draft.hasPhoto && draft.cleanTitle == nil)
        draft.cookedAt = nil; #expect(!draft.validForRanking)
        draft.cookedAt = .now; draft.privateNotes = String(repeating: "x", count: 8_001)
        #expect(!draft.validForRanking)
    }
    @Test func kitchenIndexSearchIncludesAllAuthorizedPagesAndReusesLiteralSearch() async throws {
        var calls = 0
        let owner = UUID(), match = UUID()
        let entries = (0..<26).map { n in
            CookbookEntry(dishID: nil, recipeID: n == 25 ? match : UUID(), dishTitle: "", recipeTitle: n == 25 ? "Crème Soup" : "Dish \(n)", course: nil, cuisine: "French", revision: 1)
        }
        let loaded = try await CookbookIndex.profile(request: { area, action, payload in
            #expect(area == "recipes" && action == "profile_index" && payload.peerID == owner)
            calls += 1
            let slice = calls == 1 ? Array(entries.prefix(25)) : Array(entries.suffix(1))
            return try JSONEncoder().encode(CookbookPage(entries: slice))
        }, personID: owner)
        #expect(calls == 2 && loaded.count == 26)
        #expect(loaded.filter { CookbookSearch.matches($0.searchableText, query: "creme french") }.map(\.id) == [match])
        #expect(!loaded.contains { CookbookSearch.matches($0.searchableText, query: "nonexistent") })
    }
}
