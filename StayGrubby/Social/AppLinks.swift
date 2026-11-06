import SwiftUI

nonisolated enum AppRoute: Equatable, Identifiable, Sendable {
    case profile(String), post(UUID), recipe(UUID), sharedRecipe(UUID), invalid
    var id: String {
        switch self {
        case .profile(let name): "profile:" + name
        case .post(let id): "post:" + id.uuidString
        case .recipe(let id): "recipe:" + id.uuidString
        case .sharedRecipe(let id): "shared-recipe:" + id.uuidString
        case .invalid: "invalid"
        }
    }
    init(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              (parts.scheme == "https" && parts.host == "staygrubby.com") || (parts.scheme == "staygrubby" && parts.host == "open"),
              parts.user == nil, parts.password == nil, parts.port == nil, parts.query == nil, parts.fragment == nil else { self = .invalid; return }
        // Decode ordinary URL escaping, then validate the complete route. No open redirects or private paths.
        let path = parts.path
        if path.hasPrefix("/@") {
            let name = String(path.dropFirst(2))
            guard SocialIdentityRules.valid(name: "Cook", username: name), name == SocialIdentityRules.username(name) else { self = .invalid; return }
            self = .profile(name); return
        }
        let pieces = path.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count >= 3, pieces[0].isEmpty, let uuid = UUID(uuidString: String(pieces[2])), String(pieces[2]).count == 36 else { self = .invalid; return }
        if pieces.count == 3 && pieces[1] == "p" { self = .post(uuid) }
        else if pieces.count == 3 && pieces[1] == "r" { self = .recipe(uuid) }
        else if pieces.count == 4 && pieces[1] == "p" && pieces[3] == "recipe" { self = .sharedRecipe(uuid) }
        else { self = .invalid }
    }
    static func profileURL(username: String) -> URL? {
        guard SocialIdentityRules.valid(name: "Cook", username: username), username == SocialIdentityRules.username(username) else { return nil }
        return URL(string: "https://staygrubby.com/@" + username)
    }
    static func postURL(_ id: UUID) -> URL { URL(string: "https://staygrubby.com/p/" + id.uuidString.lowercased())! }
    static func recipeURL(_ id: UUID) -> URL { URL(string: "https://staygrubby.com/r/" + id.uuidString.lowercased())! }
    static func sharedRecipeURL(postID: UUID) -> URL { URL(string: postURL(postID).absoluteString + "/recipe")! }
}
@MainActor @Observable final class AppLinkRouter {
    var pending: AppRoute?
    private(set) var ownKitchenRequests = 0
    func openOwnKitchen() { pending = nil; ownKitchenRequests += 1 }
    func receive(_ url: URL) { pending = AppRoute(url: url) }
}
struct AppLinkPresentation: ViewModifier {
    @Environment(AppLinkRouter.self) private var router
    func body(content: Content) -> some View {
        @Bindable var router = router
        content.sheet(item: $router.pending) { route in
            NavigationStack { AppLinkDestination(route: route).toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { router.pending = nil } }
            } }
        }
    }
}
struct AppLinkDestination: View {
    let route: AppRoute
    var body: some View {
        switch route {
        case .profile: ProfileLinkDestination(route: route)
        case .post(let id): SocialPostDetailView(postID: id)
        case .recipe(let id): RecipeDetailView(id: id)
        case .sharedRecipe(let id): SharedRecipeView(postID: id)
        case .invalid: ContentUnavailableView("Link unavailable", systemImage: "link", description: Text("This StayGrubby link is invalid or no longer supported."))
        }
    }
}
struct ProfileLinkDestination: View {
    @Environment(AppLinkRouter.self) private var router
    let route: AppRoute
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var isOwn = false
    @State private var person: SocialPerson?
    @State private var failed = false
    @State private var generation = UUID()
    var body: some View {
        Group {
            if let person {
                if isOwn {
                    List { Text(person.displayName).font(.title.bold()); Text(person.handle); Text("Your Kitchen"); ShareMyKitchen() }
                } else { FriendProfileView(person: person) {} }
            }
            else if failed { ContentUnavailableView("Kitchen unavailable", systemImage: "person.crop.circle.badge.xmark", description: Text("This link is invalid, private, blocked, removed or currently unavailable.")).accessibilityIdentifier("profile-link-unavailable") }
            else { ProgressView("Opening Kitchen") }
        }.navigationTitle("My Kitchen").task(id: route.id) { await resolve() }
            .onChange(of: phase) { _, next in generation = UUID(); person = nil; if next == .active { Task { await resolve() } } }
            .onDisappear { generation = UUID() }
    }
    private func resolve() async {
        guard case .profile(let username) = route, let request else { failed = true; return }
        let token = UUID(); generation = token; failed = false; person = nil
        do {
            let page = try JSONDecoder().decode(SocialPeoplePage.self, from: await request("profile_link", "resolve", .init(username: username)))
            guard !Task.isCancelled, token == generation else { return }
            person = page.people.first; isOwn = page.isOwn == true; failed = person == nil
            if isOwn && person != nil { router.openOwnKitchen() }
        } catch is CancellationError {} catch { if token == generation { failed = true; person = nil } }
    }
}
struct ShareMyKitchen: View {
    var compact = false
    @Environment(\.socialRequest) private var request
    @State private var identity: SocialIdentity?
    @State private var failed = false
    var body: some View {
        if request != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let identity, identity.discoverable, let username = identity.username, let url = AppRoute.profileURL(username: username) {
                    if compact {
                        SocialLinkShareAction(url: url, title: "Share My Kitchen", compact: true).accessibilityIdentifier("share-my-kitchen")
                    } else {
                        ShareLink(item: url) { Label("Share My Kitchen", systemImage: "square.and.arrow.up") }
                            .buttonStyle(SGButtonStyle()).accessibilityIdentifier("share-my-kitchen")
                    }
                } else if compact && !failed {
                    Image(systemName: "square.and.arrow.up").frame(minWidth: 44, minHeight: 44).foregroundStyle(.secondary)
                        .accessibilityLabel("Kitchen sharing unavailable").accessibilityHint("Enable discovery in Settings, Profile to share your Kitchen")
                } else if identity != nil { Text("To share your Kitchen, enable discovery in Settings → Profile.").font(.footnote).foregroundStyle(.secondary) }
                if failed {
                    Button { Task { await load() } } label: {
                        if compact { Image(systemName: "arrow.clockwise").frame(minWidth: 44, minHeight: 44) }
                        else { Text("Retry Kitchen sharing") }
                    }.accessibilityLabel("Retry Kitchen sharing")
                }
            }.task { await load() }
                .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
        }
    }
    private func load() async {
        guard let request else { return }
        do { let next = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init())); try Task.checkCancellation(); identity = next; failed = false }
        catch is CancellationError {} catch { identity = nil; failed = true }
    }
}
