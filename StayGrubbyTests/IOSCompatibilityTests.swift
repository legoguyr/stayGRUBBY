import Foundation
import Testing
@testable import StayGrubby

struct IOSCompatibilityTests {
    @Test func legacyWireDecodeDoesNotClaimSupportOrRewriteItsPayload() throws {
        let original = Data(#"{"photoCollectionVersion":1,"upserts":[],"deletions":[]}"#.utf8)
        let legacy = try JSONDecoder().decode(SyncChanges.self, from: original)
        #expect(legacy.rankingAssessmentVersion == nil)
        let roundtrip = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        #expect(roundtrip["rankingAssessmentVersion"] == nil)
        let modern = SyncChanges(upserts: [], deletions: [])
        #expect(try JSONDecoder().decode(SyncChanges.self, from: JSONEncoder().encode(modern)).rankingAssessmentVersion == 1)
        #expect(String(data: original, encoding: .utf8) == #"{"photoCollectionVersion":1,"upserts":[],"deletions":[]}"#)
    }
}
