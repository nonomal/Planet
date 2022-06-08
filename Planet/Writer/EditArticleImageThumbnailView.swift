import SwiftUI

struct EditArticleImageThumbnailView: View {
    @ObservedObject var draft: EditArticleDraftModel
    @State var attachmentImage: NSImage?
    @State var attachment: Attachment

    @State private var isShowingPlusIcon = false

    var body: some View {
        ZStack {
            if let image = attachmentImage,
               let resizedImage = image.resizeSquare(maxLength: 60) {
                Image(nsImage: resizedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 4)
                    .frame(width: 60, height: 60, alignment: .center)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18, alignment: .center)
                        .opacity(isShowingPlusIcon ? 1.0 : 0.0)
                    Spacer()
                }
                Spacer()
            }
            .padding(4)
            .onTapGesture {
                // TODO: missing insert file, need a way to get current selection
            }

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12, alignment: .center)
                        .opacity(isShowingPlusIcon ? 1.0 : 0.0)
                        .onTapGesture {
                            // TODO: delete attachment in draft
                        }
                }
                Spacer()
            }
            .padding(.leading, 0)
            .padding(.top, 2)
            .padding(.trailing, -8)
        }
        .frame(width: 60, height: 60, alignment: .center)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .onHover { isHovering in
            withAnimation {
                isShowingPlusIcon = isHovering
            }
        }
    }
}
