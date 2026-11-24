import Foundation
import Testing
import Supabase
@testable import StayGrubby

/// Staff moderation client (PUBLIC_MVP_MODERATION.md): contracts with `api.staff_status` and
/// `api.moderation_review`. Synthetic data only; the server enforces every permission.
@MainActor struct ModerationTests {
    @Test func staffEndpointsAreAllowed() {
        #expect(SupabaseAccountBackend.socialEndpoints.isSuperset(of: ["staff_status", "moderation_review"]))
    }

    @Test func roleIsNilForNonStaffAndErrors() async {
        #expect(await ModerationService.role { _, _, _ in Data(#"{"role":"admin"}"#.utf8) } == .admin)
        #expect(await ModerationService.role { _, _, _ in Data(#"{"role":"moderator"}"#.utf8) } == .moderator)
        #expect(await ModerationService.role { _, _, _ in Data(#"{"role":null}"#.utf8) } == nil)
        #expect(await ModerationService.role { _, _, _ in Data(#"{"role":"owner"}"#.utf8) } == nil, "Unknown roles never show staff tools")
        #expect(await ModerationService.role { _, _, _ in throw URLError(.notConnectedToInternet) } == nil)
    }

    @Test func queueCursorSendsTheServerTimestampUnchanged() async throws {
        let last = ModerationReport(id: UUID(), kind: "post", reason: "spam", createdAt: "2026-11-23T12:00:00.123456+00:00", status: "pending")
        var sent: (String, String, SocialPayload)?
        let page = try await ModerationService.queue(after: last) { endpoint, action, payload in
            sent = (endpoint, action, payload); return Data(#"{"reports":[]}"#.utf8)
        }
        #expect(page.isEmpty)
        #expect(sent?.0 == "moderation_review" && sent?.1 == "queue")
        #expect(sent?.2.afterID == last.id && sent?.2.afterTime == last.createdAt)
        let first = try JSONSerialization.jsonObject(with: JSONEncoder().encode(SocialPayload())) as? [String: Any]
        #expect(first?.isEmpty == true, "The first page sends no cursor")
    }

    @Test func resolveSendsOnlyTheReportAndDecision() async throws {
        let id = UUID(); var sent: SocialPayload?
        try await ModerationService.resolve(id, .hide) { _, action, payload in
            #expect(action == "resolve"); sent = payload; return Data("{}".utf8)
        }
        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(sent)) as? [String: String])
        #expect(json == ["reportID": id.uuidString, "decision": "hide"])
    }

    @Test func decodesEverySubjectKindAndDeletedContent() throws {
        func detail(_ subject: String) throws -> ModerationReportDetail {
            try JSONDecoder().decode(ModerationReportDetail.self, from: Data("""
            {"id":"\(UUID().uuidString)","kind":"recipe","reason":"spam","context":null,"status":"pending",
             "createdAt":"2026-11-23T12:00:00+00:00","decision":null,"resolvedAt":null,"subject":\(subject)}
            """.utf8))
        }
        #expect(try detail("null").subject == nil)
        let recipe = try detail(#"{"content":{"title":"Soup","ingredients":["1 cup stock"],"steps":["Simmer"]},"revision":2,"state":"active","photoPath":"a/b.jpg"}"#)
        #expect(recipe.subject?.content?.title == "Soup" && recipe.subject?.photoPath == "a/b.jpg")
        #expect(try detail(#"{"body":"Rude","state":"hidden"}"#).subject?.state == "hidden")
        #expect(try detail(#"{"displayName":"Cook","username":"cook","state":"active","photoPath":null}"#).subject?.username == "cook")
    }

    @Test func messagesAndLabels() {
        #expect(ModerationService.isAlreadyHandled(PostgrestError(code: "PT409", message: "x")))
        #expect(!ModerationService.isAlreadyHandled(URLError(.timedOut)))
        #expect(ModerationService.message(for: PostgrestError(code: "42501", message: "x")).contains("staff access"))
        #expect(ModerationService.reasonTitle("harassment") == "Harassment or bullying")
        #expect(ModerationService.kindTitle("recipe") == "Recipe")
        #expect(ModerationService.date("2026-11-23T12:00:00.123456+00:00") != nil)
        #expect(ModerationService.date("2026-11-23T12:00:00+00:00") != nil)
    }
}
