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
    @State private var batch = SocialSendBatch()
    @State private var query = ""
    @State private var searching = false
    @State private var cursor: String?
    @State private var loading = false
    @State private var loadFailed = false
    @State private var generation = UUID()
    var body: some View {
        NavigationStack {
            SGEditorialList {
                if batch.complete {
                    Label("Sent", systemImage: "checkmark.circle.fill").accessibilityIdentifier("social-send-success")
                    Text("Your Sous Chefs can open it from their New Ticket.").foregroundStyle(.secondary)
                } else {
                    if loading && people.isEmpty { ProgressView("Loading Sous Chefs") }
                    if loadFailed {
                        Text("Sharing unavailable. Check your connection or sharing access.")
                        Button("Retry Sous Chefs") { Task { await load() } }
                    } else if !loading && people.isEmpty {
                        ContentUnavailableView("No eligible Sous Chefs", systemImage: "person.2", description: Text(query.isEmpty ? "Only current Sous Chefs who already have access appear here." : "Try another name or username."))
                    }
                    ForEach(people) { person in
                        SocialPersonSelectionRow(person: person, selected: batch.selected[person.id] != nil || batch.delivered.contains(person.id)) {
                            batch.toggle(person); searching = false
                        }.disabled(batch.busy || batch.delivered.contains(person.id)).accessibilityValue(batch.delivered.contains(person.id) ? "Sent" : batch.selected[person.id] != nil ? "Selected" : "Not selected").accessibilityIdentifier("send-recipient-\(person.id)")
                    }
                    if let cursor { Button("More Sous Chefs") { Task { await load(after: cursor) } }.disabled(loading || batch.busy) }
                }
            }
            .searchable(text: $query, isPresented: $searching, prompt: "Search your Sous Chefs")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Send to Sous Chefs").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(batch.busy).accessibilityIdentifier("social-send-done") } }
            .safeAreaInset(edge: .bottom) {
                if !batch.complete {
                    VStack(spacing: SGTheme.Space.small) {
                        if !batch.selected.isEmpty { Text("\(batch.selected.count) selected").font(.footnote) }
                        if !batch.failed.isEmpty {
                            Text("Couldn’t send to \(batch.failed.count). Retry or refresh Sous Chefs.").font(.footnote).foregroundStyle(SGTheme.ColorToken.destructive).accessibilityIdentifier("social-send-error")
                            Button("Refresh Sous Chefs") { Task { batch.suspend(); await load() } }
                        }
                        Button(batch.busy ? "Sending…" : batch.failed.isEmpty ? "Send" : "Retry Unsent") { Task { await send() } }
                            .buttonStyle(SGButtonStyle(prominent: true)).disabled(batch.pending.isEmpty || batch.busy || loading || loadFailed)
                            .accessibilityIdentifier("social-send-confirm")
                    }.padding().frame(maxWidth: .infinity).background(SGTheme.ColorToken.background)
                }
            }
            .task(id: query) {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                guard !batch.busy else { return }; await load()
            }
            .onChange(of: phase) { _, next in
                generation = UUID(); people = []; batch.suspend(); loading = false
                if next == .active { Task { await load() } }
            }
            .onDisappear { generation = UUID(); batch.suspend() }
        }.interactiveDismissDisabled(batch.busy)
    }
    private func load(after: String? = nil) async {
        guard let request else { loadFailed = true; return }
        let token = UUID(); generation = token; loading = true; loadFailed = false
        defer { if generation == token { loading = false } }
        do {
            let page = try JSONDecoder().decode(SocialPeoplePage.self, from: await request("social_send", "recipients", content.payload(query: query, after: after)))
            guard !Task.isCancelled, generation == token else { return }
            if after == nil { people = page.people.filter { $0.relationship == .friends } }
            else { let ids = Set(people.map(\.id)); people += page.people.filter { !ids.contains($0.id) && $0.relationship == .friends } }
            cursor = page.nextCursor
        } catch is CancellationError {} catch {
            if generation == token { people = []; cursor = nil; loadFailed = true }
        }
    }
    private func send() async {
        guard let request else { return }
        await batch.send(content: content, request: request)
    }
}
