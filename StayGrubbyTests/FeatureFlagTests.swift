import Foundation
import Testing
@testable import StayGrubby

/// Feature flags default off; only server-enabled keys turn on.
@MainActor struct FeatureFlagTests {
    @Test func flagsAreOffUnlessTheServerEnablesThem() async {
        #expect(!FeatureFlags.off.isOn(.dishAggregateScores))
        let on = await FeatureFlagService.load { Data(#"{"enabled":["dish_aggregate_scores","unknown_future"]}"#.utf8) }
        #expect(on.isOn(.dishAggregateScores))
        let failing = await FeatureFlagService.load { throw URLError(.notConnectedToInternet) }
        #expect(failing == .off)
        let malformed = await FeatureFlagService.load { Data("{}".utf8) }
        #expect(malformed == .off)
    }
}
