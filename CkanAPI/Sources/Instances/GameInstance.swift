//
//  GameInstance.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/3/25.
//

import System
import Foundation

public struct GameInstance: Sendable, Identifiable, Hashable {
    public var id = UUID()
    public var name: String
    public var directory: FilePath
    public var game: Game
    public var version: GameVersion
    public var isDefault: Bool

    public var fileURL: URL {
        URL(filePath: directory)!
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
