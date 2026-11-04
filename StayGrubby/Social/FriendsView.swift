import SwiftUI

enum FriendsSection: String, CaseIterable, Identifiable {
    case friends, incoming, outgoing, search, blocked
    var id: String { rawValue }
    var title: String {
        switch self { case .friends: "Sous Chefs"; case .incoming: "Requests"; case .outgoing: "Sent Requests"; case .search: "Find Sous Chefs"; case .blocked: "Blocked Accounts" }
    }
}

struct FriendsView: View {
    @Environment(\.socialRequest) private var request
    let administrative: FriendsSection?
    @State private var section: FriendsSection
    init(section: FriendsSection = .friends) {
        administrative = [.outgoing, .blocked].contains(section) ? section : nil
        _section = State(initialValue: section)
    }
    @State private var query = ""
    @State private var identity: SocialIdentity?
    @State private var page = SocialPeoplePage(people: [])
    @State private var loading = false
    @State private var error: String?
    @State private var editingIdentity = false
    @State private var selectedPerson: SocialPerson?
    @State private var revision = 0
    @State private var requestGeneration = UUID()
    private var taskKey: String { section.rawValue + ":" + query + ":\(revision)" }
    var body: some View {
        SGEditorialList {
            if administrative == nil {
                SGPageIntro(title: "Sous Chefs", subtitle: "Good food is better with good company.", showsTitle: false).listRowSeparator(.hidden)
                ShareMyKitchen()
            }
            if let identity, !identity.isConfigured {
                Section {
                    Text("Your cooking stays private. Set up your profile when you’re ready to connect.")
                    Button("Set up Profile") { editingIdentity = true }.accessibilityIdentifier("friends-setup")
                }
            } else {
                if administrative == nil {
                    Picker("Show", selection: $section) {
                        ForEach([FriendsSection.friends, .search, .incoming]) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("friends-section")
                }
                if section == .incoming && !loading {
                    Text(page.people.count == 1 ? "1 request shown" : "\(page.people.count) requests shown").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
                if section == .search {
                    SGSearchField(placeholder: "Search @username", text: $query, identifier: "friends-search").textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Search by username. Only people who allow discovery appear here.").font(.footnote).foregroundStyle(.secondary)
                }
                if loading && page.people.isEmpty { ProgressView("Loading people") }
                if let error {
                    Text(error).foregroundStyle(.secondary).accessibilityIdentifier("friends-error")
                    Button("Retry") { revision += 1 }
                }
                if !loading && error == nil && page.people.isEmpty {
                    ContentUnavailableView(section == .search ? "Find your cooking friends" : "No \(section.title.lowercased()) yet", systemImage: "person.2",
                        description: Text(section == .search ? "Enter at least two username characters." : "Friendships are mutual. Your private cooking library stays yours."))
                    if section == .friends { Button("Find Sous Chefs") { section = .search }.accessibilityIdentifier("friends-find") }
                }
                ForEach(page.people) { person in
                    Button { selectedPerson = person } label: {
                        HStack(alignment: .top, spacing: 12) {
                        SocialAvatar(name: person.displayName, path: person.avatarPath, size: 54)
                        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                            Text(person.displayName).font(SGTheme.TypeRole.dish)
                            Text(person.handle).foregroundStyle(.secondary)
                            Text(person.relationship.label).font(SGTheme.TypeRole.secondary)
                        } }.padding(.vertical, SGTheme.Space.xSmall).fixedSize(horizontal: false, vertical: true)
                    }.accessibilityIdentifier("friend-person-\(person.username)")
                }
                if page.nextCursor != nil { Button("Load more people") { Task { await load(more: true) } }.disabled(loading) }
            }
        }
        .navigationTitle(administrative?.title ?? "Sous Chefs").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively).refreshable { await load() }
        .onSocialRefresh { if !loading && section != .search { await load() } }
        .task(id: taskKey) {
            page = .init(people: []); error = nil
            if section == .search { do { try await Task.sleep(for: .milliseconds(300)) } catch { return } }
            await load()
        }
        .sheet(item: $selectedPerson, onDismiss: { revision += 1 }) { person in
            NavigationStack {
                FriendProfileView(person: person) { revision += 1 }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selectedPerson = nil } } }
            }
        }
        .sheet(isPresented: $editingIdentity) {
            if let identity { SocialIdentityEditor(identity: identity) { self.identity = $0; revision += 1 } }
        }
    }
    private func load(more: Bool = false) async {
        guard let request else { error = "Connect your account to use Friends."; return }
        let token = UUID(); requestGeneration = token; loading = true; error = nil
        defer { if requestGeneration == token { loading = false } }
        do {
            let own = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init()))
            guard !Task.isCancelled, requestGeneration == token else { return }; identity = own
            guard own.isConfigured else { page = .init(people: []); return }
            let response = try await request("social_people", section.rawValue, .init(query: query, afterUsername: more ? page.nextCursor : nil))
            let next = try JSONDecoder().decode(SocialPeoplePage.self, from: response)
            guard !Task.isCancelled, requestGeneration == token else { return }
            if more {
                let ids = Set(page.people.map(\.id)); page.people += next.people.filter { !ids.contains($0.id) }; page.nextCursor = next.nextCursor
            } else { page = next }
        } catch is CancellationError { } catch {
            guard requestGeneration == token else { return }
            page = .init(people: []); self.error = "Couldn’t load Friends. Check your connection and retry."
        }
    }
}

struct FriendProfileView: View {
    @Environment(\.scenePhase) private var phase
    @State private var generation = UUID()
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State var person: SocialPerson
    var onChange: () -> Void
    @State private var busy = false
    @State private var error = false
    @State private var unavailable = false
    @State private var confirmation: String?
    @State private var socialRoute: SocialPostRoute?
    var body: some View {
        SGEditorialList {
            if unavailable { ContentUnavailableView("Person unavailable", systemImage: "person.crop.circle.badge.xmark", description: Text("Their privacy or relationship may have changed.")) }
            else {
                KitchenIdentityPresentation(name: person.displayName, username: person.username, avatarPath: person.avatarPath)
                    .listRowSeparator(.hidden)
                Section {
                    switch person.relationship {
                    case .none: action("Add Sous Chef", "request")
                    case .incoming: action("Accept Request", "accept"); action("Decline Request", "decline")
                    case .outgoing: action("Cancel Request", "cancel")
                    case .friends: Label("Sous Chef", systemImage: "person.2.fill").foregroundStyle(.secondary)
                    case .blocked: action("Unblock", "unblock")
                    }
                }.disabled(busy)
                if person.relationship != .blocked {
                    SocialProfilePosts(open: { socialRoute = .post($0) }, personID: person.id).id(person.id)
                        .listRowSeparator(.hidden)
                    SocialReportButton(kind: "profile", targetID: person.id)
                }
            }
            if error { Text("This action couldn’t complete. Refresh to check the latest relationship.").accessibilityIdentifier("friend-action-error"); Button("Refresh profile") { Task { await refresh() } } }
        }
        .navigationTitle("Kitchen").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if person.relationship != .blocked && !unavailable {
                Menu {
                    if person.relationship == .friends { Button("Remove Sous Chef", role: .destructive) { confirmation = "remove" } }
                    if person.relationship != .blocked { Button("Block", role: .destructive) { confirmation = "block" } }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    .accessibilityLabel("Profile actions").accessibilityIdentifier("friend-profile-actions")
                    .disabled(busy)
                }
            }
        }
        .navigationDestination(item: $socialRoute) { SocialPostDestination(route: $0) }
        .refreshable { await refresh() }.task { if person.relationship != .blocked { await refresh() } }
        .onSocialRefresh { if !busy && person.relationship != .blocked { await refresh() } }
        .onChange(of: phase) { _, next in generation = UUID(); unavailable = true; if next == .active { Task { await refresh() } } }
        .onDisappear { generation = UUID() }
        .confirmationDialog(confirmation == "block" ? "Block this person?" : "Remove this friend?", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }), titleVisibility: .visible) {
            Button(confirmation == "block" ? "Block Person" : "Remove Friendship", role: .destructive) {
                let action = confirmation ?? "remove"; confirmation = nil; Task { await mutate(action) }
            }
        } message: { Text("This changes your social relationship only. Private cooking and rankings are unchanged.") }
    }
    private func action(_ title: String, _ action: String) -> some View {
        Button(title) { Task { await mutate(action) } }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("friend-action-\(action)")
    }
    private func refresh() async {
        guard let request else { return }; let token = UUID(); generation = token
        do {
            let page = try JSONDecoder().decode(SocialPeoplePage.self, from: await request("social_people", "profile", .init(peerID: person.id)))
            guard !Task.isCancelled, generation == token else { return }
            guard let latest = page.people.first else { unavailable = true; return }; person = latest; error = false; unavailable = false
        } catch is CancellationError { } catch { if generation == token { unavailable = true; self.error = true; onChange() } }
    }
    private func mutate(_ action: String) async {
        guard let request else { return }; busy = true; error = false
        defer { busy = false }
        do {
            _ = try await request("social_people", action, .init(peerID: person.id))
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
            onChange()
            if ["block", "unblock", "remove", "decline", "cancel"].contains(action) { dismiss() }
            else { await refresh() }
        } catch is CancellationError { } catch { self.error = true; await refresh() }
    }
}

struct SocialFriendsLink: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var count: Int?
    @State private var hasMore = false
    @State private var generation = UUID()
    var body: some View {
        if request != nil {
            NavigationLink { FriendsView() } label: {
                HStack(spacing: SGTheme.Space.xSmall) {
                    if let count { Text("\(count)" + (hasMore ? "+" : "")).fontWeight(.semibold).monospacedDigit() }
                    Text("Sous Chefs")
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.font(SGTheme.TypeRole.body).frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("friends-open")
                .task { await load() }.onSocialRefresh { await load() }
                .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
                .onChange(of: phase) { _, next in
                    generation = UUID(); count = nil
                    if next == .active { Task { await load() } }
                }
                .onDisappear { generation = UUID() }
        }
    }
    private func load() async {
        guard let request else { return }; let token = UUID(); generation = token
        do {
            let page = try JSONDecoder().decode(SocialPeoplePage.self, from: await request("social_people", "friends", .init()))
            guard !Task.isCancelled, generation == token else { return }
            count = page.people.count; hasMore = page.nextCursor != nil
        } catch { if generation == token { count = nil } }
    }
}
