import SwiftUI
import Supabase
import ImageIO

nonisolated enum SocialMediaAction: Sendable {
    case upload(path: String, bytes: Data), download(path: String), remove(paths: [String])
    case avatarUpload(path: String, bytes: Data), avatarDownload(path: String), avatarRemove(paths: [String])
    case recipeUpload(path: String, bytes: Data), recipeDownload(path: String), recipeRemove(paths: [String])
    case authorize(bucket: String, path: String), reviewDownload(bucket: String, path: String)
    var isDownload: Bool { switch self { case .download, .avatarDownload, .recipeDownload, .authorize, .reviewDownload: true; default: false } }
    var bucket: String { switch self { case .authorize(let bucket, _), .reviewDownload(let bucket, _): bucket; case .recipeUpload, .recipeDownload, .recipeRemove: "recipe-photos"; case .avatarUpload, .avatarDownload, .avatarRemove: "profile-photos"; default: "social-photos" } }
    var paths: [String] {
        switch self { case .upload(let path, _), .download(let path), .avatarUpload(let path, _), .avatarDownload(let path), .recipeUpload(let path, _), .recipeDownload(let path): [path]; case .authorize(_, let path), .reviewDownload(_, let path): [path]; case .remove(let paths), .avatarRemove(let paths), .recipeRemove(let paths): paths }
    }
}
nonisolated enum SocialMediaRules {
    static let maximumBytes = 2_097_152
    static func validPath(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return parts.count == 2 && UUID(uuidString: String(parts[0])) != nil && parts[1].hasSuffix(".jpg")
            && UUID(uuidString: String(parts[1].dropLast(4))) != nil
    }
    static func validJPEG(_ data: Data) -> Bool {
        guard !data.isEmpty, data.count <= maximumBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceGetType(source) as String? == "public.jpeg",
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return false }
        return width > 0 && height > 0 && width <= 4096 && height <= 4096
    }
}
@MainActor protocol SocialMediaBackend: SocialBackend {
    func socialMedia(_ action: SocialMediaAction) async throws -> Data
}
extension SupabaseAccountBackend: SocialMediaBackend {
    func socialMedia(_ action: SocialMediaAction) async throws -> Data {
        guard let user = client.auth.currentSession?.user.id, action.paths.count <= 25,
              action.paths.allSatisfy(SocialMediaRules.validPath),
              ["social-photos", "profile-photos", "recipe-photos"].contains(action.bucket) else { throw AccountFoundationError.invalidResolution }
        let bucket = client.storage.from(action.bucket)
        let result: Data
        switch action {
        case .authorize(let name, let path):
            struct Parameters: Encodable { let bucket: String; let path: String }
            let response = try await client.schema("api").rpc("image_access", params: Parameters(bucket: name, path: path)).execute()
            guard try JSONDecoder().decode(Bool.self, from: response.data) else { throw AccountFoundationError.invalidResolution }
            result = Data()
        case .reviewDownload(_, let path): result = try await bucket.download(path: path, cacheNonce: UUID().uuidString)
        case .upload(let path, let bytes), .avatarUpload(let path, let bytes):
            guard SocialMediaRules.validJPEG(bytes) else { throw AccountFoundationError.invalidResolution }
            _ = try await bucket.upload(path, data: bytes, options: FileOptions(cacheControl: "0", contentType: "image/jpeg", upsert: true)); result = Data()
        case .recipeUpload(let path, let bytes):
            guard SocialMediaRules.validJPEG(bytes) else { throw AccountFoundationError.invalidResolution }
            do { _ = try await bucket.upload(path, data: bytes, options: FileOptions(cacheControl: "0", contentType: "image/jpeg", upsert: false)) }
            catch let error as StorageError where error.statusCode == "409" { } // Immutable retry; service verifies downloaded hash.
            result = Data()
        case .download(let path), .avatarDownload(let path), .recipeDownload(let path): result = try await bucket.download(path: path, cacheNonce: UUID().uuidString)
        case .remove(let paths), .avatarRemove(let paths), .recipeRemove(let paths): _ = try await bucket.remove(paths: paths); result = Data()
        }
        try Task.checkCancellation()
        guard client.auth.currentSession?.user.id == user else { throw AccountFoundationError.identityChanged }
        return result
    }
}
typealias SocialMediaRequest = @MainActor (SocialMediaAction) async throws -> Data
private struct SocialMediaKey: EnvironmentKey { static let defaultValue: SocialMediaRequest? = nil }
extension EnvironmentValues {
    var socialMedia: SocialMediaRequest? { get { self[SocialMediaKey.self] } set { self[SocialMediaKey.self] = newValue } }
}

struct SocialPhoto: View {
    /// Decode bound for shared photos. Uploads are the ≤1,200 px display rendition, so this never
    /// downsamples them (1,024 px softened full-width cards, about 1,080 px wide at 3×).
    static let maximumPixels = 2_048
    let path: String?
    @Environment(\.socialMedia) private var media
    @Environment(\.accountContentCache) private var cache
    @State private var refresh = UUID()
    @State private var image: UIImage?
    @State private var imagePath: String?
    private var cacheKey: String? { path.map { "post-image/\($0)" } }
    var body: some View {
        Group {
            if let shown = (imagePath == path ? image : nil) { Image(uiImage: shown).resizable().scaledToFill() }
            else { SGPhotoPlaceholder() }
        }.clipped().accessibilityHidden(true)
            .modifier(RemoteImageRefresh { image = nil; imagePath = nil; refresh = UUID() })
            .task(id: "\(path ?? "")/\(refresh)") {
                image = nil; imagePath = nil
                guard let path, let media, let key = cacheKey else { return }
                do {
                    let decoded = try await AuthorizedRemoteImage.load(key: key, action: .download(path: path), cache: cache, media: media)
                    try Task.checkCancellation()
                    image = decoded; imagePath = path
                } catch { if !Task.isCancelled { image = nil } }
            }
    }
}
