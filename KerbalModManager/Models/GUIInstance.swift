//
//  GUIInstance.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 4/14/25.
//

import AppKit
import CkanAPI
import Collections
import Foundation
import IdentifiedCollections
import Observation

@Observable
final class GUIInstance: Identifiable {
    var id: GameInstance.ID { ckan.id }

    var ckan: GameInstance

    var hasPrepopulatedRegistry = false

    var modules = IdentifiedArray<ModuleId, GUIMod>(id: \.module.id)

    private(set) var compatibleModules = IdentifiedArray<ModuleId, GUIMod>(
        id: \.module.id)

    func index(module: GUIMod) {
        assert(modules.contains(module))

        if module.isCompatible {
            compatibleModules.append(module)
        } else {
            compatibleModules.remove(module)
        }
    }

    private(set) var insights = Insights()

    func copyDirectoryToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ckan.directory.string, forType: .string)
        pasteboard.setString(ckan.fileURL.absoluteString, forType: .fileURL)
    }

    func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([ckan.fileURL])
    }

    func refreshInsights() {
        insights = Insights(for: self)
    }

    init(_ ckanInstance: GameInstance) {
        self.ckan = ckanInstance
    }

    struct Insights {
        var top10Downloads: Set<ModuleId> = []
        var top100Downloads: Set<ModuleId> = []

        init() {}

        init(for instance: GUIInstance) {
            let topDownloads = instance.modules
                .sorted(
                    using:
                        KeyPathComparator(
                            \.currentRelease.downloadCount,
                            order: .reverse)
                )
                .map(\.id)

            top10Downloads = Set(topDownloads.prefix(10))
            top100Downloads = Set(topDownloads.prefix(100))
        }
    }
}

extension GUIInstance: Equatable {
    static func == (lhs: GUIInstance, rhs: GUIInstance) -> Bool {
        lhs.ckan == rhs.ckan
    }
}
