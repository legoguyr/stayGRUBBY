import SwiftUI
import CryptoKit
import Observation

nonisolated struct ImageReviewItem: Codable, Identifiable, Sendable {
    var objectID: UUID
    var generation: UUID
    var state: String
    var createdAt: Double
    var bucket: String
    var id: UUID { objectID }
    var title: String {
        switch bucket { case "profile-photos": "Profile photo"; case "recipe-photos": "Recipe photo"; default: "Post photo" }
    }
}
nonisolated struct ImageReviewInspection: Decodable, Sendable {
    var objectID: UUID
    var generation: UUID
    var state: String
    var bucket: String
    var path: String
}

@MainActor @Observable final class ImageModerationModel {
    var items: [ImageReviewItem] = []
    var hasMore = false
    var busy = false
    var failed = false
    var inspection: ImageReviewInspection?
    var image: UIImage?
    var hash: String?
    private var generation = UUID()

    static func authorized(request: SocialRequest) async -> Bool {
        struct Capability: Decodable { var reviewer: Bool }
        return (try? JSONDecoder().decode(Capability.self, from: await request("image_moderation", "capabilities", .init())).reviewer) == true
    }
    func queue(state: String, more: Bool = false, request: SocialRequest) async {
        guard !busy else { return }
        busy = true; failed = false
        defer { busy = false }
        do {
            struct Page: Decodable { var images: [ImageReviewItem] }
            var payload = SocialPayload(); payload.reviewState = state
            if more { payload.afterID = items.last?.objectID }
            let page = try JSONDecoder().decode(Page.self, from: await request("image_moderation", "queue", payload))
            try Task.checkCancellation()
            var seen = Set((more ? items : []).map(\.id))
            items = (more ? items : []) + page.images.filter { seen.insert($0.id).inserted }
            hasMore = page.images.count == 25
        } catch { items = []; hasMore = false; failed = true }
    }
    func inspect(_ id: UUID, request: SocialRequest, media: SocialMediaRequest) async {
        let token = UUID(); generation = token
        inspection = nil; image = nil; hash = nil; failed = false
        do {
            var payload = SocialPayload(); payload.objectID = id
            let subject = try JSONDecoder().decode(ImageReviewInspection.self, from: await request("image_moderation", "inspect", payload))
            guard subject.objectID == id, ["profile-photos", "social-photos", "recipe-photos"].contains(subject.bucket),
                  SocialMediaRules.validPath(subject.path) else { throw AccountFoundationError.invalidResolution }
            guard generation == token, !Task.isCancelled else { return }
            inspection = subject
            // This action deliberately bypasses normal image memory/disk caches.
            let bytes = try await media(.reviewDownload(bucket: subject.bucket, path: subject.path))
            guard generation == token, !Task.isCancelled else { return }
            hash = RecipePhotoService.digest(bytes)
            guard SocialMediaRules.validJPEG(bytes), let decoded = RemoteMediaCache.decode(bytes) else { failed = true; return }
            image = decoded
        } catch { if generation == token { image = nil; hash = nil; failed = true } }
    }
    func clearInspection() {
        generation = UUID()
        inspection = nil; image = nil; hash = nil
    }
    func decide(_ decision: String, request: SocialRequest) async -> Bool {
        guard !busy, let inspection, decision != "approved" || image != nil && hash != nil else { return false }
        busy = true
        defer { busy = false }
        do {
            var payload = SocialPayload(); payload.objectID = inspection.objectID; payload.generation = inspection.generation
            payload.expectedState = inspection.state; payload.decision = decision; payload.photoHash = hash
            _ = try await request("image_moderation", "resolve", payload)
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
            return true
        } catch { failed = true; image = nil; hash = nil; return false }
    }
}

/// Available only after a live, server-enrolled reviewer capability check.
struct ImageModerationView: View {
    @Environment(\.socialRequest) private var request
    @State private var model = ImageModerationModel()
    @State private var state = "pending"
    var body: some View {
        List {
            Picker("Images", selection: $state) {
                Text("Pending").tag("pending")
                Text("Approved").tag("approved")
                Text("Rejected").tag("rejected")
            }.pickerStyle(.segmented).disabled(model.busy)
            if model.failed { Text("Review access changed or the connection failed. Refresh to try again.") }
            else if model.items.isEmpty && !model.busy { Text("No images to review.") }
            ForEach(model.items) { item in
                NavigationLink {
                    ImageModerationDetail(id: item.objectID)
                } label: {
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(SocialPostPresentation.timestamp(Date(timeIntervalSince1970: item.createdAt)))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.accessibilityIdentifier("review-image-\(item.objectID)")
            }
            if model.hasMore { Button("Load more") { Task { await load(more: true) } }.disabled(model.busy) }
        }
        .navigationTitle("Image Review").navigationBarTitleDisplayMode(.inline)
        .task(id: state) { await load() }.refreshable { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
    }
    private func load(more: Bool = false) async {
        guard let request else { return }
        await model.queue(state: state, more: more, request: request)
    }
}

private struct ImageModerationDetail: View {
    let id: UUID
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var model = ImageModerationModel()
    var body: some View {
        ScrollView {
            VStack(spacing: SGTheme.Space.medium) {
                if let image = model.image { Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("Image under review") }
                else if model.failed { Text("The image could not be verified. Refresh or reject it.") }
                else { ProgressView() }
                if let subject = model.inspection {
                    if subject.state != "approved" {
                        Button("Approve") { Task { await decide("approved") } }
                            .buttonStyle(SGButtonStyle()).disabled(model.image == nil || model.busy)
                            .accessibilityIdentifier("review-image-approve")
                    }
                    if subject.state != "rejected" {
                        Button(subject.state == "approved" ? "Hide Image" : "Reject", role: .destructive) { Task { await decide("rejected") } }
                            .disabled(model.busy).frame(minHeight: SGTheme.Size.minimumTap)
                            .accessibilityIdentifier("review-image-reject")
                    }
                }
                Button("Refresh") { Task { await load() } }.disabled(model.busy)
            }.padding(SGTheme.Space.margin)
        }
        .navigationTitle("Review Image").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onDisappear { model.clearInspection() }
        .onChange(of: phase) { _, next in
            model.clearInspection()
            if next == .active { Task { await load() } }
        }
    }
    private func load() async {
        guard let request, let media else { return }
        await model.inspect(id, request: request, media: media)
    }
    private func decide(_ decision: String) async {
        guard let request else { return }
        if await model.decide(decision, request: request) { dismiss() }
    }
}
