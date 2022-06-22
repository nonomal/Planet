//
//  URLUtils.swift
//  Planet
//
//  Created by Shu Lyu on 2022-05-07.
//

import Foundation

struct URLUtils {
    static let applicationSupportPath = try! FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )


    static let documentsPath = try! FileManager.default.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )

    static let legacyPlanetsPath = applicationSupportPath.appendingPathComponent("planets", isDirectory: true)

    static let legacyTemplatesPath = applicationSupportPath.appendingPathComponent("templates", isDirectory: true)

    static let legacyDraftPath = applicationSupportPath.appendingPathComponent("drafts", isDirectory: true)

    static let repoPath: URL = {
        let url = documentsPath.appendingPathComponent("Planet", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
}
