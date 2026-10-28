import SwiftUI
import PhotosUI
import CryptoKit

nonisolated struct RecipePhotoDescriptor: Codable, Sendable {
    let id: UUID
    let path: String
    let sha256: String
    let ready: Bool
}
@MainActor enum RecipePhotoService {
    static func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
    static func upload(_ bytes: Data, id: UUID, request: SocialRequest, media: SocialMediaRequest) async throws -> UUID {
        guard SocialMediaRules.validJPEG(bytes) else { throw AccountFoundationError.invalidResolution }
        var payload = SocialPayload(); payload.assetID = id; payload.photoHash = digest(bytes); payload.photoBytes = bytes.count
        let descriptor = try JSONDecoder().decode(RecipePhotoDescriptor.self, from: await request("recipes", "prepare_photo", payload))
        guard descriptor.id == id, descriptor.sha256 == payload.photoHash, SocialMediaRules.validPath(descriptor.path) else { throw AccountFoundationError.invalidResolution }
        if !descriptor.ready { _ = try await media(.recipeUpload(path: descriptor.path, bytes: bytes)) }
        let restored = try await media(.recipeDownload(path: descriptor.path))
        guard digest(restored) == descriptor.sha256, SocialMediaRules.validJPEG(restored) else { throw AccountFoundationError.invalidResolution }
        _ = try await request("recipes", "complete_photo", payload)
        return id
    }
    static func download(_ id: UUID, request: SocialRequest, media: SocialMediaRequest) async throws -> Data {
        let descriptor = try JSONDecoder().decode(RecipePhotoDescriptor.self, from: await request("recipes", "photo", .init(assetID: id)))
        guard descriptor.id == id, descriptor.ready, SocialMediaRules.validPath(descriptor.path) else { throw AccountFoundationError.invalidResolution }
        let bytes = try await media(.recipeDownload(path: descriptor.path))
        guard SocialMediaRules.validJPEG(bytes), digest(bytes) == descriptor.sha256 else { throw AccountFoundationError.invalidResolution }
        return bytes
    }
}
/// Recipe bytes take precedence; linked cook photography remains a read-only fallback.
struct RecipePhoto: View {
    let id: UUID?
    var dish: Dish? = nil
    var name: String
    var preview: Data? = nil
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @State private var loaded: Data?
    @State private var loadedID: UUID?
    var body: some View {
        Group {
            if let image = (preview ?? (loadedID == id ? loaded : nil)).flatMap(UIImage.init(data:)) { Image(uiImage: image).resizable().scaledToFill() }
            else { CookbookPhoto(dish: dish, name: name) }
        }.clipped().accessibilityElement(children: .ignore).accessibilityLabel("Photo for \(name)")
            .accessibilityValue(preview != nil || (loadedID == id && loaded != nil) ? "Recipe photo" : dish?.cookbookRepresentativeCook?.primaryImage != nil ? "Linked Dish photo" : "StayGrubby placeholder")
            .task(id: id) {
                loaded = nil; loadedID = nil
                guard let id, let request, let media else { return }
                do { let bytes = try await RecipePhotoService.download(id, request: request, media: media); try Task.checkCancellation(); loaded = bytes; loadedID = id } catch { }
            }
    }
}
struct RecipePhotoEditor: View {
    let id: UUID?
    var dish: Dish?
    let name: String
    @Binding var bytes: Data?
    @Binding var removed: Bool
    @Binding var assetID: UUID
    @Binding var loading: Bool
    @State private var selection: PhotosPickerItem?
    @State private var failed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecipePhoto(id: removed ? nil : id, dish: dish, name: name, preview: bytes).frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 16))
            #if DEBUG
            if DebugReviewConfiguration.current.storeID != nil && ProcessInfo.processInfo.arguments.contains("--recipe-photo-review") {
                Button("Use Test Recipe Photo") { bytes = SocialReview.avatarFixture; assetID = UUID(); removed = false }.accessibilityIdentifier("recipe-photo-fixture")
            }
            #endif
            PhotosPicker(selection: $selection, matching: .images) { Label(bytes != nil || (!removed && id != nil) ? "Replace Recipe Photo" : "Add Recipe Photo", systemImage: "photo") }.disabled(loading).accessibilityIdentifier("recipe-photo-choose")
            if bytes != nil || (!removed && id != nil) { Button("Remove Recipe Photo", role: .destructive) { bytes = nil; removed = true; selection = nil }.accessibilityIdentifier("recipe-photo-remove") }
            if loading { ProgressView("Preparing photo") }
            if failed { Text("Couldn’t prepare this photo. Try another image.").font(.footnote) }
            Text("Optional. A linked Dish photo is used when this Recipe has no photo.").font(.footnote).foregroundStyle(.secondary)
        }.task(id: selection) {
            guard let selection else { return }
            loading = true; failed = false; defer { loading = false }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else { throw LocalPhotoStore.PhotoError.unreadableImage }
                let prepared = try await Task.detached { try LocalPhotoStore.prepare(data: data) }.value
                try Task.checkCancellation(); bytes = prepared.displayData; assetID = UUID(); removed = false
            } catch is CancellationError {} catch { failed = true }
        }
    }
}
