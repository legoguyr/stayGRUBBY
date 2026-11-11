import SwiftUI
import SwiftData

struct CookedWithSelection: View {
    @Binding var selected: Set<UUID>
    var editing = false
    var existingPeople: [SocialPerson] = []
    @Environment(\.sgReduceMotion) private var reduceMotion
    @Environment(\.socialRequest) private var request
    @State private var people: [SocialPerson] = []
    @State private var loading = false
    @State private var failed = false
    @State private var cursor: String?
    @State private var revision = 0
    @State private var choosing = false
    @State private var query = ""
    @State private var searching = false
    private var previewPeople: [SocialPerson] {
        let tagged = existingPeople.filter { selected.contains($0.id) }
        let ids = Set(tagged.map(\.id))
        return tagged + people.filter { !ids.contains($0.id) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            Button { choosing = true } label: {
                HStack {
                    Label("Tag a Sous Chef", systemImage: "person.crop.circle.badge.plus")
                    Spacer()
                    if !selected.isEmpty { Text("\(selected.count)").monospacedDigit() }
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
            }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("cooked-with-open")
            if !previewPeople.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: SGTheme.Space.medium) {
                        ForEach(previewPeople.prefix(8)) { person in
                            Button { toggle(person) } label: {
                                VStack(spacing: SGTheme.Space.xSmall) {
                                    SocialAvatar(name: person.displayName, path: person.avatarPath, size: 48)
                                        .overlay(alignment: .bottomTrailing) {
                                            if selected.contains(person.id) {
                                                Image(systemName: "checkmark.circle.fill").symbolRenderingMode(.palette)
                                                    .foregroundStyle(SGTheme.ColorToken.onAccent, SGTheme.ColorToken.buttonAccent)
                                            }
                                        }
                                    Text(person.displayName).font(SGTheme.TypeRole.secondary).lineLimit(1)
                                }.frame(width: 76).padding(.vertical, SGTheme.Space.xSmall).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("Cooked with \(person.displayName)")
                                .accessibilityValue(selected.contains(person.id) ? "Selected" : "Not selected")
                                .accessibilityIdentifier("cooked-with-\(person.id)")
                        }
                    }
                }
            }
            if failed { Text("Sous Chefs unavailable. Open to retry.").font(.footnote).foregroundStyle(.secondary) }
        }
        .animation(reduceMotion ? nil : SGTheme.Motion.quick, value: selected)
        .sensoryFeedback(.selection, trigger: selected)
        .task(id: "\(revision):\(editing ? query : "")") { await load() }
        .sheet(isPresented: $choosing) {
            NavigationStack {
                SGEditorialList {
                    Section {
                        Text(editing ? "Add or remove up to eight Sous Chefs. New invitations are sent when you save." : "Invite up to eight Sous Chefs after ranking. They choose whether to add their own cook.")
                            .font(.footnote).foregroundStyle(.secondary)
                        DisclosureGroup("What invitations share") {
                            Text("Dish title, Course, Cuisine and public source attribution. Private notes, allergens and photos stay private. Tagging does not post to The Pass.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if loading { ProgressView("Loading Sous Chefs") }
                    if failed { Button("Retry Sous Chefs") { revision += 1 } }
                    ForEach(people.filter { query.isEmpty || $0.displayName.localizedCaseInsensitiveContains(query) || $0.username.localizedCaseInsensitiveContains(query) }) { person in
                        SocialPersonSelectionRow(person: person, selected: selected.contains(person.id)) { toggle(person); searching = false }
                            .accessibilityLabel("Cooked with \(person.displayName)")
                            .accessibilityIdentifier("sous-chef-selection-\(person.id)")
                    }
                    if let cursor { Button("More Sous Chefs") { Task { await load(after: cursor) } }.disabled(loading) }
                    if people.isEmpty && !loading && !failed { Text("Your current Sous Chefs will appear here.").foregroundStyle(.secondary) }
                }
                .searchable(text: $query, isPresented: $searching, prompt: "Search your Sous Chefs")
                .navigationTitle("Tag a Sous Chef").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { choosing = false }.accessibilityIdentifier("cooked-with-done") } }
                .safeAreaInset(edge: .bottom) { Text("\(selected.count) of 8 selected").font(.footnote).foregroundStyle(.secondary).padding().frame(maxWidth: .infinity).background(SGTheme.ColorToken.background) }
            }
        }
    }
    private func toggle(_ person: SocialPerson) {
        if selected.contains(person.id) { selected.remove(person.id) }
        else if selected.count < 8 { selected.insert(person.id) }
    }
    private func load(after: String? = nil) async {
        guard let request else { return }; loading = true; failed = false
        defer { loading = false }
        do {
            let response = try await request(editing ? "social_cooking" : "social_people",
                                             editing ? "eligible_selection" : "friends",
                                             .init(query: editing ? String(query.prefix(50)) : nil, afterUsername: after))
            let page = try JSONDecoder().decode(SocialPeoplePage.self, from: response)
            try Task.checkCancellation()
            if after == nil { people = [] }
            let ids = Set(people.map(\.id)); people += page.people.filter { !ids.contains($0.id) }; cursor = page.nextCursor
        } catch is CancellationError { } catch { failed = true; if after == nil { people = [] } }
    }
}

struct SharedCookingEntryView: View {
    var eventID: UUID? = nil
    var postID: UUID? = nil
    @Environment(\.socialRequest) private var request
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @Environment(\.sharedCooking) private var sharedCooking
    @State private var event: SharedCookingEvent?
    @State private var post: SocialPost?
    @State private var claim: SocialCookingClaim?
    @State private var list: RankingList?
    @State private var existing: CookingAttempt?
    @State private var busy = false
    @State private var failed = false
    @State private var declined = false
    @State private var completed = false
    @State private var generation = UUID()
    var body: some View {
        SGEditorialList {
            if failed {
                ContentUnavailableView("Cooking activity unavailable", systemImage: "wifi.exclamationmark", description: Text("Your access may have changed or the connection was interrupted."))
                Button("Retry") { Task { await load() } }
            } else if declined { Text("Invitation declined. Nothing was added to your cooking history.") }
            else {
                if busy { ProgressView("Loading cooking activity") }
                if let event {
                    Text(event.metadata.title ?? "Cooked Together").font(.title2.bold())
                    Label(event.owner.displayName, systemImage: "person.2")
                    ForEach(event.participants) { participant in
                        HStack {
                            SocialAvatar(name: participant.person.displayName, path: participant.person.avatarPath, size: 32)
                            Text(participant.person.displayName); Spacer(); Text(stateLabel(participant.state)).foregroundStyle(.secondary)
                        }
                        if event.isOwner && ["pending", "joining"].contains(participant.state) {
                            Button("Remove invitation for \(participant.person.displayName)", role: .destructive) { Task { await remove(participant.person.id) } }
                        }
                    }
                }
                if let post {
                    Text(post.title).font(.title2.bold()); Text("Run It Back from \(post.author.displayName)’s cooking")
                    if post.recipeID != nil { NavigationLink("View recipe") { SharedRecipeView(postID: post.id) } }
                }
                if let existing {
                    NavigationLink("View my saved cook") { AttemptDetailView(attempt: existing) }
                } else if completed { Text("Already added to your cooking. Let your account finish restoring to see it here.") }
                else if event?.isOwner != true && (event != nil || post != nil) {
                    Text("Review the details and rank this cook in your own library. Scores, comparisons, private notes and photos are never copied.")
                    if event != nil { Text("Joining confirms you cooked together. Participation may appear to mutual friends when either cook is shared.").font(.footnote).foregroundStyle(.secondary) }
                    Button(event != nil ? "Add to My Cooking" : "Run It Back") { Task { await begin() } }
                        .accessibilityIdentifier("shared-begin").disabled(busy)
                    if event != nil { Button("Decline invitation", role: .destructive) { Task { await decline() } }.accessibilityIdentifier("shared-decline").disabled(busy) }
                }
            }
        }.navigationTitle(eventID == nil ? "Run It Back" : "Cooked Together").navigationBarTitleDisplayMode(.inline)
            .task { await load() }.refreshable { await load() }
            .onSocialRefresh { if !busy { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); event = nil; post = nil; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .sheet(item: $claim, onDismiss: { Task { await load() } }) { claim in
                if let list { AddCookingView(list: list, origin: claim) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
    }
    private func stateLabel(_ state: String) -> String {
        switch state { case "pending": "Invited"; case "joining": "Reviewing"; case "joined": "Joined"; case "declined": "Declined"; default: "Removed" }
    }
    private func load() async {
        guard !declined else { return }
        guard let request else { return }; let token = UUID(); generation = token; busy = true; failed = false; event = nil; post = nil
        defer { if generation == token { busy = false } }
        do {
            list = try CookingStore.globalRanking(context: context)
            if let eventID {
                let next = try JSONDecoder().decode(SharedCookingEvent.self, from: await request("social_cooking", "event", .init(eventID: eventID)))
                guard !Task.isCancelled, generation == token else { return }; event = next
            } else if let postID {
                let next = try JSONDecoder().decode(SocialPostsPage.self, from: await request("social_feed", "post", .init(postID: postID))).posts.first
                guard !Task.isCancelled, generation == token else { return }; post = next
            }
        } catch is CancellationError { } catch { if generation == token { event = nil; post = nil; failed = true } }
    }
    private func begin() async {
        guard let request else { return }; busy = true
        defer { busy = false }
        do {
            let next = try JSONDecoder().decode(SocialCookingClaim.self, from: await request("social_cooking", eventID == nil ? "recreate" : "claim", .init(postID: postID, eventID: eventID)))
            try Task.checkCancellation()
            existing = try context.fetch(FetchDescriptor<CookingAttempt>()).first { $0.rankedItemID == next.itemID }
            if existing != nil || next.completed {
                completed = true
                if existing != nil && !next.completed {
                    try sharedCooking?.record(itemID: next.itemID, participants: [], originID: next.id, recipeOriginID: next.recipeOriginID)
                    sharedCooking?.retry()
                }
            }
            else { claim = next }
        } catch is CancellationError { } catch { failed = true }
    }
    private func decline() async {
        guard let request, let eventID else { return }
        do { _ = try await request("social_cooking", "decline", .init(eventID: eventID)); try Task.checkCancellation(); declined = true; NotificationCenter.default.post(name: .socialContentChanged, object: nil) }
        catch is CancellationError { } catch { failed = true }
    }
    private func remove(_ peer: UUID) async {
        guard let request, let eventID else { return }
        do { _ = try await request("social_cooking", "remove", .init(peerID: peer, eventID: eventID)); await load() }
        catch is CancellationError { } catch { failed = true }
    }
}

struct CookingProvenanceView: View {
    let itemID: UUID
    var includesRecipe = true
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var page: CookingProvenancePage?
    @State private var failed = false
    @State private var generation = UUID()
    var body: some View {
        if request != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let page {
                    ForEach(page.origins) { origin in
                        Text(origin.kind == "recreated" ? origin.creator.map { "Inspired by \($0.displayName)" } ?? "Original cooking activity unavailable" : origin.creator.map { "Cooked with \($0.displayName)" } ?? "Cooked Together · original activity unavailable")
                            .font(.subheadline)
                    }
                    ForEach(page.events) { event in
                        NavigationLink(SharedCookingEvent.collaboratorLine(event)) { SharedCookingEntryView(eventID: event.id) }
                            .accessibilityIdentifier("cook-collaborators")
                    }
                }
                if failed { Button("Retry cooking provenance") { Task { await load() } }.font(.footnote) }
                if includesRecipe { RecipeCookingProvenance(itemID: itemID) }
                SharedCookingPending(itemID: itemID)
            }.task(id: itemID) { await load() }
                .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
                .onChange(of: phase) { _, next in generation = UUID(); page = nil; if next == .active { Task { await load() } } }
                .onDisappear { generation = UUID() }
        }
    }
    private func load() async {
        guard let request else { return }; let token = UUID(); generation = token; page = nil; failed = false
        do { let next = try JSONDecoder().decode(CookingProvenancePage.self, from: await request("social_cooking", "own", .init(targetID: itemID))); guard !Task.isCancelled, generation == token else { return }; page = next }
        catch is CancellationError { } catch { if generation == token { failed = true } }
    }
}
