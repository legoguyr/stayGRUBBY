import SwiftUI

nonisolated enum SocialSendContent: Equatable, Identifiable, Sendable {
    case recipe(UUID), post(UUID)
    var id: String { type + ":" + target.uuidString }
    var type: String { switch self { case .recipe: "recipe"; case .post: "post" } }
    var target: UUID { switch self { case .recipe(let id), .post(let id): id } }
    func payload(query: String = "", after: String? = nil, peer: UUID? = nil, origin: UUID? = nil) -> SocialPayload {
        var value = SocialPayload(); value.targetType = type; value.targetID = target
        value.query = query; value.afterUsername = after; value.peerID = peer; value.originID = origin
        return value
    }
}

struct SocialSendSheet: View {
    let content: SocialSendContent
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var people: [SocialPerson] = []
    @State private var selected: SocialPerson?
    @State private var query = ""
    @State private var searching = false
    @State private var cursor: String?
    @State private var loading = false
    @State private var busy = false
    @State private var loadFailed = false
    @State private var sendFailed = false
    @State private var sent = false
    @State private var generation = UUID()
    @State private var origin = UUID()
    @State private var originRecipient: UUID?
    var body: some View {
        NavigationStack {
            SGEditorialList {
                if sent {
                    Label("Sent", systemImage: "checkmark.circle.fill").accessibilityIdentifier("social-send-success")
                    Text("Your Sous Chef can open it in Order Up!").foregroundStyle(.secondary)
                } else {
                    if loading && people.isEmpty { ProgressView("Loading Sous Chefs") }
                    if loadFailed {
                        Text("Sharing unavailable. Check your connection or sharing access.")
                        Button("Retry Sous Chefs") { Task { await load() } }
                    } else if !loading && people.isEmpty {
                        ContentUnavailableView("No eligible Sous Chefs", systemImage: "person.2", description: Text(query.isEmpty ? "Only current Sous Chefs who already have access appear here." : "Try another name or username."))
                    }
                    ForEach(people) { person in
                        SocialPersonSelectionRow(person: person, selected: selected?.id == person.id) {
                            selected = selected?.id == person.id ? nil : person
                            if selected != nil && originRecipient != person.id { origin = UUID(); originRecipient = person.id }
                            sendFailed = false; searching = false
                        }.disabled(busy).accessibilityIdentifier("send-recipient-\(person.id)")
                    }
                    if let cursor { Button("More Sous Chefs") { Task { await load(after: cursor) } }.disabled(loading || busy) }
                }
            }
            .searchable(text: $query, isPresented: $searching, prompt: "Search your Sous Chefs")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Send to Sous Chef").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(busy).accessibilityIdentifier("social-send-done") } }
            .safeAreaInset(edge: .bottom) {
                if !sent {
                    VStack(spacing: SGTheme.Space.small) {
                        if let selected { Text("To \(selected.displayName)").font(.footnote) }
                        if sendFailed {
                            Text("Couldn’t send. Retry or refresh Sous Chefs.").font(.footnote).foregroundStyle(SGTheme.ColorToken.destructive).accessibilityIdentifier("social-send-error")
                            Button("Refresh Sous Chefs") { Task { selected = nil; await load() } }
                        }
                        Button(busy ? "Sending…" : "Send") { Task { await send() } }
                            .buttonStyle(SGButtonStyle(prominent: true)).disabled(selected == nil || busy || loading || loadFailed)
                            .accessibilityIdentifier("social-send-confirm")
                    }.padding().frame(maxWidth: .infinity).background(SGTheme.ColorToken.background)
                }
            }
            .task(id: query) {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                guard !busy else { return }; await load()
            }
            .onChange(of: phase) { _, next in
                generation = UUID(); people = []; selected = nil; sent = false; busy = false; loading = false
                if next == .active { Task { await load() } }
            }
            .onDisappear { generation = UUID() }
        }.interactiveDismissDisabled(busy)
    }
    private func load(after: String? = nil) async {
        guard let request else { loadFailed = true; return }
        let token = UUID(); generation = token; loading = true; loadFailed = false
        defer { if generation == token { loading = false } }
        do {
            let page = try JSONDecoder().decode(SocialPeoplePage.self, from: await request("social_send", "recipients", content.payload(query: query, after: after)))
            guard !Task.isCancelled, generation == token else { return }
            if after == nil { people = page.people }
            else { let ids = Set(people.map(\.id)); people += page.people.filter { !ids.contains($0.id) } }
            cursor = page.nextCursor
        } catch is CancellationError {} catch {
            if generation == token { people = []; cursor = nil; selected = nil; loadFailed = true }
        }
    }
    private func send() async {
        guard let request, let selected, !busy else { return }
        let token = generation; busy = true; sendFailed = false
        defer { if generation == token { busy = false } }
        do {
            struct Receipt: Decodable { let sent: Bool }
            let result = try JSONDecoder().decode(Receipt.self, from: await request("social_send", "send", content.payload(peer: selected.id, origin: origin)))
            guard !Task.isCancelled, token == generation else { return }
            sent = result.sent; sendFailed = !result.sent
        } catch is CancellationError {} catch { if generation == token { sendFailed = true } }
    }
}
