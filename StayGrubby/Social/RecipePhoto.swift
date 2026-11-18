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
    static func descriptor(_ id: UUID, request: SocialRequest) async throws -> RecipePhotoDescriptor {
        let descriptor = try JSONDecoder().decode(RecipePhotoDescriptor.self, from: await request("recipes", "photo", .init(assetID: id)))
        guard descriptor.id == id, descriptor.ready, SocialMediaRules.validPath(descriptor.path) else { throw AccountFoundationError.invalidResolution }
        return descriptor
    }
    static func download(_ id: UUID, request: SocialRequest, media: SocialMediaRequest) async throws -> Data {
        let descriptor = try await descriptor(id, request: request)
        let bytes = try await media(.recipeDownload(path: descriptor.path))
        guard SocialMediaRules.validJPEG(bytes), digest(bytes) == descriptor.sha256 else { throw AccountFoundationError.invalidResolution }
        return bytes
    }
}
@MainActor enum RecipePhotoPolicy {
    /// The cook whose photo stands in when the Recipe has no photo of its own: the linked cook when it
    /// has a photo, else the Dish's representative cook (`dish` is always the viewer's own Dish). An exact
    /// link to a cook that was 86'd or has no photo no longer leaves an empty frame (MVP stabilization).
    static func fallbackCook(ownedPhoto: UUID?, cook: CookingAttempt?, dish: Dish?, exactLink: Bool) -> CookingAttempt? {
        guard ownedPhoto == nil else { return nil }
        if let cook, cook.primaryImage != nil { return cook }
        return dish?.cookbookRepresentativeCook ?? cook
    }
}
/// Recipe bytes take precedence; linked cook photography remains a read-only fallback, also shown
/// when the Recipe photo can't be fetched (never an empty frame when the Dish has a photo).
/// Recipe photo assets are immutable per ID (a replacement is a new asset), so verified bytes and the
/// decoded image are cached by asset ID in the account cache: no repeat RPC or download, no flash.
struct RecipePhoto: View {
    let id: UUID?
    var dish: Dish? = nil
    var name: String
    var cook: CookingAttempt? = nil
    var exactCookLink = false
    var preview: Data? = nil
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @Environment(\.accountContentCache) private var cache
    @State private var refresh = UUID()
    @State private var loaded: UIImage?
    @State private var loadedID: UUID?
    @State private var unavailable = false
    private var fallbackCook: CookingAttempt? { RecipePhotoPolicy.fallbackCook(ownedPhoto: unavailable ? nil : id, cook: cook, dish: dish, exactLink: exactCookLink) }
    static func cacheKey(_ id: UUID) -> String { "recipe-asset/\(id.uuidString.lowercased())" }
    private var image: UIImage? {
        if let preview { return UIImage(data: preview) }
        guard let id else { return nil }
        if loadedID == id, let loaded { return loaded }
        return nil
    }
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else if id != nil && !unavailable { SGPhotoPlaceholder().overlay { ProgressView() } }
            else { CookbookPhoto(dish: dish, name: name, cook: fallbackCook) }
        }.clipped().accessibilityElement(children: .ignore).accessibilityLabel("Photo for \(name)")
            .accessibilityValue(image != nil ? "Recipe photo" : fallbackCook?.primaryImage != nil ? (exactCookLink || cook != nil ? "Linked cook photo" : "Dish family photo") : id != nil && !unavailable ? "Recipe photo loading" : "StayGrubby placeholder")
            .modifier(RemoteImageRefresh { loaded = nil; loadedID = nil; unavailable = false; refresh = UUID() })
            .task(id: "\(id?.uuidString ?? "")/\(refresh)") {
                unavailable = false; loaded = nil; loadedID = nil
                guard let id else { return }
                guard let request, let media else { unavailable = true; return }
                do {
                    let descriptor = try await RecipePhotoService.descriptor(id, request: request)
                    let image = try await AuthorizedRemoteImage.load(key: Self.cacheKey(id), action: .recipeDownload(path: descriptor.path),
                                                                     expectedHash: descriptor.sha256, cache: cache, media: media)
                    try Task.checkCancellation(); loaded = image; loadedID = id
                } catch is CancellationError {} catch { unavailable = true }
            }
    }
}

struct RecipePhotoEditor: View {
    let id: UUID?
    var dish: Dish?
    var cook: CookingAttempt? = nil
    var exactCookLink = false
    let name: String
    @Binding var bytes: Data?
    @Binding var removed: Bool
    @Binding var assetID: UUID
    @Binding var loading: Bool
    @State private var selection: PhotosPickerItem?
    @State private var failed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecipePhoto(id: removed ? nil : id, dish: dish, name: name, cook: cook, exactCookLink: exactCookLink, preview: bytes).frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 16))
            #if DEBUG
            if DebugReviewConfiguration.current.storeID != nil && ProcessInfo.processInfo.arguments.contains("--recipe-photo-review") {
                Button("Use Test Recipe Photo") { bytes = SocialReview.avatarFixture; assetID = UUID(); removed = false }.accessibilityIdentifier("recipe-photo-fixture")
            }
            #endif
            PhotosPicker(selection: $selection, matching: .images) { Label(bytes != nil || (!removed && id != nil) ? "Replace Recipe Photo" : "Add Recipe Photo", systemImage: "photo") }.disabled(loading).accessibilityIdentifier("recipe-photo-choose")
            if bytes != nil || (!removed && id != nil) { Button("Remove Recipe Photo", role: .destructive) { bytes = nil; removed = true; selection = nil }.accessibilityIdentifier("recipe-photo-remove") }
            if loading { ProgressView("Preparing photo") }
            if failed { Text("Couldn’t prepare this photo. Try another image.").font(.footnote) }
            Text("Recipe photos stay separate from your cook’s photos.").font(.footnote).foregroundStyle(.secondary)
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
