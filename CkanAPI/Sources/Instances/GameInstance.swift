//
//  GameInstance.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/3/25.
//

import AppKit
import Foundation
import IdentifiedCollections
import System

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
    public var compatabilityOptions: CompatabilityOptions

    public var hasPrepopulatedRegistry = false
    public var compatibleModules = Set<CkanModule.Release.ID>()


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
        isDefault: Bool = false,
        compatabilityOptions: CompatabilityOptions = .init()
    ) {
        self.name = name
        self.directory = directory
        self.game = game
        self.version = version
        self.isDefault = isDefault
        self.compatabilityOptions = compatabilityOptions
    }

    public struct CompatabilityOptions: Equatable, Sendable {
        public var stabilityTolerance = CkanModule.Release.Status.stable
        public var stabilityToleranceOverrides:
            [CkanModule.ID: CkanModule.Release.Status] = [:]
        public var versionCompatibility = VersionCompatibility()

        public init(
            stabilityTolerance: CkanModule.Release.Status = .stable,
            stabilityToleranceOverrides: [CkanModule.ID: CkanModule.Release.Status] = [:],
            versionCompatibility: GameInstance.VersionCompatibility = .init()
        ) {
            self.stabilityTolerance = stabilityTolerance
            self.stabilityToleranceOverrides = stabilityToleranceOverrides
            self.versionCompatibility = versionCompatibility
        }
    }

    public struct VersionCompatibility: Equatable, Sendable {
        public var additionalCompatibleVersions = Set<GameVersion>()
        public var gameVersionWhenLastUpdated: GameVersion?

        public init(
            _ additionalCompatibleVersions: Set<GameVersion> = [],
            gameVersionWhenLastUpdated: GameVersion? = nil
        ) {
            self.gameVersionWhenLastUpdated = gameVersionWhenLastUpdated
            self.additionalCompatibleVersions = additionalCompatibleVersions
        }
    }
}
