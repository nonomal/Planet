//
//  TemplateBrowserStore.swift
//  Planet
//
//  Created by Livid on 5/3/22.
//

import Foundation
import PlanetSiteTemplates

class TemplateBrowserStore: ObservableObject {
    static let shared = TemplateBrowserStore()

    @Published var templates: [Template] = []

    func loadTemplates() {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: URLUtils.legacyTemplatesPath,
                includingPropertiesForKeys: nil
            )
            let directories = files.filter { $0.hasDirectoryPath }
            var templatesMapping: [String: Template] = [:]
            for directory in directories {
                if let template = Template.from(path: directory) {
                    templatesMapping[template.name] = template
                }
            }
            for builtInTemplate in PlanetSiteTemplates.builtInTemplates {
                var overwriteLocal = false
                if let existingTemplate = templatesMapping[builtInTemplate.name] {
                    if builtInTemplate.version != existingTemplate.version {
                        if existingTemplate.hasGitRepo {
                            debugPrint("Skip updating built-in template \(existingTemplate.name) because it has a git repo")
                        } else {
                            overwriteLocal = true
                        }
                    }
                } else {
                    overwriteLocal = true
                }
                if overwriteLocal {
                    debugPrint("Overwriting local built-in template \(builtInTemplate.name)")
                    let source = builtInTemplate.base!
                    let directoryName = source.lastPathComponent
                    let destination = URLUtils.legacyTemplatesPath.appendingPathComponent(directoryName, isDirectory: true)
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.copyItem(at: source, to: destination)
                    let newTemplate = Template.from(path: destination)!
                    templatesMapping[newTemplate.name] = newTemplate
                }
            }
            templates = Array(templatesMapping.values)
            templates.sort { t1, t2 in
                t1.name < t2.name
            }
            for template in templates {
                template.prepareTemporaryAssetsForPreview()
            }
        } catch {
            debugPrint("Failed to load templates: \(error)")
        }
    }

    func hasTemplate(named name: String) -> Bool {
        templates.contains(where: { $0.name == name })
    }

    subscript(templateID: Template.ID?) -> Template? {
        get {
            if let id = templateID {
                return templates.first(where: { $0.id == id })
            }
            return nil
        }
    }
}
