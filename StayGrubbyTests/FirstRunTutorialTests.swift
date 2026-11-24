import Foundation
import Testing
@testable import StayGrubby

/// Build 7 first run: new accounts see the kitchen tour once, after setup; existing accounts never do;
/// interrupted tours resume; nothing ever resets a completed state.
struct FirstRunTutorialTests {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "tutorial-\(UUID().uuidString)")! }

    @Test func newAccountsArePendingUntilFinished() {
        let d = defaults()
        #expect(FirstRunTutorial.state("a", defaults: d) == .undecided)
        FirstRunTutorial.begin("a", defaults: d)
        #expect(FirstRunTutorial.isPending("a", defaults: d))
        FirstRunTutorial.bypass("a", defaults: d)
        #expect(FirstRunTutorial.isPending("a", defaults: d), "An interrupted new-account tour is never dropped")
        FirstRunTutorial.complete("a", defaults: d)
        #expect(FirstRunTutorial.state("a", defaults: d) == .done)
        FirstRunTutorial.begin("a", defaults: d)
        #expect(FirstRunTutorial.state("a", defaults: d) == .done, "Done is never reset")
    }

    @Test func existingAccountsBypassAndAccountsAreIndependent() {
        let d = defaults()
        FirstRunTutorial.bypass("existing", defaults: d)
        #expect(FirstRunTutorial.state("existing", defaults: d) == .done)
        FirstRunTutorial.begin("existing", defaults: d)
        #expect(FirstRunTutorial.state("existing", defaults: d) == .done)
        #expect(FirstRunTutorial.state("other", defaults: d) == .undecided)
    }

    @Test func pagesAreOrderedAndEndWithGetStarted() {
        #expect(TutorialPage.allCases.count == 4)
        #expect(TutorialPage.allCases.last?.isLast == true)
        #expect(TutorialPage.allCases.dropLast().allSatisfy { !$0.isLast })
        #expect(TutorialPage.allCases.allSatisfy { !$0.title.isEmpty && !$0.message.isEmpty && !$0.illustrationLabel.isEmpty })
        #expect(!TutorialPage.allCases.contains { $0.message.lowercased().contains("version") }, "No technical terms")
    }
}
