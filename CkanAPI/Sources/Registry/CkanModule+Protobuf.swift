//
//  CkanModule+Protobuf.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/25/25.
//

import Foundation

extension CkanModule {
    convenience init(from ckan: Ckan_Module) {
        self.init(
            id: ckan.identifier,
            name: ckan.name,
            version: ckan.version,

            abstract: ckan.abstract,
            kind: Kind(from: ckan.kind),
            authors: ckan.authors,
            licenses: ckan.licenses,
            resources: Resources(from: ckan.resources),
            localizations: ckan.localizations.map { Locale(identifier: $0) },

            releaseStatus: ReleaseStatus(from: ckan.releaseStatus),

            conflicts: ckan.conflicts.map { Relationship(from: $0) },
            depends: ckan.depends.map { Relationship(from: $0) },
            recommends: ckan.recommends.map { Relationship(from: $0) },
            suggests: ckan.suggests.map { Relationship(from: $0) },
            supports: ckan.supports.map { Relationship(from: $0) },

            downloadUrls: ckan.downloadUris.compactMap { URL(string: $0) },
            downloadSizeBytes: UInt(ckan.downloadSizeBytes),
            installSizeBytes: UInt(ckan.installSizeBytes)
        )

        if ckan.hasDescription_p {
            description = ckan.description_p
        }
        if ckan.hasReplacedBy {
            replacedBy = Relationship(from: ckan.replacedBy)
        }
        if ckan.hasKspVersion {
            kspVersion = GameVersion(from: ckan.kspVersion)
        }
        if ckan.hasKspVersionMax {
            kspVersionMax = GameVersion(from: ckan.kspVersionMax)
        }
        if ckan.hasKspVersionMin {
            kspVersionMin = GameVersion(from: ckan.kspVersionMin)
        }
    }
}

extension CkanModule.Resources {
    init(from ckan: Ckan_Module.Resources) {
        if ckan.hasHomepage { homepage = ckan.homepage }
        if ckan.hasSpacedock { spacedock = ckan.spacedock }
        if ckan.hasCurse { curse = ckan.curse }
        if ckan.hasRepository { repository = ckan.repository }
        if ckan.hasBugtracker { bugtracker = ckan.bugtracker }
        if ckan.hasDiscussions { discussions = ckan.discussions }
        if ckan.hasCi { ci = ckan.ci }
        if ckan.hasLicense { license = ckan.license }
        if ckan.hasManual { manual = ckan.manual }
        if ckan.hasMetanetkan { metanetkan = ckan.metanetkan }
        if ckan.hasRemoteAvc { remoteAvc = ckan.remoteAvc }
        if ckan.hasRemoteSwinfo { remoteSwinfo = ckan.remoteSwinfo }
        if ckan.hasStore { store = ckan.store }
        if ckan.hasSteamStore { steamStore = ckan.steamStore }
    }
}

extension CkanModule.Kind {
    init(from ckan: Ckan_Module.Kind) {
        self =
            switch ckan {
            case .modulePackage: .package
            case .moduleMetapackage: .metapackage
            case .moduleDlc: .dlc
            default: .package
            }
    }
}

extension CkanModule.ReleaseStatus {
    init(from ckan: Ckan_Module.ReleaseStatus) {
        self =
            switch ckan {
            case .mrsStable: .stable
            case .mrsTesting: .testing
            case .mrsDevelopment: .development
            default: .stable
            }
    }
}

extension CkanModule.Relationship {
    init(from ckan: Ckan_Module.Relationship) {
        if ckan.hasChoiceHelpText {
            choiceHelpText = ckan.choiceHelpText
        }
        suppressRecommendations = ckan.suppressRecommendations
        self.type =
            switch ckan.type {
            case .anyOf(let anyOf):
                .anyOf(
                    allowedModules: anyOf.allowedModules.map { Self(from: $0) })
            case .direct(let direct):
                .direct(.init(from: direct))
            default:
                fatalError("Unknown relationship type")
            }
    }
}

extension CkanModule.DirectRelationship {
    init(from ckan: Ckan_Module.Relationship.DirectRelationship) {
        name = ckan.name
        if ckan.hasMaxVersion {
            maxVersion = ckan.maxVersion
        }
        if ckan.hasMinVersion {
            minVersion = ckan.minVersion
        }
        if ckan.hasVersion {
            version = ckan.version
        }
    }
}
