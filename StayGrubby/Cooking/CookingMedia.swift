import Foundation
import SwiftData

nonisolated enum CookingMediaKind: String {
    case image
}

/// File-backed images owned by one actual cook; bounded ordered collections
/// reuse existing identities, private file variants and restoration.
@Model
final class CookingMedia {
    @Attribute(.unique) var id: UUID
    var kindCode: String
    var displayFilename: String
    var thumbnailFilename: String
    var pixelWidth: Int
    var pixelHeight: Int
    var sortOrder: Int
    var createdAt: Date
    var attempt: CookingAttempt?

    var kind: CookingMediaKind { CookingMediaKind(rawValue: kindCode) ?? .image }

    init(id: UUID, displayFilename: String, thumbnailFilename: String,
         pixelWidth: Int, pixelHeight: Int, sortOrder: Int = 0) {
        self.id = id
        kindCode = CookingMediaKind.image.rawValue
        self.displayFilename = displayFilename
        self.thumbnailFilename = thumbnailFilename
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.sortOrder = sortOrder
        createdAt = .now
    }
}
