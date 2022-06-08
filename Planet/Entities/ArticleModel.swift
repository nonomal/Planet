import Foundation

enum ArticleModel: Equatable, Hashable {
    case myArticle(MyArticleModel)
    case followingArticle(FollowingArticleModel)
}

struct PublicArticleModel: Codable {
    let link: String
    let title: String
    let content: String
    let created: Date
}
