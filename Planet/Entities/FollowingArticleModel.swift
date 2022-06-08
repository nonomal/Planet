import Foundation

class FollowingArticleModel: Codable, Identifiable, Hashable, ObservableObject {
    let id: UUID
    let link: String
    @Published var title: String
    @Published var content: String
    let created: Date
    @Published var read: Date? = nil
    @Published var starred: Date? = nil

    // populated when initializing
    weak var planet: FollowingPlanetModel! = nil

    lazy var path = planet.articlesPath.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    var webviewURL: URL? {
        get async {
            if let linkURL = URL(string: link),
               linkURL.scheme?.lowercased() == "https" {
                return linkURL
            }
            if let cid = planet.cid {
                return URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(cid)/\(link)")
            }
            if let planetLink = URL(string: planet.link) {
                return URL(string: link, relativeTo: planetLink)?.absoluteURL
            }
            return nil
        }
    }
    var browserURL: URL? {
        if let linkURL = URL(string: link),
           linkURL.scheme?.lowercased() == "https" {
            return linkURL
        }
        if let cid = planet.cid {
            return URL(string: "\(IPFSDaemon.publicGateways[0])/ipfs/\(cid)/\(link)")
        }
        if let planetLink = URL(string: planet.link) {
            return URL(string: link, relativeTo: planetLink)?.absoluteURL
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, link, title, content, created, read, starred
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        link = try container.decode(String.self, forKey: .link)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        created = try container.decode(Date.self, forKey: .created)
        read = try container.decodeIfPresent(Date.self, forKey: .read)
        starred = try container.decodeIfPresent(Date.self, forKey: .starred)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(link, forKey: .link)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(created, forKey: .created)
        try container.encodeIfPresent(read, forKey: .read)
        try container.encodeIfPresent(starred, forKey: .starred)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(planet)
    }

    static func ==(lhs: FollowingArticleModel, rhs: FollowingArticleModel) -> Bool {
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

    init(
        id: UUID,
        link: String,
        title: String,
        content: String,
        created: Date,
        read: Date?,
        starred: Date?
    ) {
        self.id = id
        self.link = link
        self.title = title
        self.content = content
        self.created = created
        self.read = read
        self.starred = starred
    }

    static func load(from filePath: URL, planet: FollowingPlanetModel) throws -> FollowingArticleModel {
        let filename = (filePath.lastPathComponent as NSString).deletingPathExtension
        guard let id = UUID(uuidString: filename) else {
            throw PlanetError.PersistenceError
        }
        let articleData = try Data(contentsOf: filePath)
        let article = try JSONDecoder.shared.decode(FollowingArticleModel.self, from: articleData)
        guard article.id == id else {
            throw PlanetError.PersistenceError
        }
        article.planet = planet
        return article
    }

    static func from(publicArticle: PublicArticleModel, planet: FollowingPlanetModel) -> FollowingArticleModel {
        let article = FollowingArticleModel(
            id: UUID(),
            link: publicArticle.link,
            title: publicArticle.title,
            content: publicArticle.content,
            created: publicArticle.created,
            read: nil,
            starred: nil
        )
        article.planet = planet
        return article
    }

    func save() throws {
        let data = try JSONEncoder.shared.encode(self)
        try data.write(to: path)
    }

    func delete() {
        try? FileManager.default.removeItem(at: path)
    }
}
