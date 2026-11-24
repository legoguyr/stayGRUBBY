import Foundation
import Testing
@testable import StayGrubby

/// Build 6 regression: `recipe_library` was missing from the device-only endpoint allowlist, so Unlink
/// from Dish and Recently Deleted failed on iPhone before any request while every fixture passed.
@MainActor struct SocialEndpointAllowlistTests {
    @Test func recipeRecoveryEndpointIsAllowed() {
        #expect(SupabaseAccountBackend.socialEndpoints.contains("recipe_library"))
    }

    /// Every endpoint literal the app sends through `SocialRequest` must be on the allowlist.
    @Test func everyEndpointTheAppCallsIsAllowed() throws {
        let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("StayGrubby")
        let files = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        let pattern = try NSRegularExpression(pattern: #"request!?\("([a-z_]+)", ""#)
        var used = Set<String>()
        for case let url as URL in files where url.pathExtension == "swift" && !url.path.contains("SocialReview") {
            let text = try String(contentsOf: url, encoding: .utf8)
            for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text) { used.insert(String(text[range])) }
            }
        }
        #expect(used.contains("recipe_library"))
        #expect(used.count >= 10)
        #expect(used.subtracting(SupabaseAccountBackend.socialEndpoints).isEmpty, "Not allowlisted: \(used.subtracting(SupabaseAccountBackend.socialEndpoints).sorted())")
    }
}
