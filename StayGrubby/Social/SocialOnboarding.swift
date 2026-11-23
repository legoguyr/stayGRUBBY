import SwiftUI
import SwiftData
import Supabase

/// New-account social setup (Public MVP, November 16, 2026; UI_ARCHITECTURE "Onboarding").
///
/// Three short steps on the existing `social_identity` contract — no new backend:
/// 1. **Name and username.** Saved immediately with `discoverable = false`, so the username is
///    reserved and checked for uniqueness right away and the account is private by default even if
///    the person stops here.
/// 2. **Privacy.** An explicit Private (recommended, preselected) / Public choice. Public saves
///    `discoverable = true`: the profile can be found by username in Find Sous Chefs. Either way,
///    shared cooks and Recipes reach only accepted Sous Chefs (the backend has no public content).
/// 3. **Photo** (optional).
///
/// Progress is kept per account on this device, so a closed app resumes at the same step. A brand-new
/// account (no cooks) must finish; an existing account without a username is offered setup once and
/// can choose Not Now (The Pass and My Kitchen keep their Set up Profile entries). Once complete, no
/// further identity request is made at launch.
nonisolated enum SocialOnboardingPolicy {
    enum Presentation: Equatable { case none, required, offer }
    static func presentation(identity: SocialIdentity?, hasCooks: Bool, dismissed: Bool, resuming: Bool) -> Presentation {
        if resuming { return hasCooks ? .offer : .required }
        guard let identity, !identity.isConfigured else { return .none } // Unknown (offline) or already set up.
        if !hasCooks { return .required }
        return dismissed ? .none : .offer
    }
    /// Live guidance for the username field (nil when valid or empty).
    static func usernameMessage(_ raw: String) -> String? {
        let value = SocialIdentityRules.username(raw)
        guard !value.isEmpty else { return nil }
        if value.count < 3 { return "Use at least 3 characters." }
        if value.count > 24 { return "Use 24 characters or fewer." }
        if value.range(of: "^[a-z0-9]+(_[a-z0-9]+)*$", options: .regularExpression) == nil { return "Use lowercase letters, numbers and single underscores." }
        if SocialIdentityRules.reserved.contains(value.replacingOccurrences(of: "_", with: "")) { return "That username is reserved." }
        return nil
    }
}

/// A username another account holds (`23505` from `social_identity save`).
nonisolated struct SocialUsernameUnavailable: Error {}
nonisolated enum SocialIdentitySaveFailure: Equatable {
    case usernameTaken, invalid, connection
    static func classify(_ error: Error) -> Self {
        if error is SocialUsernameUnavailable { return .usernameTaken }
        if let error = error as? PostgrestError {
            if error.code == "23505" { return .usernameTaken }
            if error.code == "22023" { return .invalid }
        }
        return .connection
    }
    var message: String {
        switch self {
        case .usernameTaken: "That username is taken. Try another."
        case .invalid: "Check your name and username and try again."
        case .connection: "Couldn’t save. Check your connection and try again."
        }
    }
}

/// Per-account, on-device setup progress (no content; names only until saved to the server).
nonisolated struct SocialOnboardingDraft: Codable, Equatable {
    enum Step: Int, Codable { case profile, privacy, photo }
    var step: Step = .profile
    var displayName = ""
    var username = ""
    var publicProfile = false

    private static func key(_ scope: String) -> String { "staygrubby.onboarding.draft.\(scope)" }
    private static func doneKey(_ scope: String) -> String { "staygrubby.onboarding.done.\(scope)" }
    private static func dismissedKey(_ scope: String) -> String { "staygrubby.onboarding.dismissed.\(scope)" }
    static func load(_ scope: String, defaults: UserDefaults = .standard) -> Self? {
        defaults.data(forKey: key(scope)).flatMap { try? JSONDecoder().decode(Self.self, from: $0) }
    }
    func save(_ scope: String, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key(scope)) }
    }
    static func isComplete(_ scope: String, defaults: UserDefaults = .standard) -> Bool { defaults.bool(forKey: doneKey(scope)) }
    static func isDismissed(_ scope: String, defaults: UserDefaults = .standard) -> Bool { defaults.bool(forKey: dismissedKey(scope)) }
    static func complete(_ scope: String, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: doneKey(scope)); defaults.removeObject(forKey: key(scope))
    }
    static func dismiss(_ scope: String, defaults: UserDefaults = .standard) { defaults.set(true, forKey: dismissedKey(scope)) }
    /// Removes every trace of a scope (the internal first-run preview's temporary scope).
    static func discard(_ scope: String, defaults: UserDefaults = .standard) {
        for key in [key(scope), doneKey(scope), dismissedKey(scope)] { defaults.removeObject(forKey: key) }
    }
}

/// Decides once per account session whether to present setup, then presents it full screen.
struct SocialOnboardingHost: ViewModifier {
    @Environment(\.socialRequest) private var request
    @Environment(\.scoreMilestoneScope) private var scope
    @Environment(\.modelContext) private var context
    @State private var presentation = SocialOnboardingPolicy.Presentation.none
    @State private var identity: SocialIdentity?
    @State private var touring = false

    /// First run is one full-screen flow (Build 7): kitchen setup, then the kitchen tour, then Grub Rank.
    func body(content: Content) -> some View {
        content
            .task(id: scope) { await evaluate() }
            .fullScreenCover(isPresented: Binding(get: { (presentation != .none || touring) && scope != nil },
                                                  set: { if !$0 { presentation = .none; touring = false } })) {
                Group {
                    if touring {
                        TutorialView { if let scope { FirstRunTutorial.complete(scope) }; touring = false }
                            .transition(.opacity)
                    } else {
                        SocialOnboardingView(scope: scope ?? "", identity: identity, required: presentation == .required) {
                            presentation = .none
                            // A new account goes straight on to the tour in the same cover.
                            if let scope, FirstRunTutorial.isPending(scope) { withAnimation(SGTheme.Motion.standard) { touring = true } }
                        }
                    }
                }
            }
    }
    private var enabled: Bool {
        #if DEBUG
        // Isolated UI fixtures opt in explicitly so existing review flows are unchanged.
        if DebugReviewConfiguration.current.storeID != nil { return ProcessInfo.processInfo.arguments.contains("--onboarding-review") }
        #endif
        return true
    }
    private func evaluate() async {
        guard enabled, let scope else { return }
        if SocialOnboardingDraft.isComplete(scope) {
            // Setup finished earlier. An interrupted new-account tour resumes (on-device, no request);
            // everyone else is an existing account and never sees it.
            if FirstRunTutorial.isPending(scope) { touring = true } else { FirstRunTutorial.bypass(scope) }
            return
        }
        guard let request else { return }
        let hasCooks = ((try? context.fetchCount(FetchDescriptor<CookingAttempt>())) ?? 0) > 0
        let draft = SocialOnboardingDraft.load(scope)
        do {
            let current = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init()))
            try Task.checkCancellation()
            identity = current
            // A draft past the profile step means the username is saved; resume privacy/photo.
            let resuming = (draft?.step ?? .profile) != .profile && current.isConfigured
            if current.isConfigured && !resuming {
                SocialOnboardingDraft.complete(scope)
                if FirstRunTutorial.isPending(scope) { touring = true } else { FirstRunTutorial.bypass(scope) }
                return
            }
            let next = SocialOnboardingPolicy.presentation(identity: current, hasCooks: hasCooks,
                dismissed: SocialOnboardingDraft.isDismissed(scope), resuming: resuming)
            if next == .required { FirstRunTutorial.begin(scope) } else { FirstRunTutorial.bypass(scope) }
            presentation = next
        } catch { /* Offline or unavailable: never block the library; evaluate again next launch. */ }
    }
}

struct SocialOnboardingView: View {
    let scope: String
    let identity: SocialIdentity?
    let required: Bool
    let close: () -> Void
    /// False in the internal first-run preview: finishing must not make the real app reload anything.
    let announcesChanges: Bool
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @Environment(\.featureFlags) private var flags
    @State private var draft: SocialOnboardingDraft
    @State private var saving = false
    @State private var failure: SocialIdentitySaveFailure?
    @State private var photo: Data?
    @State private var removePhoto = false
    @State private var preparingPhoto = false
    @State private var photoFailed = false
    @FocusState private var focused: Bool

    init(scope: String, identity: SocialIdentity?, required: Bool, announcesChanges: Bool = true, close: @escaping () -> Void) {
        self.scope = scope; self.identity = identity; self.required = required; self.announcesChanges = announcesChanges; self.close = close
        var initial = SocialOnboardingDraft.load(scope) ?? SocialOnboardingDraft()
        if initial.displayName.isEmpty { initial.displayName = identity?.displayName ?? "" }
        if initial.username.isEmpty { initial.username = identity?.username ?? "" }
        if identity?.isConfigured != true { initial.step = .profile } // Nothing saved yet: start at the beginning.
        else if initial.step == .profile { initial.step = .privacy; initial.publicProfile = identity?.discoverable ?? false }
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                    header
                    switch draft.step {
                    case .profile: profileStep
                    case .privacy: privacyStep
                    case .photo: photoStep
                    }
                    if let failure { Text(failure.message).font(SGTheme.TypeRole.body).foregroundStyle(SGTheme.ColorToken.destructive).accessibilityIdentifier("onboarding-error") }
                }
                .frame(maxWidth: SGTheme.Size.contentMaximum, alignment: .leading)
                .padding(SGTheme.Space.margin).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SGTheme.ColorToken.background)
            .safeAreaInset(edge: .bottom) { footer }
            .toolbar {
                if !required {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Not Now") { SocialOnboardingDraft.dismiss(scope); close() }.disabled(saving).accessibilityIdentifier("onboarding-not-now")
                    }
                }
                if draft.step == .privacy && identity?.isConfigured != true || draft.step == .photo {
                    ToolbarItem(placement: .navigation) {
                        Button("Back", systemImage: "chevron.left") { failure = nil; draft.step = draft.step == .photo ? .privacy : .profile; draft.save(scope) }
                            .disabled(saving).accessibilityIdentifier("onboarding-back")
                    }
                }
            }
            .interactiveDismissDisabled(true)
            .onChange(of: draft) { _, next in next.save(scope) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            if let logo = OfficialBrandWordmark.image {
                Image(uiImage: logo).resizable().scaledToFit().frame(width: 96, height: 54).accessibilityLabel("#stayGRUBBY")
            }
            SGEyebrow(text: "Your kitchen · \(draft.step.rawValue + 1) of 3")
            Text(title).font(SGTheme.TypeRole.hero).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding-title")
            Text(subtitle).font(SGTheme.TypeRole.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var title: String {
        switch draft.step { case .profile: "Set up your Kitchen"; case .privacy: "Who can find you?"; case .photo: "Add a profile photo" }
    }
    private var subtitle: String {
        switch draft.step {
        case .profile: "Sous Chefs find and tag you by your @username. Everything you cook stays private until you share it."
        case .privacy: "Private is the default. You can change it anytime in Settings."
        case .photo: "Optional. Your initials are used until you add one."
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                Text("Name").font(SGTheme.TypeRole.headline)
                TextField("Your name or nickname", text: $draft.displayName).textContentType(.nickname)
                    .padding(SGTheme.Space.small).background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
                    .focused($focused).accessibilityIdentifier("onboarding-name")
            }
            VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                Text("Username").font(SGTheme.TypeRole.headline)
                HStack(spacing: 2) {
                    Text("@").foregroundStyle(.secondary)
                    TextField("username", text: $draft.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textContentType(.username).accessibilityIdentifier("onboarding-username")
                        .onChange(of: draft.username) { _, _ in if failure == .usernameTaken { failure = nil } }
                }
                .padding(SGTheme.Space.small).background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
                Text(SocialOnboardingPolicy.usernameMessage(draft.username) ?? "3–24 lowercase letters, numbers or single underscores. Unique to you.")
                    .font(SGTheme.TypeRole.secondary)
                    .foregroundStyle(SocialOnboardingPolicy.usernameMessage(draft.username) == nil ? Color.secondary : SGTheme.ColorToken.destructive)
                    .accessibilityIdentifier("onboarding-username-hint")
            }
            // App Review 1.2: people who can share agree to the Terms and Community Guidelines first.
            if flags.isOn(.legalTerms) {
                Text("By continuing, you agree to the [Terms of Use](\(LegalDocuments.termsOfUse.absoluteString)) and [Community Guidelines](\(LegalDocuments.communityGuidelines.absoluteString)).")
                    .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).tint(SGTheme.ColorToken.accent)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("onboarding-terms-agreement")
            }
        }
    }

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            choice(public: false, title: "Private", badge: "Recommended", symbol: "lock",
                   detail: "People can’t find you in search. Only people you add as Sous Chefs see what you share.")
            choice(public: true, title: "Public", badge: nil, symbol: "magnifyingglass",
                   detail: "People can find your name, username and photo in Find Sous Chefs. What you share still goes only to your Sous Chefs.")
            Text("This only decides who can find you. You still choose what to share each time you post, and your Grub Rank, notes and unshared cooks are always private.")
                .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func choice(public value: Bool, title: String, badge: String?, symbol: String, detail: String) -> some View {
        let selected = draft.publicProfile == value
        return Button { draft.publicProfile = value } label: {
            HStack(alignment: .top, spacing: SGTheme.Space.small) {
                Image(systemName: symbol).font(.title3).frame(width: 28).foregroundStyle(SGTheme.ColorToken.accent)
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    HStack(spacing: SGTheme.Space.xSmall) {
                        Text(title).font(SGTheme.TypeRole.headline)
                        if let badge { Text(badge).font(.caption.weight(.semibold)).foregroundStyle(SGTheme.ColorToken.accent) }
                    }
                    Text(detail).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3)
                    .foregroundStyle(selected ? SGTheme.ColorToken.accent : .secondary)
            }
            .padding(SGTheme.Space.medium).frame(maxWidth: .infinity, alignment: .leading)
            .background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: SGTheme.Radius.card).strokeBorder(selected ? SGTheme.ColorToken.accent : SGTheme.ColorToken.border, lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(SGTheme.ColorToken.primaryText)
        .accessibilityElement(children: .ignore).accessibilityLabel([title, badge, detail].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(value ? "onboarding-public" : "onboarding-private")
    }

    private var photoStep: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SocialAvatarPicker(name: draft.displayName, path: identity?.avatarPath, photo: $photo, removePhoto: $removePhoto, loading: $preparingPhoto)
            if photoFailed { Text("Couldn’t upload this photo. Try again, or finish without one.").font(SGTheme.TypeRole.body).accessibilityIdentifier("onboarding-photo-error") }
        }
    }

    private var footer: some View {
        VStack(spacing: SGTheme.Space.small) {
            Button { Task { await advance() } } label: {
                Text(saving ? "Saving…" : draft.step == .photo ? (photo == nil ? "Finish" : "Save Photo and Finish") : "Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(SGButtonStyle(prominent: true)).disabled(!canAdvance).accessibilityIdentifier("onboarding-continue")
            if draft.step == .photo && photo != nil {
                Button("Finish Without Photo") { finish() }.disabled(saving).accessibilityIdentifier("onboarding-skip-photo")
            }
        }
        .padding(.horizontal, SGTheme.Space.margin).padding(.vertical, SGTheme.Space.small)
        .background(SGTheme.ColorToken.background)
    }
    private var canAdvance: Bool {
        guard !saving, !preparingPhoto else { return false }
        if draft.step == .profile { return SocialIdentityRules.valid(name: draft.displayName, username: draft.username) }
        return true
    }

    private func advance() async {
        guard let request else { failure = .connection; return }
        failure = nil; saving = true; defer { saving = false }
        do {
            switch draft.step {
            case .profile:
                // Private by default: the first save never makes the profile findable.
                _ = try await save(discoverable: false, request: request)
                focused = false; draft.step = .privacy
            case .privacy:
                if draft.publicProfile != (identity?.discoverable ?? false) || draft.publicProfile {
                    _ = try await save(discoverable: draft.publicProfile, request: request)
                }
                draft.step = .photo
            case .photo:
                if photo != nil {
                    photoFailed = false
                    do { try await SocialAvatarService.save(photo: photo, remove: false, currentPath: identity?.avatarPath, assetID: UUID(), request: request, media: media) }
                    catch is CancellationError { return } catch { photoFailed = true; return }
                }
                finish()
            }
        } catch is CancellationError {
        } catch { failure = SocialIdentitySaveFailure.classify(error) }
    }
    private func save(discoverable: Bool, request: SocialRequest) async throws -> SocialIdentity {
        let data = try await request("social_identity", "save", .init(displayName: SocialIdentityRules.name(draft.displayName),
            username: SocialIdentityRules.username(draft.username), discoverable: discoverable))
        return try JSONDecoder().decode(SocialIdentity.self, from: data)
    }
    private func finish() {
        SocialOnboardingDraft.complete(scope)
        if announcesChanges { NotificationCenter.default.post(name: .socialContentChanged, object: nil) } // The Pass and My Kitchen pick up the new identity.
        close()
    }
}
