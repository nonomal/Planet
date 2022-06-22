import Foundation
import os
import SwiftUI

enum PlanetType: Int, Codable {
    case planet = 0
    case ens = 1
    case dnslink = 2
    case dns = 3
}

class FollowingPlanetModel: Codable, Identifiable, Hashable, ObservableObject {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MyPlanet")

    let id: UUID
    let planetType: PlanetType
    @Published var name: String
    @Published var about: String
    let link: String
    @Published var cid: String?
    let created: Date
    @Published var updated: Date
    @Published var lastLocalUpdate: Date

    @Published var isUpdating = false

    // populated when initializing
    @Published var articles: [FollowingArticleModel]! = nil
    @Published var avatar: NSImage? = nil

    static let followingPlanetsPath: URL = {
        // ~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planets/Following/
        let url = URLUtils.repoPath.appendingPathComponent("Following", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    lazy var basePath = Self.followingPlanetsPath.appendingPathComponent(id.uuidString, isDirectory: true)
    lazy var infoPath = basePath.appendingPathComponent("Planet.json", isDirectory: false)
    lazy var articlesPath = basePath.appendingPathComponent("Articles", isDirectory: true)
    lazy var avatarPath = basePath.appendingPathComponent("Avatar.png", isDirectory: false)

    var nameInitials: String {
        let initials = name.components(separatedBy: .whitespaces).map { $0.prefix(1).capitalized }.joined()
        return String(initials.prefix(2))
    }
    var webviewURL: URL? {
        get async {
            if let cid = cid {
                return URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(cid)")
            }
            return URL(string: link)
        }
    }
    var browserURL: URL? {
        if let cid = cid {
            return URL(string: "\(IPFSDaemon.publicGateways[0])/ipfs/\(cid)")
        }
        return URL(string: link)
    }

    enum CodingKeys: String, CodingKey {
        case id, planetType, name, about, link, cid, created, updated, lastLocalUpdate
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        planetType = try container.decode(PlanetType.self, forKey: .planetType)
        name = try container.decode(String.self, forKey: .name)
        about = try container.decode(String.self, forKey: .about)
        link = try container.decode(String.self, forKey: .link)
        cid = try container.decode(String?.self, forKey: .cid)
        created = try container.decode(Date.self, forKey: .created)
        updated = try container.decode(Date.self, forKey: .updated)
        lastLocalUpdate = try container.decode(Date.self, forKey: .lastLocalUpdate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(planetType, forKey: .planetType)
        try container.encode(name, forKey: .name)
        try container.encode(about, forKey: .about)
        try container.encode(link, forKey: .link)
        try container.encode(cid, forKey: .cid)
        try container.encode(created, forKey: .created)
        try container.encode(updated, forKey: .updated)
        try container.encode(lastLocalUpdate, forKey: .lastLocalUpdate)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func ==(lhs: FollowingPlanetModel, rhs: FollowingPlanetModel) -> Bool {
        if lhs === rhs {
            return true
        }
        if type(of: lhs) != type(of: rhs) {
            return false
        }
        if lhs.id != rhs.id {
            return false
        }
        return true
    }

    init(
        id: UUID,
        planetType: PlanetType,
        name: String,
        about: String,
        link: String,
        cid: String?,
        created: Date,
        updated: Date,
        lastLocalUpdate: Date
    ) {
        self.id = id
        self.planetType = planetType
        self.name = name
        self.about = about
        self.link = link
        self.cid = cid
        self.created = created
        self.updated = updated
        self.lastLocalUpdate = lastLocalUpdate
    }

    static func load(from directoryPath: URL) throws -> FollowingPlanetModel {
        let planetPath = directoryPath.appendingPathComponent("Planet.json", isDirectory: false)
        guard let planetID = UUID(uuidString: planetPath.lastPathComponent) else {
            // directory name is not a UUID
            throw PlanetError.PersistenceError
        }
        let planetData = try Data(contentsOf: planetPath)
        let planet = try JSONDecoder.shared.decode(FollowingPlanetModel.self, from: planetData)
        guard planet.id == planetID else {
            // directory UUID does not match planet json UUID
            throw PlanetError.PersistenceError
        }
        let articleDirectory = directoryPath.appendingPathComponent("Articles", isDirectory: true)
        let articleFiles = try FileManager.default.contentsOfDirectory(
            at: articleDirectory,
            includingPropertiesForKeys: nil
        )
        planet.articles = articleFiles.compactMap { try? FollowingArticleModel.load(from: $0, planet: planet) }
        planet.avatar = NSImage(contentsOf: planet.avatarPath)
        return planet
    }

    static func follow(link: String) async throws -> FollowingPlanetModel {
        if link.hasSuffix(".eth") {
            guard let cid = try await ENSUtils.getCID(ens: link) else {
                throw PlanetError.InvalidPlanetURLError
            }
            Self.logger.info("Follow \(link): CID \(cid)")
            Task {
                try await IPFSDaemon.shared.pin(cid: cid)
            }
            // update a native planet if a public planet is found
            if let planetURL = URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(cid)/planet.json"),
               let (planetData, planetResponse) = try? await URLSession.shared.data(from: planetURL),
               let httpResponse = planetResponse as? HTTPURLResponse,
               httpResponse.ok ,
               let publicPlanet = try? JSONDecoder.shared.decode(PublicPlanetModel.self, from: planetData) {

                let planet = FollowingPlanetModel(
                    id: UUID(),
                    planetType: .ens,
                    name: publicPlanet.name,
                    about: publicPlanet.about,
                    link: link,
                    cid: cid,
                    created: publicPlanet.created,
                    updated: publicPlanet.updated,
                    lastLocalUpdate: Date()
                )

                try FileManager.default.createDirectory(at: planet.basePath, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: planet.articlesPath, withIntermediateDirectories: true)

                planet.articles = publicPlanet.articles.map {
                    FollowingArticleModel.from(publicArticle: $0, planet: planet)
                }

                // try to find ENS avatar
                if let data = try? await ENSUtils.shared.avatar(name: link),
                   let image = NSImage(data: data),
                   let _ = try? data.write(to: planet.avatarPath) {
                    planet.avatar = image
                } else
                // try to find native planet avatar
                if let planetAvatarURL = URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(cid)/avatar.png"),
                   let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
                   let httpResponse = response as? HTTPURLResponse,
                   httpResponse.ok,
                   let image = NSImage(data: data),
                   let _ = try? data.write(to: planet.avatarPath) {
                    planet.avatar = image
                }

                try planet.save()
                return planet
            }
            // did not get published planet file, try to get feed
            guard let feedURL = URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(cid)"),
                  let feedData = try await FeedUtils.findFeed(url: feedURL) else {
                throw PlanetError.InvalidPlanetURLError
            }
            let feed = try FeedUtils.parseFeed(data: feedData)
            let now = Date()
            let planet = FollowingPlanetModel(
                id: UUID(),
                planetType: .ens,
                name: feed.name ?? link,
                about: feed.about ?? "",
                link: link,
                cid: cid,
                created: now,
                updated: now,
                lastLocalUpdate: now
            )

            try FileManager.default.createDirectory(at: planet.basePath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: planet.articlesPath, withIntermediateDirectories: true)

            if let publicArticles = feed.articles {
                planet.articles = publicArticles.map {
                    FollowingArticleModel.from(publicArticle: $0, planet: planet)
                }
            } else {
                planet.articles = []
            }

            if let data = feed.avatar,
               let image = NSImage(data: data),
               let _ = try? data.write(to: planet.avatarPath) {
                planet.avatar = image
            }

            try planet.save()
            return planet
        } else if link.hasPrefix("https://") {
            guard let feedURL = URL(string: link),
                  let feedData = try await FeedUtils.findFeed(url: feedURL) else {
                throw PlanetError.InvalidPlanetURLError
            }
            let feed = try FeedUtils.parseFeed(data: feedData)
            let now = Date()
            let planet = FollowingPlanetModel(
                id: UUID(),
                planetType: .dns,
                name: feed.name ?? link,
                about: feed.about ?? "",
                link: link,
                cid: nil,
                created: now,
                updated: now,
                lastLocalUpdate: now
            )
            try FileManager.default.createDirectory(at: planet.basePath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: planet.articlesPath, withIntermediateDirectories: true)

            if let publicArticles = feed.articles {
                planet.articles = publicArticles.map {
                    FollowingArticleModel.from(publicArticle: $0, planet: planet)
                }
            } else {
                planet.articles = []
            }

            if let data = feed.avatar,
               let image = NSImage(data: data),
               let _ = try? data.write(to: planet.avatarPath) {
                planet.avatar = image
            }

            try planet.save()
            return planet
        } else if link.hasPrefix("k") {
            let cidWithPrefix = try await IPFSDaemon.shared.resolveIPNS(ipns: link)
            guard cidWithPrefix.hasPrefix("/ipfs/") else {
                throw PlanetError.InvalidPlanetURLError
            }
            let cid = cidWithPrefix.removePrefix(until: 6)
            Self.logger.info("Follow \(link): CID \(cid)")
            Task {
                try await IPFSDaemon.shared.pin(cid: cid)
            }
            let planetURL = URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(cid)/planet.json")!
            let (planetData, planetResponse) = try await URLSession.shared.data(from: planetURL)
            guard let httpResponse = planetResponse as? HTTPURLResponse,
                  httpResponse.ok
            else {
                throw PlanetError.NetworkError
            }
            let publicPlanet = try JSONDecoder.shared.decode(PublicPlanetModel.self, from: planetData)
            let planet = FollowingPlanetModel(
                id: UUID(),
                planetType: .planet,
                name: publicPlanet.name,
                about: publicPlanet.about,
                link: link,
                cid: cid,
                created: publicPlanet.created,
                updated: publicPlanet.updated,
                lastLocalUpdate: Date()
            )

            try FileManager.default.createDirectory(at: planet.basePath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: planet.articlesPath, withIntermediateDirectories: true)

            planet.articles = publicPlanet.articles.map {
                FollowingArticleModel.from(publicArticle: $0, planet: planet)
            }

            if let planetAvatarURL = URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(cid)/avatar.png"),
               let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.ok,
               let image = NSImage(data: data),
               let _ = try? data.write(to: planet.avatarPath) {
                planet.avatar = image
            }

            try planet.save()
            return planet
        }
        throw PlanetError.InvalidPlanetURLError
    }

    func update() async throws {
        Self.logger.info("Updating planet \(self.name)")
        isUpdating = true
        defer {
            isUpdating = false
        }
        switch planetType {
        case .planet:
            let cidWithPrefix = try await IPFSDaemon.shared.resolveIPNS(ipns: link)
            guard cidWithPrefix.hasPrefix("/ipfs/") else {
                throw PlanetError.InvalidPlanetURLError
            }
            let newCID = cidWithPrefix.removePrefix(until: 6)
            if cid == newCID {
                Self.logger.info("Planet \(self.name) has no update")
                return
            }
            Task {
                try await IPFSDaemon.shared.pin(cid: newCID)
                if let oldCid = cid {
                    try await IPFSDaemon.shared.unpin(cid: oldCid)
                }
            }
            let planetURL = URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(newCID)/planet.json")!
            let (planetData, planetResponse) = try await URLSession.shared.data(from: planetURL)
            if let httpResponse = planetResponse as? HTTPURLResponse,
               httpResponse.ok {
                let publicPlanet = try JSONDecoder.shared.decode(PublicPlanetModel.self, from: planetData)
                name = publicPlanet.name
                about = publicPlanet.about
                updated = publicPlanet.updated
                try updateArticles(publicArticles: publicPlanet.articles, delete: true)
                cid = newCID
                lastLocalUpdate = Date()

                if let planetAvatarURL = URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(newCID)/avatar.png"),
                   let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
                   let httpResponse = response as? HTTPURLResponse,
                   httpResponse.ok,
                   let image = NSImage(data: data),
                   let _ = try? data.write(to: avatarPath) {
                    avatar = image
                }

                try save()
                return
            }
            throw PlanetError.PlanetFeedError
        case .ens:
            guard let newCID = try await ENSUtils.getCID(ens: link) else {
                throw PlanetError.InvalidPlanetURLError
            }
            if cid == newCID {
                Self.logger.info("Planet \(self.name) has no update")
                return
            }
            Task {
                try await IPFSDaemon.shared.pin(cid: newCID)
                if let oldCid = cid {
                    try await IPFSDaemon.shared.unpin(cid: oldCid)
                }
            }
            do {
                let planetURL = URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(newCID)/planet.json")!
                let (planetData, planetResponse) = try await URLSession.shared.data(from: planetURL)
                if let httpResponse = planetResponse as? HTTPURLResponse,
                   httpResponse.ok {
                    let publicPlanet = try JSONDecoder.shared.decode(PublicPlanetModel.self, from: planetData)
                    name = publicPlanet.name
                    about = publicPlanet.about
                    updated = publicPlanet.updated

                    try updateArticles(publicArticles: publicPlanet.articles, delete: true)

                    if let data = try? await ENSUtils.shared.avatar(name: link),
                       let image = NSImage(data: data),
                       let _ = try? data.write(to: avatarPath) {
                        avatar = image
                    } else
                    if let planetAvatarURL = URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(newCID)/avatar.png"),
                       let (data, response) = try? await URLSession.shared.data(from: planetAvatarURL),
                       let httpResponse = response as? HTTPURLResponse,
                       httpResponse.ok,
                       let image = NSImage(data: data),
                       let _ = try? data.write(to: avatarPath) {
                        avatar = image
                    }

                    cid = newCID
                    lastLocalUpdate = Date()

                    try save()
                    return
                }
            } catch {
                // ignore
            }
            // did not get published planet file, try to get feed
            let feedURL = URL(string: "\(await IPFSDaemon.shared.gateway)/ipfs/\(newCID)")!
            guard let feedData = try await FeedUtils.findFeed(url: feedURL) else {
                throw PlanetError.InvalidPlanetURLError
            }
            let feed = try FeedUtils.parseFeed(data: feedData)
            let now = Date()

            name = feed.name ?? link
            about = feed.about ?? ""
            updated = now
            lastLocalUpdate = now

            if let publicArticles = feed.articles {
                try updateArticles(publicArticles: publicArticles)
            }

            if let data = feed.avatar,
               let image = NSImage(data: data),
               let _ = try? data.write(to: avatarPath) {
                avatar = image
            }

            try save()
            return
        case .dnslink:
            // not implemented yet
            throw PlanetError.InternalError
        case .dns:
            guard let feedURL = URL(string: link),
                  let feedData = try await FeedUtils.findFeed(url: feedURL) else {
                throw PlanetError.PlanetFeedError
            }
            let feed = try FeedUtils.parseFeed(data: feedData)
            let now = Date()
            name = feed.name ?? link
            about = feed.about ?? ""
            updated = now
            lastLocalUpdate = now

            if let publicArticles = feed.articles {
                try updateArticles(publicArticles: publicArticles)
            }

            if let data = feed.avatar,
               let image = NSImage(data: data),
               let _ = try? data.write(to: avatarPath) {
                avatar = image
            }

            try save()
            return
        }
    }

    func updateArticles(publicArticles: [PublicArticleModel], delete: Bool = false) throws {
        // planet file will have all the articles, so delete a planet article if it is no longer presented
        // feed will rollover old articles, so retain the article even if it is not in feed
        var existingArticleMap: [String: FollowingArticleModel] = [:]
        for existingArticle in articles {
            existingArticleMap[existingArticle.link] = existingArticle
        }

        for publicArticle in publicArticles {
            let link = publicArticle.link
            if let article = existingArticleMap[link] {
                // update
                article.title = publicArticle.title
                article.content = publicArticle.content
                existingArticleMap.removeValue(forKey: link)
            } else {
                // created
                articles.append(FollowingArticleModel.from(publicArticle: publicArticle, planet: self))
            }
        }
        if delete {
            articles.removeAll { existingArticleMap[$0.link] != nil }
            existingArticleMap.values.forEach { $0.delete() }
        }
        articles.sort { $0.created > $1.created }
    }

    func save() throws {
        let data = try JSONEncoder.shared.encode(self)
        try data.write(to: infoPath)
        articles.forEach { try? $0.save() }
    }

    func delete() {
        try? FileManager.default.removeItem(at: basePath)
    }
}
