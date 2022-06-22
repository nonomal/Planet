import SwiftUI

struct FollowingArticleItemView: View {
    @ObservedObject var article: FollowingArticleModel

    var body: some View {
        HStack {
            VStack {
                if article.starred != nil {
                    Image(systemName: "star.fill")
                        .renderingMode(.original)
                        .frame(width: 8, height: 8)
                        .padding(.all, 4)
                } else {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .padding(.all, 4)
                        .visibility(article.read == nil ? .visible : .invisible)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(article.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                HStack {
                    Text(article.created.mmddyyyy())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
            .contentShape(Rectangle())
            .contextMenu {
                VStack {
                    Button {
                        if article.read == nil {
                            article.read = Date()
                        } else {
                            article.read = nil
                        }
                    } label: {
                        Text(article.read == nil ? "Mark as Read" : "Mark as Unread")
                    }
                    Button {
                        if article.starred == nil {
                            article.starred = Date()
                        } else {
                            article.starred = nil
                        }
                    } label: {
                        Text(article.starred == nil ? "Star" : "Unstar")
                    }
                    Button {
                        if let url = article.browserURL {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.absoluteString, forType: .string)
                        }
                    } label: {
                        Text("Copy Public Link")
                    }
                    Button {
                        if let url = article.browserURL {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Open in Browser")
                    }
                }
            }
    }
}
