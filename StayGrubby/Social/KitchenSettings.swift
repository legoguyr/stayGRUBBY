import SwiftUI

struct KitchenSettings<AccountUtilities: View>: View {
    #if INTERNAL_TESTING
    private static var buildSuffix: String { " · Internal" }
    #else
    private static var buildSuffix: String { "" }
    #endif
    @Environment(\.socialRequest) private var request
    @State private var showingPolicy = false
    @State private var showingTutorial = false
    #if DEBUG || INTERNAL_TESTING
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

            #if INTERNAL_TESTING
            InternalTestingSettingsSection { previewingFirstRun = true }
            #endif
            #if DEBUG
            Section("Developer") {
                NavigationLink("Recipe Intelligence") { RecipeIntelligenceDiagnosticsView() }
                // UI-test entry to the same preview Internal builds show (isolated review stores only).
                if DebugReviewConfiguration.current.storeID != nil, ProcessInfo.processInfo.arguments.contains("--internal-preview-review") {
                    Button("Preview First-Time Experience") { previewingFirstRun = true }.accessibilityIdentifier("internal-preview-open")
                }
            }
            #endif
            Section("Support & About") {
                // Replay records nothing and touches no data (FirstRunTutorial).
                Button("How #stayGRUBBY Works") { showingTutorial = true }.accessibilityIdentifier("settings-tutorial")
                Button("Privacy Policy") { showingPolicy = true }.accessibilityIdentifier("privacy-policy-open")
                Link("Support", destination: URL(string: "https://staygrubby.com/support")!)
                LabeledContent("StayGrubby", value: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))\(Self.buildSuffix)")
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(SGTheme.ColorToken.background)
            .sheet(isPresented: $showingPolicy) { PrivacyPolicyView() }
            .fullScreenCover(isPresented: $showingTutorial) { TutorialView(replay: true) { showingTutorial = false } }
            #if DEBUG || INTERNAL_TESTING
            .fullScreenCover(isPresented: $previewingFirstRun) { FirstRunPreview { previewingFirstRun = false } }
            #endif
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}
