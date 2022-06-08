import Foundation

class MyArticleModel: Codable, Identifiable, Hashable, ObservableObject {
    let id: UUID
    @Published var link: String
    @Published var title: String
    @Published var content: String
    let created: Date
    @Published var starred: Date? = nil

    // populated when initializing
    weak var planet: MyPlanetModel! = nil
    var draft: EditArticleDraftModel? = nil

    lazy var path = planet.articlesPath.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    lazy var publicBasePath = planet.publicBasePath.appendingPathComponent(id.uuidString, isDirectory: true)
    lazy var publicIndexPath = publicBasePath.appendingPathComponent("index.html")

    var publicArticle: PublicArticleModel {
        PublicArticleModel(link: link, title: title, content: content, created: created)
    }
    var browserURL: URL? {
        URL(string: "\(IPFSDaemon.publicGateways[0])/ipns/\(planet.ipns)/\(link)/")
    }

    enum CodingKeys: String, CodingKey {
        case id, link, title, content, created, starred
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        link = try container.decode(String.self, forKey: .link)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        created = try container.decode(Date.self, forKey: .created)
        starred = try container.decodeIfPresent(Date.self, forKey: .starred)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(link, forKey: .link)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(created, forKey: .created)
        try container.encodeIfPresent(starred, forKey: .starred)
    }

    static func ==(lhs: MyArticleModel, rhs: MyArticleModel) -> Bool {
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(planet)
    }

    init(id: UUID, link: String, title: String, content: String, created: Date) {
        self.id = id
        self.link = link
        self.title = title
        self.content = content
        self.created = created
    }

    static func load(from filePath: URL, planet: MyPlanetModel) throws -> MyArticleModel {
        let filename = (filePath.lastPathComponent as NSString).deletingPathExtension
        guard let id = UUID(uuidString: filename) else {
            throw PlanetError.PersistenceError
        }
        let articleData = try Data(contentsOf: filePath)
        let article = try JSONDecoder.shared.decode(MyArticleModel.self, from: articleData)
        guard article.id == id else {
            throw PlanetError.PersistenceError
        }
        article.planet = planet
        let draftPath = planet.articleDraftsPath.appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: draftPath.path) {
            article.draft = try EditArticleDraftModel.load(from: draftPath, article: article)
        }
        return article
    }

    static func compose(link: String?, title: String, content: String, planet: MyPlanetModel) throws -> MyArticleModel {
        let id = UUID()
        let article = MyArticleModel(
            id: id,
            link: link ?? id.uuidString,
            title: title,
            content: content,
            created: Date()
        )
        article.planet = planet
        try FileManager.default.createDirectory(at: article.publicBasePath, withIntermediateDirectories: true)
        return article
    }

    func save() throws {
        let data = try JSONEncoder.shared.encode(self)
        try data.write(to: path)
    }

    func delete() {
        try? FileManager.default.removeItem(at: path)
        // try? FileManager.default.removeItem(at: publicBasePath)
    }
}

struct BackupArticleModel: Codable {
    let id: UUID
    let link: String
    let title: String
    let content: String
    let created: Date
}
