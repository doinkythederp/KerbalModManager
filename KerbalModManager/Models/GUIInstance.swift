//
//  GUIInstance.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 4/14/25.
//

import Foundation
import Observation
import CkanAPI
import AppKit
import Collections
import IdentifiedCollections

@Observable
final class GUIInstance: Identifiable {
    var id: GameInstance.ID { ckan.id }

    var ckan: GameInstance

    var hasPrepopulatedRegistry = false
    
    var modules = IdentifiedArray<String, GUIMod>(id: \.module.id)
    
    private(set) var compatibleModules = IdentifiedArray<String, GUIMod>(id: \.module.id)
    
    func index(module: GUIMod) {
        assert(modules.contains(module))
        
        if module.isCompatible {
            compatibleModules.append(module)
        } else {
            compatibleModules.remove(module)
        }
    }

    func copyDirectory() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ckan.directory.string, forType: .string)
        pasteboard.setString(ckan.fileURL.absoluteString, forType: .fileURL)
    }

    func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([ckan.fileURL])
    }

    init(_ ckanInstance: GameInstance) {
        self.ckan = ckanInstance
    }
}

extension GUIInstance: Equatable {
    static func == (lhs: GUIInstance, rhs: GUIInstance) -> Bool {
        lhs.ckan == rhs.ckan
    }
}
