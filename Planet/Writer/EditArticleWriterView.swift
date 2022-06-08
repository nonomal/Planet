//
//  PlanetWriterView.swift
//  Planet
//
//  Created by Kai on 2/22/22.
//

import SwiftUI
import Stencil
import PathKit
import WebKit
import Ink

struct EditArticleWriterView: View {
    @ObservedObject var draft: EditArticleDraftModel
    @State var isShowingEmptyTitleAlert: Bool = false
    @State var isMediaTrayOpen = false
    @State var selectedRanges: [NSValue] = []
    @FocusState var focusTitle: Bool
    let dragAndDrop: EditArticleWriterDragAndDrop

    init(draft: EditArticleDraftModel) {
        self.draft = draft
        dragAndDrop = EditArticleWriterDragAndDrop(draft: draft)
    }

    var body: some View {
        VStack (spacing: 0) {
            HStack (spacing: 0) {
                TextField("Title", text: $draft.title)
                    .frame(height: 34, alignment: .leading)
                    .padding(.bottom, 2)
                    .padding(.horizontal, 16)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .background(Color(NSColor.textBackgroundColor))
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($focusTitle)
            }

            Divider()

            HSplitView {
                WriterTextView(text: $draft.content, selectedRanges: $selectedRanges)
                    .frame(minWidth: 200, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
                    .onChange(of: draft.content) { newValue in
                        do {
                            try WriterStore.shared.renderDraft(draft: .editArticleDraft(draft))
                        } catch {
                        }
                        // TODO: refresh
                    }
                    .onChange(of: selectedRanges) { [selectedRanges] newValue in
                        debugPrint("Ranges: \(selectedRanges) -->> \(newValue)")
                    }
                PlanetWriterPreviewView(url: draft.previewPath)
                    .frame(minWidth: 200, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
            }

            if isMediaTrayOpen {
                Divider()
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        // TODO
                    }
                }
                .frame(height: 80)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.03))
                .onDrop(of: [.fileURL], delegate: dragAndDrop)
            }
        }
        .frame(minWidth: 400)
            // TODO: notifications???
        .onAppear {
            if !draft.attachments.isEmpty {
                isMediaTrayOpen = true
            }
            focusTitle = true
        }
        .alert("This article has no title. Please enter the title before clicking send.", isPresented: $isShowingEmptyTitleAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private func cancelAction() {
        // TODO
    }

    private func attachPhotoAction() {
        // TODO
    }

    private func saveAction() {
        // TODO
    }

    private func updateAction() {
        // TODO
    }

    private func uploadImagesAction() -> [URL]? {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.jpeg, .png, .pdf, .tiff, .gif]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.message = "Please choose images to upload."
        openPanel.prompt = "Choose"
        let response = openPanel.runModal()
        return response == .OK ? openPanel.urls : nil
    }
}
