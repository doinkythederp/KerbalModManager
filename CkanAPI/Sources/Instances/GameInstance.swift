//
//  GameInstance.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/3/25.
//

import System
import Foundation
import AppKit
import IdentifiedCollections

@Observable
public final class GameInstance: Identifiable, Equatable {
    public static func == (lhs: GameInstance, rhs: GameInstance) -> Bool {
        lhs.id == rhs.id
    }

    public var id = UUID()
    public private(set) var name: String
    public var directory: FilePath
    public var game: Game
    public var version: GameVersion
    public var isDefault: Bool

    public var hasPrepopulatedRegistry = false
    public var compatibleModules: IdentifiedArrayOf<CkanModule> = []

    public var fileURL: URL {
        URL(filePath: directory)!
    }

    public func rename(_ newName: String) {
        if newName.isEmpty { return }
        name = newName
    }

    public func copyDirectory() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(directory.string, forType: .string)
        pasteboard.setString(fileURL.absoluteString, forType: .fileURL)
    }

    public func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    public init(
        name: String,
        directory: FilePath,
        game: Game = Game.kerbalSpaceProgram,
        version: GameVersion = GameVersion(),
        isDefault: Bool = false
    ) {
        self.name = name
        self.directory = directory
        self.game = game
        self.version = version
        self.isDefault = isDefault
    }

    init(from ckan: Ckan_Instance) throws(CkanError) {
        name = ckan.name
        directory = FilePath(ckan.directory)
        guard let game = Game(id: ckan.gameID) else {
            throw CkanError.unknownGameID(id: ckan.gameID)
        }
        self.game = game
        version = GameVersion(from: ckan.gameVersion)
        isDefault = ckan.isDefault
    }
}
