//
//  CkanModule+Protobuf.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/25/25.
//

import Collections
import Foundation
import IdentifiedCollections

extension CkanModule {
    convenience init(from ckan: Ckan_Module) {
        self.init(
            id: ckan.identifier,
            releases: IdentifiedArray(
                uniqueElements: ckan.releases.map { release in
                    CkanModule.Release(id: ckan.identifier, from: release)
                }))
    }
}

extension CkanModule.Release {
    convenience init(id: String, from ckan: Ckan_Module.Release) {
        self.init(
            id: id,
            name: ckan.name,
            version: CkanModule.Version(ckan.version),

            abstract: ckan.abstract,
            kind: Kind(from: ckan.kind),
            authors: ckan.authors,
            licenses: ckan.licenses,
            resources: Resources(from: ckan.resources),
            localizations: ckan.localizations.map { Locale(identifier: $0) },
            tags: ckan.tags,
            releaseDate: ckan.releaseDate.date,

            releaseStatus: Status(from: ckan.releaseStatus),

            provides: ckan.provides,
            conflicts: ckan.conflicts.map { Relationship(from: $0) },
            depends: ckan.depends.map { Relationship(from: $0) },
            recommends: ckan.recommends.map { Relationship(from: $0) },
            suggests: ckan.suggests.map { Relationship(from: $0) },
            supports: ckan.supports.map { Relationship(from: $0) },

            downloadUrls: ckan.downloadUris.compactMap { URL(string: $0) },
            downloadSizeBytes: UInt(ckan.downloadSizeBytes),
            installSizeBytes: UInt(ckan.installSizeBytes),
            downloadCount: UInt(ckan.downloadCount)
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

extension CkanModule.Release.Resources {
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

extension CkanModule.Release.Kind {
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

extension CkanModule.Release.Status {
    init(from ckan: Ckan_Module.ReleaseStatus) {
        self =
            switch ckan {
            case .mrsStable: .stable
            case .mrsTesting: .testing
            case .mrsDevelopment: .development
            default: .stable
            }
    }

    var rawValue: Ckan_Module.ReleaseStatus {
        switch self {
        case .stable:
            .mrsStable
        case .testing:
            .mrsTesting
        case .development:
            .mrsDevelopment
        }
    }
}

extension CkanModule.Release.Relationship {
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

extension CkanModule.Release.DirectRelationship {
    init(from ckan: Ckan_Module.Relationship.DirectRelationship) {
        reference = ModuleId(ckan.name)
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

extension ModuleState {
    init(from ckan: Ckan_ModuleState) {
        moduleId = ModuleId(ckan.identifier)
        if let install = ckan.install {
            installState = InstalledModule(from: install, moduleId: moduleId)
        }
        canBeUpgraded = ckan.canBeUpgraded
        isCompatible = ckan.isCompatible
        currentVersion = ckan.currentRelease
    }
}

extension InstalledModule {
    init(from ckan: Ckan_ModuleState.OneOf_Install, moduleId: ModuleId) {
        switch ckan {
        case .managedInstall(let managed):
            self = .managed(
                ManagedInstalledModule(
                    release: ReleaseId(moduleId: moduleId, version: managed.releaseVersion),
                    date: managed.installDate.date,
                    wasAutoInstalled: managed.isAutoInstalled
                )
            )

        case .unmanagedInstall(let unmanaged):
            var install = UnmanagedInstalledModule()
            if unmanaged.hasReleaseVersion {
                install.release = ReleaseId(moduleId: moduleId, version: unmanaged.releaseVersion)
            }

            self = .unmanaged(install)
        }
    }
}

extension ReleaseId {
    init(from ckan: Ckan_ModuleReleaseRef) {
        moduleId = ModuleId(ckan.id)
        version = ckan.version
    }
}

extension Ckan_ModuleReleaseRef {
    init(from releaseId: ReleaseId) {
        id = releaseId.moduleId.value
        version = releaseId.version
    }
}

extension OptionalDependencies {
    init(from ckan: Ckan_RegistryOptionalDependenciesReply) {
        recommended = Set(ckan.recommended.map(Dependency.init))
        suggested = Set(ckan.suggested.map(Dependency.init))
        supporters = Set(ckan.supporters.map(Dependency.init))
        installableRecommended = Set(ckan.installableRecommended.map { ModuleId($0) })
    }
}

extension OptionalDependencies.Dependency {
    init(from ckan: Ckan_RegistryOptionalDependenciesReply.Dependency) {
        id = ReleaseId(from: ckan.module)
        sources = Set(ckan.sources.map { ModuleId($0) })
    }
}
