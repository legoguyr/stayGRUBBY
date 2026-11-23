import SwiftUI

struct KitchenSettings<AccountUtilities: View>: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.featureFlags) private var flags
    @State private var showingPolicy = false
    @State private var showingTutorial = false
    /// Current staff role from the server (`api.staff_status`); asked only while `staff_moderation` is on.
    @State private var staffRole: StaffRole?
    #if DEBUG
    @State private var previewingFirstRun = false
    #endif
    @ViewBuilder var account: () -> AccountUtilities
    var body: some View {
        List {
            Section("Account") {
                if request != nil {
                    NavigationLink { SocialIdentitySection() } label: { Label("Profile", systemImage: "person.crop.circle") }
                        .accessibilityIdentifier("settings-account")
                }
                NavigationLink { Form { account() }.navigationTitle("Account & Sync").navigationBarTitleDisplayMode(.inline) } label: {
                    Label("Account & Sync", systemImage: "arrow.triangle.2.circlepath")
                }.accessibilityIdentifier("settings-sync")
            }
            if request != nil {
                Section("Social") {
                    NavigationLink("Sharing Preferences") { SocialSettingsView() }.accessibilityIdentifier("social-settings-open")
                    NavigationLink("Sent Requests") { FriendsView(section: .outgoing) }
                }
                Section {
                    NavigationLink("Blocked Accounts") { FriendsView(section: .blocked) }
                } header: { Text("Privacy & Safety") } footer: {
                    Text("Sharing is for mutual Sous Chefs. Profiles are private unless you choose Public in Profile; your cooking library is never public. Blocked accounts can’t see your profile or what you share, and their content is hidden from you.")
                }
            }

            if staffRole != nil {
                Section {
                    NavigationLink { ModerationQueueView() } label: { Label("Moderation", systemImage: "checkmark.shield") }
                        .accessibilityIdentifier("settings-moderation")
                } header: { Text("Staff") } footer: {
                    Text("Shown only to #stayGRUBBY staff. Reports about your own content go to another moderator.")
                }
            }

            #if DEBUG
            // Debug builds installed from Xcode only; compiled out of Release (TestFlight and App Store).
            Section {
                NavigationLink("Recipe Intelligence") { RecipeIntelligenceDiagnosticsView() }
                Button("Preview First-Time Experience") { previewingFirstRun = true }.accessibilityIdentifier("internal-preview-open")
            } header: { Text("Developer Tools — Debug Only") } footer: {
                Text("The preview replays the new-account journey with temporary data. Nothing is saved and your account is unchanged.")
            }
            #endif
            Section("Support & About") {
                // Replay records nothing and touches no data (FirstRunTutorial).
                Button("How #stayGRUBBY Works") { showingTutorial = true }.accessibilityIdentifier("settings-tutorial")
                Button("Privacy Policy") { showingPolicy = true }.accessibilityIdentifier("privacy-policy-open")
                if flags.isOn(.legalTerms) {
                    Link("Terms of Use", destination: LegalDocuments.termsOfUse).accessibilityIdentifier("settings-terms")
                    Link("Community Guidelines", destination: LegalDocuments.communityGuidelines).accessibilityIdentifier("settings-guidelines")
                }
                Link("Support", destination: URL(string: "https://staygrubby.com/support")!)
                LabeledContent("StayGrubby", value: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(SGTheme.ColorToken.background)
            .task(id: flags.isOn(.staffModeration)) {
                // Ordinary users never ask unless the flag is on; the server still checks every moderation action.
                guard flags.isOn(.staffModeration), let request else { staffRole = nil; return }
                staffRole = await ModerationService.role(request)
            }
            .sheet(isPresented: $showingPolicy) { PrivacyPolicyView() }
            .fullScreenCover(isPresented: $showingTutorial) { TutorialView(replay: true) { showingTutorial = false } }
            #if DEBUG
            .fullScreenCover(isPresented: $previewingFirstRun) { FirstRunPreview { previewingFirstRun = false } }
            #endif
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}
