//
//  GameInstance+Protobuf.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 4/8/25.
//

import Foundation
import System

extension GameInstance {
    init(from ckan: Ckan_Instance) throws(CkanError) {
        guard let game = Game(id: ckan.gameID) else {
            throw CkanError.unknownGameID(id: ckan.gameID)
        }

        self.init(
            name: ckan.name,
            directory: FilePath(ckan.directory),
            game: game,
            version: GameVersion(from: ckan.gameVersion),
            isDefault: ckan.isDefault,
            compatabilityOptions: GameInstance.CompatabilityOptions(
                stabilityTolerance: CkanModule.Release.Status(from: ckan.compatOptions.stabilityTolerance),
                stabilityToleranceOverrides: ckan.compatOptions.stabilityToleranceOverrides.mapValues { status in
                    CkanModule.Release.Status(from: status)
                },
                versionCompatibility: GameInstance.VersionCompatibility(
                    Set(ckan.compatOptions.versionCompatibility.compatibleVersions
                            .map { version in GameVersion(from: version) })
                )
            )
        )

        if ckan.compatOptions.versionCompatibility.hasGameVersionWhenLastUpdated {
            let version = ckan.compatOptions.versionCompatibility.gameVersionWhenLastUpdated

            compatabilityOptions.versionCompatibility.gameVersionWhenLastUpdated =
                GameVersion(from: version)
        }

    }
}
