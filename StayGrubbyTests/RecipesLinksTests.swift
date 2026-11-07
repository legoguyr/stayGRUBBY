import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct RecipesLinksTests {
    @Test func routesAreExactAndDoNotAcceptPrivateObjectsOrRedirects() throws {
        let good = try #require(URL(string: "https://staygrubby.com/@friendly_cook"))
        #expect(AppRoute(url: good) == .profile("friendly_cook"))
        #expect(AppRoute(url: URL(string: "https://staygrubby.com/%40friendly_cook")!) == .profile("friendly_cook"))
        for value in ["http://staygrubby.com/@friendly_cook", "https://staygrubby.com.evil/@friendly_cook", "https://evil@staygrubby.com/@friendly_cook", "https://staygrubby.com:443/@friendly_cook", "https://staygrubby.com/@friendly_cook?next=private", "https://staygrubby.com/@friendly_cook#private", "https://staygrubby.com/@Friendly_Cook", "https://staygrubby.com/@ab", "https://staygrubby.com/@friendly_cook/private", "https://staygrubby.com/recipe/secret"] {
            #expect(AppRoute(url: try #require(URL(string: value))) == .invalid)
        }
        #expect(AppRoute.profileURL(username: "friendly_cook") == good)
        #expect(AppRoute.profileURL(username: "../private") == nil)
    }
    @Test func referralIsOptionalBoundedAndIndependentOfDestination() throws {
        let id = UUID(), token = "abcde_01234567890"
        let url = AppRoute.recipeURL(id, referral: token)
        #expect(AppRoute(url: url) == .recipe(id))
        #expect(AppRoute.referral(from: url) == token)
        let base = AppRoute.recipeURL(id)
        for suffix in ["?ref=bad", "?ref=%22%3E", "?ref=\(token)&ref=\(token)"] {
            let malformed = try #require(URL(string: base.absoluteString + suffix))
            #expect(AppRoute(url: malformed) == .recipe(id))
            #expect(AppRoute.referral(from: malformed) == nil)
        }
        let router = AppLinkRouter()
        router.receive(url)
        #expect(router.pending == .recipe(id) && router.pendingReferral == token)
        router.receive(base)
        #expect(router.pending == .recipe(id) && router.pendingReferral == nil)
    }
    @Test func sharedDestinationsRoundTripThroughHTTPSAndExplicitAppOpen() throws {
        let id = UUID()
        let cases: [(URL, AppRoute)] = [(AppRoute.postURL(id), .post(id)), (AppRoute.recipeURL(id), .recipe(id)), (AppRoute.sharedRecipeURL(postID: id), .sharedRecipe(id))]
        for (url, route) in cases {
            #expect(AppRoute(url: url) == route)
            #expect(AppRoute(url: URL(string: "staygrubby://open" + url.path)!) == route)
            #expect(!url.absoluteString.contains("token"))
            #expect(AppRoute(url: URL(string: url.absoluteString + "?redirect=private")!) == .invalid)
            #expect(AppRoute(url: URL(string: url.absoluteString + "/extra")!) == .invalid)
        }
        for path in ["/dish/", "/cook/", "/ranking/", "/signature-dishes/"] {
            #expect(AppRoute(url: URL(string: "https://staygrubby.com" + path + id.uuidString)!) == .invalid)
        }
        #expect(AppRoute(url: URL(string: "staygrubby://evil/@friendly_cook")!) == .invalid)
        let router = AppLinkRouter()
        router.receive(AppRoute.sharedRecipeURL(postID: id))
        #expect(router.pending == .sharedRecipe(id))
        router.openOwnKitchen()
        #expect(router.pending == nil && router.ownKitchenRequests == 1)
    }
    @Test func routerRetainsOnlyDestinationUntilAuthenticationReady() {
        let router = AppLinkRouter()
        router.receive(URL(string: "https://staygrubby.com/@first_cook")!)
        #expect(router.pending == .profile("first_cook"))
        router.receive(URL(string: "https://staygrubby.com/@second_cook")!)
        #expect(router.pending == .profile("second_cook"))
        router.pending = nil; #expect(router.pending == nil)
    }
    @Test func recipePrefillHasNoPrivateCookingFields() throws {
        let snapshot = RecipeContent(title: "Lemon soup", ingredients: ["Lemon"], steps: ["Simmer"], course: "soup", cuisine: "Italian", source: "Recipe author", externalURL: "https://example.com/soup")
        let claim = SocialCookingClaim(id: UUID(), itemID: UUID(), kind: "recipe", completed: false, metadata: .init(title: snapshot.title, course: snapshot.course), recipeOriginID: UUID(), recipeSnapshot: snapshot)
        let draft = claim.draft()
        #expect(draft.dishName == "Lemon soup" && draft.category == .soup && draft.cuisine?.id == "italian")
        #expect(draft.source?.onlineWebsite == "Recipe author" && draft.source?.onlineURL == "https://example.com/soup")
        #expect(draft.notes.isEmpty && draft.dietary.isEmpty && draft.contains.isEmpty && draft.allergy.isEmpty && !draft.hasPhoto)
    }
    @Test func recipeIntentSurvivesRelaunchAndNeverCreatesCookingUntilExistingSave() async throws {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext, list = try CookingStore.prepare(context: context)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), owner = UUID(), item = UUID(), claim = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        var calls = 0
        let request: SocialRequest = { endpoint, action, payload in
            #expect(endpoint == "recipes" && action == "complete" && payload.originID == claim)
            calls += 1; return Data("{}".utf8)
        }
        let worker = SharedCookingCoordinator(); worker.connect(context: context, root: root, owner: owner, request: request, sync: nil)
        let before = try CookingGraphExport.snapshot(context: context)
        try worker.record(itemID: item, participants: [], originID: nil, recipeOriginID: claim)
        await worker.retryNow(); #expect(calls == 0 && list.items.isEmpty)
        #expect(try CookingGraphExport.snapshot(context: context) == before)
        worker.disconnect()
        var draft = CookingDraft(); draft.dishName = "My recipe cook"
        _ = try CookingStore.create(draft: draft, session: RankingEngine(itemID: item, orderedIDs: [], reaction: .fine), context: context)
        let saved = try CookingGraphExport.snapshot(context: context)
        worker.connect(context: context, root: root, owner: owner, request: request, sync: nil)
        await worker.retryNow(); await worker.retryNow()
        #expect(calls == 1 && worker.intents.isEmpty && list.items.count == 1 && list.comparisons.isEmpty)
        #expect(try CookingGraphExport.snapshot(context: context) == saved)
        worker.disconnect()
    }
    @Test func legacySocialClaimDecodesWithoutRecipe() throws {
        let bytes = Data("{\"id\":\"\(UUID())\",\"itemID\":\"\(UUID())\",\"kind\":\"recreated\",\"completed\":false,\"metadata\":{\"title\":\"Legacy soup\"}}".utf8)
        let claim = try JSONDecoder().decode(SocialCookingClaim.self, from: bytes)
        #expect(claim.recipeOriginID == nil && claim.recipeSnapshot == nil && claim.draft().dishName == "Legacy soup")
    }
    @Test func rankMyVersionUsesExistingPinnedRecipeReservation() async throws {
        let recipeID = UUID(), reservation = UUID(), itemID = UUID()
        let snapshot = RecipeContent(title:"My recipe",ingredients:["400 g Arborio rice"],steps:["Cook as written."],source:"Original author")
        var requests = 0
        let request: SocialRequest = { endpoint, action, payload in
            #expect(endpoint == "recipes" && action == "begin" && payload.recipeID == recipeID && payload.originID == reservation)
            requests += 1
            return try JSONEncoder().encode(SocialCookingClaim(id:reservation,itemID:itemID,kind:"recipe",completed:false,metadata:.init(title:snapshot.title),recipeOriginID:reservation,recipeSnapshot:snapshot))
        }
        let claim = try await RecipeService.begin(id:recipeID,reservation:reservation,request:request)
        #expect(requests == 1 && claim.itemID == itemID && claim.recipeOriginID == reservation && claim.recipeSnapshot == snapshot)
        #expect(claim.draft().dishName == snapshot.title && claim.draft().notes.isEmpty)
    }

}
