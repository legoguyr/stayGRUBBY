import SwiftUI
import Supabase

/// Staff moderation (PUBLIC_MVP_MODERATION.md). A thin client over the existing server contracts:
/// `api.staff_status` (own role, read-only) and `api.moderation_review` (`queue`, `review`, `resolve`).
/// The server decides everything: who is staff, which reports are visible (never reports about the
/// reviewer's own content), who can read a reported photo, and the audited outcome of every decision.
/// Nothing here is cached on device; a removed role stops working on the next request.
nonisolated enum StaffRole: String, Decodable, Sendable { case admin, moderator }

nonisolated struct ModerationReport: Decodable, Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: String
    let reason: String
    /// The server's own timestamp text, sent back unchanged as the queue cursor.
    let createdAt: String
    let status: String
}

nonisolated struct ModerationReportDetail: Decodable, Sendable {
    let id: UUID
    let kind: String
    let reason: String
    let context: String?
    let status: String
    let createdAt: String
    let decision: String?
    let subject: Subject?

    /// Whichever fields the server sends for this kind (`staygrubby.moderation_subject`); nil when the
    /// reported content no longer exists.
    struct Subject: Decodable, Sendable {
        var displayName: String?
        var username: String?
        var title: String?
        var description: String?
        var body: String?
        var content: RecipeContent?
        var state: String?
        var photoPath: String?
    }
}

@MainActor enum ModerationService {
    static let pageSize = 25

    /// Nil for everyone who is not current staff (and on any error: no row is better than a wrong one).
    static func role(_ request: SocialRequest) async -> StaffRole? {
        struct Response: Decodable { var role: StaffRole? }
        return try? JSONDecoder().decode(Response.self, from: await request("staff_status", "me", .init())).role
    }

    static func queue(after last: ModerationReport?, _ request: SocialRequest) async throws -> [ModerationReport] {
        struct Page: Decodable { var reports: [ModerationReport] }
        let data = try await request("moderation_review", "queue", .init(afterID: last?.id, afterTime: last?.createdAt))
        return try JSONDecoder().decode(Page.self, from: data).reports
    }

    static func review(_ id: UUID, _ request: SocialRequest) async throws -> ModerationReportDetail {
        try JSONDecoder().decode(ModerationReportDetail.self, from: await request("moderation_review", "review", .init(reportID: id)))
    }

    enum Decision: String { case dismiss, hide }

    static func resolve(_ id: UUID, _ decision: Decision, _ request: SocialRequest) async throws {
        _ = try await request("moderation_review", "resolve", .init(reportID: id, decision: decision.rawValue))
    }

    static func isAlreadyHandled(_ error: Error) -> Bool { (error as? PostgrestError)?.code == "PT409" }

    static func message(for error: Error) -> String {
        switch (error as? PostgrestError)?.code {
        case "PT409": "Another moderator already handled this report."
        case "42501": "This report isn’t available to you. Your staff access may have changed."
        default: "Couldn’t reach #stayGRUBBY. Check your connection and try again."
        }
    }

    static func kindTitle(_ kind: String) -> String {
        switch kind { case "post": "Post"; case "comment": "Comment"; case "profile": "Profile"; case "recipe": "Recipe"; default: kind.capitalized }
    }

    static func reasonTitle(_ reason: String) -> String { SocialReportReason(rawValue: reason)?.title ?? reason.capitalized }

    static func date(_ text: String) -> Date? {
        let withFraction = ISO8601DateFormatter(); withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}

// MARK: Queue

struct ModerationQueueView: View {
    @Environment(\.socialRequest) private var request
    @State private var reports: [ModerationReport] = []
    @State private var loaded = false
    @State private var hasMore = false
    @State private var loadingMore = false
    @State private var failure: String?

    var body: some View {
        List {
            if !loaded && failure == nil {
                SGLoadingState(label: "Loading reports").listRowBackground(Color.clear)
            } else if let failure, reports.isEmpty {
                SGContentState(title: "Couldn’t Load Reports", symbol: "exclamationmark.triangle", message: failure) {
                    Button("Try Again") { Task { await reload() } }.buttonStyle(.bordered).accessibilityIdentifier("moderation-retry")
                }.listRowBackground(Color.clear)
            } else if reports.isEmpty {
                SGContentState(title: "No Open Reports", symbol: "checkmark.shield",
                               message: "Reports about your own content go to another moderator.")
                    .listRowBackground(Color.clear).accessibilityIdentifier("moderation-empty")
            } else {
                Section {
                    ForEach(reports) { report in
                        NavigationLink {
                            ModerationReportView(reportID: report.id) { reports.removeAll { $0.id == report.id } }
                        } label: { ModerationReportRow(report: report) }
                            .accessibilityIdentifier("moderation-report-\(report.id.uuidString)")
                    }
                    if hasMore {
                        Button { Task { await loadMore() } } label: {
                            if loadingMore { ProgressView().frame(maxWidth: .infinity) } else { Text("Load More").frame(maxWidth: .infinity) }
                        }.disabled(loadingMore).accessibilityIdentifier("moderation-load-more")
                    }
                } footer: {
                    if let failure { Text(failure).foregroundStyle(SGTheme.ColorToken.destructive) }
                    else { Text("Oldest first. Reports about your own content go to another moderator.") }
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(SGTheme.ColorToken.background)
        .navigationTitle("Moderation").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("moderation-queue")
        .task { if !loaded { await reload() } }
        .refreshable { await reload() }
    }

    private func reload() async {
        guard let request else { return }
        failure = nil
        do {
            let page = try await ModerationService.queue(after: nil, request)
            reports = page; hasMore = page.count == ModerationService.pageSize
        } catch { failure = ModerationService.message(for: error) }
        loaded = true
    }

    private func loadMore() async {
        guard let request, let last = reports.last, !loadingMore else { return }
        loadingMore = true; failure = nil
        defer { loadingMore = false }
        do {
            let page = try await ModerationService.queue(after: last, request)
            let known = Set(reports.map(\.id))
            reports += page.filter { !known.contains($0.id) }
            hasMore = page.count == ModerationService.pageSize
        } catch { failure = ModerationService.message(for: error) }
    }
}

private struct ModerationReportRow: View {
    let report: ModerationReport
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ModerationService.kindTitle(report.kind).uppercased()).font(SGTheme.TypeRole.eyebrow).foregroundStyle(SGTheme.ColorToken.accent)
            Text(ModerationService.reasonTitle(report.reason)).font(SGTheme.TypeRole.headline)
            if let date = ModerationService.date(report.createdAt) {
                Text("Reported \(date, format: .relative(presentation: .named))").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 2)
    }
}

// MARK: Report

struct ModerationReportView: View {
    let reportID: UUID
    let resolved: () -> Void
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ModerationReportDetail?
    @State private var failure: String?
    @State private var confirming: ModerationService.Decision?
    @State private var working = false
    @State private var outcome: String?

    var body: some View {
        List {
            if let detail {
                Section("Report") {
                    LabeledContent("Type", value: ModerationService.kindTitle(detail.kind))
                    LabeledContent("Reason", value: ModerationService.reasonTitle(detail.reason))
                    if let date = ModerationService.date(detail.createdAt) {
                        LabeledContent("Reported") { Text(date, format: .dateTime.month().day().year().hour().minute()) }
                    }
                    if let context = detail.context?.trimmingCharacters(in: .whitespacesAndNewlines), !context.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reporter’s note").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                            Text(context).font(SGTheme.TypeRole.body)
                        }
                    }
                }
                ModerationSubjectSection(kind: detail.kind, subject: detail.subject)
                Section {
                    if let outcome {
                        Label(outcome, systemImage: "checkmark.circle").accessibilityIdentifier("moderation-outcome")
                    } else if detail.status != "pending" {
                        Label("Already handled", systemImage: "checkmark.circle").accessibilityIdentifier("moderation-outcome")
                    } else {
                        Button("Hide Content", role: .destructive) { confirming = .hide }
                            .disabled(working || detail.subject == nil).accessibilityIdentifier("moderation-hide")
                        Button("Dismiss Report") { confirming = .dismiss }
                            .disabled(working).accessibilityIdentifier("moderation-dismiss")
                    }
                } footer: {
                    if let failure { Text(failure).foregroundStyle(SGTheme.ColorToken.destructive).accessibilityIdentifier("moderation-error") }
                    else if outcome == nil && detail.status == "pending" {
                        Text(detail.subject == nil
                             ? "The reported content no longer exists. Dismiss the report to close it."
                             : "Hiding removes the content from everyone except its owner. Every decision is recorded.")
                    }
                }
            } else if let failure {
                SGContentState(title: "Report Unavailable", symbol: "exclamationmark.triangle", message: failure) {
                    Button("Try Again") { Task { await load() } }.buttonStyle(.bordered)
                }.listRowBackground(Color.clear)
            } else {
                SGLoadingState(label: "Loading report").listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(SGTheme.ColorToken.background)
        .navigationTitle("Report").navigationBarTitleDisplayMode(.inline)
        .task { if detail == nil { await load() } }
        .confirmationDialog(confirming == .hide ? "Hide this content?" : "Dismiss this report?",
                            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }), titleVisibility: .visible) {
            if confirming == .hide {
                Button("Hide Content", role: .destructive) { Task { await resolve(.hide) } }.accessibilityIdentifier("moderation-confirm-hide")
            } else {
                Button("Dismiss Report") { Task { await resolve(.dismiss) } }.accessibilityIdentifier("moderation-confirm-dismiss")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirming == .hide ? "It stays visible to its owner. This decision is recorded."
                                     : "The content stays up. This decision is recorded.")
        }
    }

    private func load() async {
        guard let request else { return }
        failure = nil
        do { detail = try await ModerationService.review(reportID, request) }
        catch { failure = ModerationService.message(for: error) }
    }

    private func resolve(_ decision: ModerationService.Decision) async {
        guard let request, !working else { return }
        working = true; failure = nil
        defer { working = false }
        do {
            try await ModerationService.resolve(reportID, decision, request)
            outcome = decision == .hide ? "Content hidden" : "Report dismissed"
            resolved()
        } catch where ModerationService.isAlreadyHandled(error) {
            outcome = "Already handled"; resolved()
        } catch { failure = ModerationService.message(for: error) }
    }
}

/// The reported content, read-only, with the app's existing profile and photo presentation.
private struct ModerationSubjectSection: View {
    let kind: String
    let subject: ModerationReportDetail.Subject?
    var body: some View {
        Section {
            if let subject {
                switch kind {
                case "profile":
                    HStack(spacing: SGTheme.Space.small) {
                        SocialAvatar(name: subject.displayName ?? "", path: nil, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(subject.displayName ?? "No display name").font(SGTheme.TypeRole.headline)
                            if let username = subject.username { Text("@\(username)").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary) }
                        }
                    }
                    if let path = subject.photoPath { ModerationPhoto(bucket: .avatar, path: path) }
                case "post":
                    if let path = subject.photoPath { ModerationPhoto(bucket: .post, path: path) }
                    if let title = subject.title, !title.isEmpty { Text(title).font(SGTheme.TypeRole.headline) }
                    if let description = subject.description, !description.isEmpty { Text(description).font(SGTheme.TypeRole.body) }
                case "comment":
                    Text(subject.body ?? "").font(SGTheme.TypeRole.body)
                case "recipe":
                    if let path = subject.photoPath { ModerationPhoto(bucket: .recipe, path: path) }
                    if let content = subject.content { ModerationRecipeText(content: content) }
                default:
                    Text("This content type can’t be shown here.").foregroundStyle(.secondary)
                }
                if subject.state == "hidden" {
                    Label("Already hidden", systemImage: "eye.slash").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
            } else {
                Text("The reported content no longer exists.").foregroundStyle(.secondary).accessibilityIdentifier("moderation-subject-missing")
            }
        } header: { Text("Reported \(ModerationService.kindTitle(kind))") }
    }
}

private struct ModerationRecipeText: View {
    let content: RecipeContent
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            Text(content.title.isEmpty ? "Untitled Recipe" : content.title).font(SGTheme.TypeRole.headline)
            if let description = content.description, !description.isEmpty { Text(description).font(SGTheme.TypeRole.body) }
            ForEach(content.orderedComponents) { component in
                VStack(alignment: .leading, spacing: 4) {
                    if let title = component.title, !title.isEmpty { Text(title).font(SGTheme.TypeRole.body.weight(.semibold)) }
                    ForEach(component.ingredients) { Text("• \($0.displayText)").font(SGTheme.TypeRole.secondary) }
                    ForEach(Array(component.steps.enumerated()), id: \.element.id) { index, step in
                        Text("\(index + 1). \(step.instruction)").font(SGTheme.TypeRole.secondary)
                    }
                }
            }
            if let tips = content.tips, !tips.isEmpty { Text(tips).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary) }
        }
    }
}

/// A reported photo. Downloaded fresh through Storage, which authorizes staff for reported content only
/// (`review_image_allowed`), and deliberately never written to the account's photo cache.
private struct ModerationPhoto: View {
    enum Bucket { case post, avatar, recipe }
    let bucket: Bucket
    let path: String
    @Environment(\.socialMedia) private var media
    @State private var image: UIImage?
    @State private var failed = false
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else if failed { Label("Photo unavailable", systemImage: "photo").foregroundStyle(.secondary) }
            else { SGPhotoPlaceholder().frame(height: 200) }
        }
        .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.field))
        .accessibilityLabel("Reported photo").accessibilityIdentifier("moderation-photo")
        .task(id: path) {
            guard let media else { failed = true; return }
            let action: SocialMediaAction = switch bucket {
            case .post: .download(path: path)
            case .avatar: .avatarDownload(path: path)
            case .recipe: .recipeDownload(path: path)
            }
            do {
                let bytes = try await media(action)
                guard SocialMediaRules.validJPEG(bytes), let decoded = RemoteMediaCache.decode(bytes, maximumPixels: 2048) else { failed = true; return }
                image = decoded
            } catch { if !Task.isCancelled { failed = true } }
        }
    }
}
