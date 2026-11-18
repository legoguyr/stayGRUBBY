import SwiftUI
import CryptoKit

/// Permission is refreshed before memory/disk reuse. Denied cached bytes never render.
@MainActor enum AuthorizedRemoteImage {
    static func load(key: String, action: SocialMediaAction, expectedHash: String? = nil,
                     cache: AccountContentCache?, media: @escaping SocialMediaRequest) async throws -> UIImage {
        guard let path = action.paths.first else { throw AccountFoundationError.invalidResolution }
        do {
            let byteKey = "\(action.bucket)/\(path)"
            var cachedImage = cache?.media.image(key)
            var cachedBytes = cache?.media.data(byteKey)
            if cachedImage != nil || cachedBytes != nil {
                if try await !requireAccess(action: action, cache: cache, media: media) {
                    // No server permission check: never trust the cache; a fresh Storage download decides.
                    cachedImage = nil; cachedBytes = nil
                }
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
            // A download that isn't cached is authorized by Storage itself, so only a cache hit needs the
            // separate permission read (one round trip saved per cold photo, and no dependency on it).
            if cache.media.data(key) != nil {
                if try await !requireAccess(action: action, cache: cache, media: media) {
                    cache.media.remove(key)
                }
                try Task.checkCancellation()
            }
            return try await cache.media.load(key) { try await media(action) }
        } catch {
            cache.media.remove(key)
            throw error
        }
    }
    /// True when the server confirmed access; false when this server has no permission check
    /// (`api.image_access` not deployed), so the caller must re-download instead of reusing the cache.
    /// Throws when access is denied or the check fails.
    private static func requireAccess(action: SocialMediaAction, cache: AccountContentCache?,
                                      media: @escaping SocialMediaRequest) async throws -> Bool {
        guard let path = action.paths.first else { throw AccountFoundationError.invalidResolution }
        if ImageAccessCheck.unavailableThisSession { return false }
        do {
            if let cache {
                _ = try await cache.coalesced("image-access/\(action.bucket)/\(path)") { try await media(.authorize(bucket: action.bucket, path: path)) }
            } else { _ = try await media(.authorize(bucket: action.bucket, path: path)) }
            return true
        } catch is ImageAccessCheck.Unavailable {
            ImageAccessCheck.unavailableThisSession = true
            return false
        }
    }
}

/// The server-side permission read that gates cache reuse (`api.image_access`).
@MainActor enum ImageAccessCheck {
    /// The hosted project doesn't have the function yet (pending migration).
    struct Unavailable: Error {}
    /// Remembered for the session so a missing function costs one failed request, not one per photo.
    static var unavailableThisSession = false
    /// PostgREST "function not in schema cache" or PostgreSQL undefined_function.
    nonisolated static func isMissingFunction(code: String?) -> Bool { code == "PGRST202" || code == "42883" }
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
