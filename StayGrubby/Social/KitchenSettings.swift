import SwiftUI

struct KitchenSettings<AccountUtilities: View>: View {
    @Environment(\.socialRequest) private var request
    @State private var showingPolicy = false
    @State private var reviewer = false
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
            if reviewer {
                Section("Moderation") {
                    NavigationLink("Image Review") { ImageModerationView() }.accessibilityIdentifier("image-review-open")
                }
            }
            #if DEBUG
            Section("Developer") { NavigationLink("Recipe Intelligence") { RecipeIntelligenceDiagnosticsView() } }
            #endif
            Section("Support & About") {
                Button("Privacy Policy") { showingPolicy = true }.accessibilityIdentifier("privacy-policy-open")
                Link("Support", destination: URL(string: "https://staygrubby.com/support")!)
                LabeledContent("StayGrubby", value: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(SGTheme.ColorToken.background)
            .task { if let request { reviewer = await ImageModerationModel.authorized(request: request) } }
            .sheet(isPresented: $showingPolicy) { PrivacyPolicyView() }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}
