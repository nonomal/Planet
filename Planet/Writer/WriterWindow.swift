//
//  PlanetWriterWindow.swift
//  Planet
//
//  Created by Kai on 2/22/22.
//

import SwiftUI

class WriterWindow: NSWindow {
    var draft: DraftModel

    init(draft: DraftModel) {
        self.draft = draft
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.closable, .miniaturizable, .resizable, .titled, .unifiedTitleAndToolbar, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        titleVisibility = .visible
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = false
        toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: "WriterToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        self.toolbar = toolbar
        delegate = self
        isReleasedWhenClosed = false
    }

    @objc func send(_ sender: Any?) {
        NotificationCenter.default.post(name: .sendArticle, object: draft)
    }

    @objc func attachPhoto(_ sender: Any?) {
        NotificationCenter.default.post(name: .attachPhoto, object: draft)
    }
}

extension WriterWindow: NSToolbarDelegate {
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .send:
            let title = NSLocalizedString("Send", comment: "Send")
            return makeToolbarButton(
                itemIdentifier: .send,
                title: title,
                image: NSImage(systemSymbolName: "paperplane", accessibilityDescription: "Send")!,
                selector: "send:"
            )
        case .attachPhoto:
            let title = NSLocalizedString("Attach Picture", comment: "Attach Picture")
            return makeToolbarButton(
                itemIdentifier: .attachPhoto,
                title: title,
                image: NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "Attach Photo")!,
                selector: "attachPhoto:"
            )
        default:
            return nil
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.send, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.send, .attachPhoto]
    }

    func toolbarWillAddItem(_ notification: Notification) {
        guard let _ = notification.userInfo?["item"] as? NSToolbarItem else {
            return
        }
    }

    func toolbarDidRemoveItem(_ notification: Notification) {
        guard let _ = notification.userInfo?["item"] as? NSToolbarItem else {
            return
        }
    }

    func makeToolbarButton(
        itemIdentifier: NSToolbarItem.Identifier,
        title: String,
        image: NSImage,
        selector: String
    ) -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.autovalidates = true

        switch itemIdentifier {
        case .send:
            toolbarItem.isNavigational = true
        default:
            toolbarItem.isNavigational = false
        }

        let button = NSButton()
        button.bezelStyle = .texturedRounded
        button.image = image
        button.imageScaling = .scaleProportionallyDown
        button.action = Selector((selector))

        toolbarItem.view = button
        toolbarItem.toolTip = title
        toolbarItem.label = title
        return toolbarItem
    }
}

extension WriterWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        true
    }

    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.post(name: .closeWriterWindow, object: draft)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        WriterStore.shared.setActiveDraft(draft: draft)
    }
}
