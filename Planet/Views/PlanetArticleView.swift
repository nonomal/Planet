import SwiftUI

struct PlanetArticleView: View {
    static let noSelectionURL = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!
    @EnvironmentObject var planetStore: PlanetStore

    @State private var url = Self.noSelectionURL

    var body: some View {
        VStack {
            PlanetArticleWebView(url: $url)
        }
        .background(
            Color(NSColor.textBackgroundColor)
        )
        .onChange(of: planetStore.selectedArticle) { newArticle in
            Task.init {
                switch newArticle {
                case .myArticle(let myArticle):
                    url = myArticle.publicIndexPath
                case .followingArticle(let followingArticle):
                    if let webviewURL = await followingArticle.webviewURL {
                        url = webviewURL
                    } else {
                        url = Self.noSelectionURL
                    }
                default:
                    url = Self.noSelectionURL
                }
                NotificationCenter.default.post(name: .loadArticle, object: nil)
            }
        }
        .onChange(of: planetStore.selectedView) { _ in
            url = Self.noSelectionURL
            NotificationCenter.default.post(name: .loadArticle, object: nil)
        }
    }
}
