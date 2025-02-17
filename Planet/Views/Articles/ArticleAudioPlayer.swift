import SwiftUI

@MainActor class ArticleAudioPlayerViewModel: ObservableObject {
    static let shared = ArticleAudioPlayerViewModel()

    @Published var url: URL?
    @Published var title = ""
}

struct ArticleAudioPlayer: View {
    @ObservedObject var viewModel = ArticleAudioPlayerViewModel.shared

    var body: some View {
        if let url = viewModel.url {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                HStack {
                    AudioPlayer(url: url, title: viewModel.title, isPlaying: true)
                    Button {
                        viewModel.url = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 24, height: 24)
                }
                .padding(.top, 6)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        }
    }
}
