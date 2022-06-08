import Foundation
import SwiftUI

class EditArticleWriterDragAndDrop: ObservableObject, DropDelegate {
    @ObservedObject var draft: EditArticleDraftModel

    init(draft: EditArticleDraftModel) {
        self.draft = draft
    }

    func dropEntered(info: DropInfo) {
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard let _ = info.itemProviders(for: [.fileURL]).first else { return false }
        return true
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL])
        let supportedExtensions: [String] = ["png", "jpeg", "gif", "tiff", "jpg"]
        Task.detached {
            for provider in providers {
                if let item = try? await provider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil),
                   let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil),
                   supportedExtensions.contains(url.pathExtension) {
                    try await self.draft.addAttachment(path: url)
                }
            }
        }
        return true
    }
}

class NewArticleWriterDragAndDrop: ObservableObject, DropDelegate {
    @ObservedObject var draft: NewArticleDraftModel

    init(draft: NewArticleDraftModel) {
        self.draft = draft
    }

    func dropEntered(info: DropInfo) {
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard let _ = info.itemProviders(for: [.fileURL]).first else { return false }
        return true
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL])
        let supportedExtensions: [String] = ["png", "jpeg", "gif", "tiff", "jpg"]
        Task.detached {
            for provider in providers {
                if let item = try? await provider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil),
                   let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil),
                   supportedExtensions.contains(url.pathExtension) {
                    try await self.draft.addAttachment(path: url)
                }
            }
        }
        return true
    }
}
