import Foundation
import Testing
@testable import StayGrubby

/// App Store compliance: every required-reason API the app uses is declared in the bundled privacy
/// manifest, and the app declares no tracking. Add a category here when code starts using a new one.
@MainActor struct PrivacyManifestTests {
    @Test func requiredReasonAPIsAreDeclaredAndTrackingIsOff() throws {
        let url = try #require(Bundle(for: AccountContentCache.self).url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let manifest = try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
        let declared = Dictionary(uniqueKeysWithValues: ((manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]]) ?? []).compactMap { entry in
            (entry["NSPrivacyAccessedAPIType"] as? String).map { ($0, entry["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []) }
        })
        #expect(declared["NSPrivacyAccessedAPICategoryUserDefaults"] == ["CA92.1"])
        #expect(declared["NSPrivacyAccessedAPICategoryDiskSpace"] == ["E174.1"], "AccountContentCache.adaptiveDiskLimit")
        #expect(declared["NSPrivacyAccessedAPICategoryFileTimestamp"] == ["C617.1"], "AccountContentCache.rebuildIndex")
    }
}
