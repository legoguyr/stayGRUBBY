import SwiftUI
import CryptoKit

/// Permission is refreshed before memory/disk reuse. Denied cached bytes never render.
@MainActor enum AuthorizedRemoteImage {
    static func load(key: String, action: SocialMediaAction, expectedHash: String? = nil,
                     cache: AccountContentCache?, media: @escaping SocialMediaRequest) async throws -> UIImage {
        guard let path = action.paths.first else { throw AccountFoundationError.invalidResolution }
        do {
            let byteKey = "\(action.bucket)/\(path)"
            let cachedImage = cache?.media.image(key)
            let cachedBytes = cache?.media.data(byteKey)
            if cachedImage != nil || cachedBytes != nil {
                try await requireAccess(action: action, cache: cache, media: media)
                try Task.checkCancellation()
            }
            if let cachedImage { return cachedImage }
            let bytes: Data
            if let cachedBytes { bytes = cachedBytes }
            else { bytes = try await media(action) }
            guard SocialMediaRules.validJPEG(bytes), expectedHash.map({ RecipePhotoService.digest(bytes) == $0 }) ?? true,
                  let image = RemoteMediaCache.decode(bytes, maximumPixels: action.bucket == "profile-photos" ? 360 : 2048)
            else { throw AccountFoundationError.invalidResolution }
            if case .recipeDownload = action { cache?.media.store(bytes, key: byteKey) }
            try Task.checkCancellation()
            cache?.media.storeImage(image, key: key)
            return image
        } catch {
            cache?.media.remove(key)
            cache?.media.remove("\(action.bucket)/\(path)")
            throw error
        }
    }
    /// Also gates non-view callers such as sharing/export before returning cached bytes.
    static func bytes(key: String, action: SocialMediaAction, cache: AccountContentCache,
                      media: @escaping SocialMediaRequest) async throws -> Data {
        do {
            try await requireAccess(action: action, cache: cache, media: media)
            try Task.checkCancellation()
            return try await cache.media.load(key) { try await media(action) }
        } catch {
            cache.media.remove(key)
            throw error
        }
    }
    private static func requireAccess(action: SocialMediaAction, cache: AccountContentCache?,
                                      media: @escaping SocialMediaRequest) async throws {
        guard let path = action.paths.first else { throw AccountFoundationError.invalidResolution }
        if let cache {
            _ = try await cache.coalesced("image-access/\(action.bucket)/\(path)") { try await media(.authorize(bucket: action.bucket, path: path)) }
        } else { _ = try await media(.authorize(bucket: action.bucket, path: path)) }
    }
}

/// Re-entering the app or receiving a privacy/content change requires fresh access.
struct RemoteImageRefresh: ViewModifier {
    @Environment(\.scenePhase) private var phase
    let refresh: () -> Void
    func body(content: Content) -> some View {
        content.onChange(of: phase) { _, next in if next == .active { refresh() } }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in refresh() }
    }
}
