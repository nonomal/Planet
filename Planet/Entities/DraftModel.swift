import Foundation

enum AttachmentStatus: String, Codable {
    case new
    case overwrite
    case existing
    case deleted
}

enum AttachmentType: String, Codable {
    case image
    case video
    case audio
    case file
}

struct Attachment: Codable {
    let name: String
    var type: AttachmentType
    var status: AttachmentStatus
}

enum DraftModel: Equatable, Hashable {
    case editArticleDraft(EditArticleDraftModel)
    case newArticleDraft(NewArticleDraftModel)
}
