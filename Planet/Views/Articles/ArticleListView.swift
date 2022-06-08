import SwiftUI

struct ArticleListView: View {
    @EnvironmentObject var planetStore: PlanetStore

    var articles: [ArticleModel]

    var body: some View {
        VStack {
            if articles.isEmpty {
                Text("No articles.")
            } else {
                List(articles, id: \.self, selection: $planetStore.selectedArticle) { article in
                    switch article {
                    case .myArticle(let myArticle):
                        MyArticleItemView(article: myArticle)
                    case .followingArticle(let followingArticle):
                        FollowingArticleItemView(article: followingArticle)
                    }
                }
            }
        }
            // .toolbar {
            //     // TODO: Content Type Switcher will go here
            //     Spacer()
            // }
            // .navigationTitle(
            //     // TODO: smart feed type enum
            // )
            // .navigationSubtitle(
            //     // TODO: smart feed type enum
            // )

    }
}
