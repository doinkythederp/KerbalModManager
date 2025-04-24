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
                stabilityTolerance: CkanModule.Release.Status(
                    from: ckan.compatOptions.stabilityTolerance),
                stabilityToleranceOverrides:
                    Dictionary(
                        uniqueKeysWithValues:
                            ckan.compatOptions.stabilityToleranceOverrides
                            .map { k, v in
                                (
                                    ModuleId(k),
                                    CkanModule.Release.Status(from: v)
                                )
                            }),
                versionCompatibility: GameInstance.VersionCompatibility(
                    Set(
                        ckan.compatOptions.versionCompatibility
                            .compatibleVersions
                            .map(GameVersion.init))
                )
            )
        )

        if ckan.compatOptions.versionCompatibility.hasGameVersionWhenLastUpdated
        {
            let version = ckan.compatOptions.versionCompatibility
                .gameVersionWhenLastUpdated

            compatabilityOptions.versionCompatibility
                .gameVersionWhenLastUpdated =
                GameVersion(from: version)
        }

    }
}

extension Ckan_Instance.VersionCompatibility {
    init(from compat: GameInstance.VersionCompatibility) {
        self.compatibleVersions = compat.additionalCompatibleVersions.map(
            Ckan_Game.Version.init)
        if let version = compat.gameVersionWhenLastUpdated {
            self.gameVersionWhenLastUpdated = Ckan_Game.Version(from: version)
        }
    }
}

extension Ckan_Instance.CompatOptions {
    init(from compat: GameInstance.CompatabilityOptions) {
        self.stabilityTolerance = compat.stabilityTolerance.rawValue
        self.versionCompatibility = Ckan_Instance.VersionCompatibility(
            from: compat.versionCompatibility)
        self.stabilityToleranceOverrides =
            Dictionary(
                uniqueKeysWithValues:
                    compat.stabilityToleranceOverrides
                    .map { k, v in (k.value, v.rawValue) })
    }
}
