import Foundation

enum PlanetModel: Equatable, Hashable {
    case myPlanet(MyPlanetModel)
    case followingPlanet(FollowingPlanetModel)
}

struct PublicPlanetModel: Codable {
    var name: String
    var about: String
    let ipns: String
    let created: Date
    var updated: Date
    var articles: [PublicArticleModel]
}
