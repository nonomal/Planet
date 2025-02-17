//
//  PlanetDownloadsWindowController.swift
//  Planet
//
//  Created by Kai on 8/1/22.
//

import Cocoa


class PlanetDownloadsWindowController: NSWindowController {
    override init(window: NSWindow?) {
        let windowSize = NSSize(width: 320, height: 480)
        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(screenSize.width/2 - windowSize.width/2, screenSize.height/2 - windowSize.height/2, windowSize.width, windowSize.height)
        let w = PlanetDownloadsWindow(contentRect: rect, styleMask: [], backing: .buffered, defer: true)
        super.init(window: w)
        self.window?.setFrameAutosaveName("Planet Downloads Window")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


