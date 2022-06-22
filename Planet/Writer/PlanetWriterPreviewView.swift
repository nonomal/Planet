//
//  PlanetWriterPreviewView.swift
//  Planet
//
//  Created by Kai on 3/30/22.
//

import SwiftUI


struct PlanetWriterPreviewView: View {
    var url: URL?

    var body: some View {
        VStack {
            WriterWebView(url: url == nil ? Bundle.main.url(forResource: "WriterBasicPlaceholder", withExtension: "html")! : url!)
        }.background(Color(NSColor.textBackgroundColor))
    }
}
