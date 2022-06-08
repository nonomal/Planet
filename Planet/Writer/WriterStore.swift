import Foundation
import Stencil
import PathKit
import Ink

class WriterStore: ObservableObject {
    static let shared = WriterStore()

    let previewRenderEnv: Stencil.Environment
    let writerTemplateName: String

    @Published var writers: [DraftModel: WriterWindow] = [:]
    @Published var activeDraft: DraftModel? = nil

    init() {
        let writerTemplatePath = Bundle.main.url(forResource: "WriterBasic", withExtension: "html")!
        previewRenderEnv = Environment(
            loader: FileSystemLoader(paths: [Path(writerTemplatePath.path)]),
            extensions: [StencilExtension.get()]
        )
        writerTemplateName = writerTemplatePath.lastPathComponent
    }

    func newArticle(for planet: MyPlanetModel) {
        // writerWindow.center()
        // writerWindow.contentView = NSHostingView(rootView: writerView)
        // writerWindow.makeKeyAndOrderFront(nil)
    }

    func editArticle(article: MyArticleModel) {
        // writerWindow.center()
        // writerWindow.contentView = NSHostingView(rootView: writerView)
        // writerWindow.makeKeyAndOrderFront(nil)
    }

    func guessAttachmentType(path: URL) -> AttachmentType {
        let fileExtension = path.pathExtension
        if ["jpg", "jpeg", "png", "tiff", "gif"].contains(fileExtension) {
            return .image
        }
        return .file
    }

    func addAttachments(files: [URL]) throws {
        switch activeDraft {
        case .newArticleDraft(let draft):
            try files.forEach { try draft.addAttachment(path: $0) }
        case .editArticleDraft(let draft):
            try files.forEach { try draft.addAttachment(path: $0) }
        default:
            return
        }
    }

    func setActiveDraft(draft: DraftModel) {
        activeDraft = draft
    }

    func renderDraft(draft: DraftModel) throws {
        let content: String
        let previewPath: URL
        switch draft {
        case .newArticleDraft(let draft):
            content = draft.content
            previewPath = draft.previewPath
        case .editArticleDraft(let draft):
            content = draft.content
            previewPath = draft.previewPath
        }

        let html = MarkdownParser().html(from: content.trim())
        let output = try previewRenderEnv.renderTemplate(name: writerTemplateName, context: ["content_html": html])
        try output.data(using: .utf8)?.write(to: previewPath)
    }
}
