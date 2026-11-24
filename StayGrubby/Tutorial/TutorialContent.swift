import SwiftUI

/// First-time tutorial (Build 7; UI_ARCHITECTURE §14). Content is plain data so the same pages, copy and
/// illustrations can be reused for the website, Instagram and App Store screenshots (render any page's
/// `TutorialIllustration` with `ImageRenderer`). Nothing here reads or writes the library, ranks anything
/// or makes a request: every name and score below is illustrative.
nonisolated enum TutorialPage: Int, CaseIterable, Identifiable, Sendable {
    case dishAndCooks, thisOrThat, grubRank, foodBibleAndPass

    var id: Int { rawValue }
    var eyebrow: String {
        switch self {
        case .dishAndCooks: "Cook it"
        case .thisOrThat: "Rank it"
        case .grubRank: "Grub Rank"
        case .foodBibleAndPass: "Keep it · Share it"
        }
    }
    var title: String {
        switch self {
        case .dishAndCooks: "One Dish. Every cook."
        case .thisOrThat: "This or that?"
        case .grubRank: "Your food, ranked."
        case .foodBibleAndPass: "Save it. Show it off."
        }
    }
    var message: String {
        switch self {
        case .dishAndCooks:
            "A Dish is what you make, like Rack of Lamb. Every time you make it is a cook, with its own score and photos."
        case .thisOrThat:
            "After a cook, pick between two things you’ve made. No stars, no sliders. Just this or that."
        case .grubRank:
            "Your picks build your Grub Rank. Your top three are your Signature Dishes."
        case .foodBibleAndPass:
            "Keep your Recipes in Food Bible. Proud of a cook? Post it to The Pass for your Sous Chefs to Give Hands 🙌."
        }
    }
    /// VoiceOver description of the illustration (the copy above stays the primary explanation).
    var illustrationLabel: String {
        switch self {
        case .dishAndCooks: "Example: the Dish Rack of Lamb with three cooks: Grilled, Sous Vide and Herb-Crusted Rack of Lamb."
        case .thisOrThat: "Example: Mushroom Risotto or Pan-Seared Duck Breast. One is chosen."
        case .grubRank: "Example Grub Rank: Rack of Lamb, Mushroom Risotto, Pan-Seared Duck Breast and Chicken Piccata, the top three marked as Signature Dishes."
        case .foodBibleAndPass: "Example: the Herb-Crusted Rack of Lamb Recipe in Food Bible and that cook posted to The Pass with Hands."
        }
    }
    var isLast: Bool { self == Self.allCases.last }
}

/// Once per account (Build 7). A genuinely new account (setup required: no cooks, no username) is marked
/// `pending` when setup begins and sees the kitchen tour right after it; closing the app mid-tour resumes the
/// tour, never setup. Every other account is marked `done` the first time it is evaluated, so existing
/// users bypass it automatically and session restoration never shows it. Replay lives in Settings and
/// records nothing. On-device only: no request, no library writes.
nonisolated enum FirstRunTutorial {
    enum State: Int { case undecided, pending, done }
    static let version = 1
    static func key(_ scope: String) -> String { "staygrubby.tutorial.v\(version).\(scope)" }
    static func state(_ scope: String, defaults: UserDefaults = .standard) -> State {
        State(rawValue: defaults.integer(forKey: key(scope))) ?? .undecided
    }
    static func isPending(_ scope: String, defaults: UserDefaults = .standard) -> Bool { state(scope, defaults: defaults) == .pending }
    /// A new account starting required setup.
    static func begin(_ scope: String, defaults: UserDefaults = .standard) {
        if state(scope, defaults: defaults) == .undecided { defaults.set(State.pending.rawValue, forKey: key(scope)) }
    }
    /// An existing account: never shown (keeps a pending tour of an interrupted new account).
    static func bypass(_ scope: String, defaults: UserDefaults = .standard) {
        if state(scope, defaults: defaults) == .undecided { complete(scope, defaults: defaults) }
    }
    /// Get Started or Skip.
    static func complete(_ scope: String, defaults: UserDefaults = .standard) { defaults.set(State.done.rawValue, forKey: key(scope)) }
}
