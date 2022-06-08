import Foundation

class NewArticleDraftModel: Codable, ObservableObject, Hashable {
    let id: UUID
    @Published var title: String
    @Published var content: String
    @Published var attachments: [Attachment]

    // populated when initializing
    weak var planet: MyPlanetModel! = nil

    lazy var basePath = planet.draftsPath.appendingPathComponent(id.uuidString, isDirectory: true)
    lazy var infoPath = basePath.appendingPathComponent("Draft.json", isDirectory: false)
    lazy var attachmentsPath = basePath.appendingPathComponent("Attachments", isDirectory: true)
    // put preview in attachments directory since attachments use relative URL of the same level in HTML
    // example markdown when adding image: [example](example.png)
    lazy var previewPath = attachmentsPath.appendingPathComponent("preview.html", isDirectory: false)

    enum CodingKeys: String, CodingKey {
        case id, title, content, attachments
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        attachments = try container.decode([Attachment].self, forKey: .attachments)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(attachments, forKey: .attachments)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(planet)
    }

    static func ==(lhs: NewArticleDraftModel, rhs: NewArticleDraftModel) -> Bool {
        if lhs === rhs {
            return true
        }
        if type(of: lhs) != type(of: rhs) {
            return false
        }
        if lhs.id != rhs.id {
            return false
        }
        if lhs.planet != rhs.planet {
            return false
        }
        return true
    }

    init(id: UUID, title: String, content: String, attachments: [Attachment]) {
        self.id = id
        self.title = title
        self.content = content
        self.attachments = attachments
    }

    static func load(from directoryPath: URL, planet: MyPlanetModel) throws -> NewArticleDraftModel {
        let draftPath = directoryPath.appendingPathComponent("Draft.json", isDirectory: false)
        let data = try Data(contentsOf: draftPath)
        let draft = try JSONDecoder.shared.decode(NewArticleDraftModel.self, from: data)
        draft.planet = planet
        return draft
    }

    init(planet: MyPlanetModel) throws {
        self.planet = planet

        id = UUID()
        title = ""
        content = ""
        attachments = []

        // initialize article attachments

        try FileManager.default.createDirectory(at: basePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: attachmentsPath, withIntermediateDirectories: true)
    }

    func hasAttachment(name: String) -> Bool {
        attachments.contains(where: { $0.name == name })
    }

    func addAttachment(path: URL) throws {
        let name = path.lastPathComponent
        let targetPath = attachmentsPath.appendingPathComponent(name, isDirectory: false)
        if FileManager.default.fileExists(atPath: targetPath.path) {
            try FileManager.default.removeItem(at: targetPath)
        }
        try FileManager.default.copyItem(at: path, to: targetPath)
        if !hasAttachment(name: name) {
            attachments.append(Attachment(name: name, type: .image, status: .new))
        }
    }

    func deleteAttachment(name: String) {
        if hasAttachment(name: name) {
            attachments.removeAll { $0.name == name }
        }
    }

    func getAttachmentURL(name: String) -> URL? {
        if hasAttachment(name: name) {
            return attachmentsPath.appendingPathComponent(name)
        }
        return nil
    }

    func saveToArticle() throws {
        let article = try MyArticleModel.compose(link: nil, title: title, content: content, planet: planet)
        for attachment in attachments {
            let sourcePath = attachmentsPath.appendingPathComponent(attachment.name, isDirectory: false)
            let targetPath = article.publicBasePath.appendingPathComponent(attachment.name, isDirectory: false)
            try FileManager.default.copyItem(at: sourcePath, to: targetPath)
        }
        planet.articles.insert(article, at: 0)
        article.planet.updated = Date()
        try article.planet.save()
    }

    func save() throws {
        let data = try JSONEncoder.shared.encode(self)
        try data.write(to: infoPath)
    }

    func delete() throws {
        try FileManager.default.removeItem(at: basePath)
    }
}
