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

@Observable
public final class GUIInstance: Identifiable {
    public var id: GameInstance.ID { ckan.id }

    public var ckan: GameInstance

    public var hasPrepopulatedRegistry = false
    public var compatibleModules = Set<CkanModule.Release.ID>()

    public func copyDirectory() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ckan.directory.string, forType: .string)
        pasteboard.setString(ckan.fileURL.absoluteString, forType: .fileURL)
    }

    public func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([ckan.fileURL])
    }

    init(_ ckanInstance: GameInstance) {
        self.ckan = ckanInstance
    }
}

extension GUIInstance: Equatable {
    public static func == (lhs: GUIInstance, rhs: GUIInstance) -> Bool {
        lhs.ckan == rhs.ckan
    }
}
