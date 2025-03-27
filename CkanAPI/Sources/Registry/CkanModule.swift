//
//  CkanModule.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/25/25.
//

import Foundation

@Observable
public class CkanModule: Identifiable {
    public var id: String
    public var name: String
    public var version: String

    public var abstract: String
    public var description: String?
    public var kind: Kind
    public var authors: [String]
    public var licenses: [String]
    public var resources: Resources
    public var localizations: [Locale]

    public var releaseStatus: ReleaseStatus
    public var replacedBy: Relationship?

    public var conflicts: [Relationship]
    public var depends: [Relationship]
    public var recommends: [Relationship]
    public var suggests: [Relationship]
    public var supports: [Relationship]

    public var kspVersion: GameVersion?
    public var kspVersionMax: GameVersion?
    public var kspVersionMin: GameVersion?

    public var downloadUrls: [URL]
    public var downloadSizeBytes: UInt
    public var installSizeBytes: UInt

    public struct Resources {
        public var homepage: String?
        public var spacedock: String?
        public var curse: String?
        public var repository: String?
        public var bugtracker: String?
        public var discussions: String?
        public var ci: String?
        public var license: String?
        public var manual: String?
        public var metanetkan: String?
        public var remoteAvc: String?
        public var remoteSwinfo: String?
        public var store: String?
        public var steamStore: String?

        public init(
            homepage: String? = nil, spacedock: String? = nil,
            curse: String? = nil, repository: String? = nil,
            bugtracker: String? = nil, discussions: String? = nil,
            ci: String? = nil, license: String? = nil, manual: String? = nil,
            metanetkan: String? = nil, remoteAvc: String? = nil,
            remoteSwinfo: String? = nil, store: String? = nil,
            steamStore: String? = nil
        ) {
            self.homepage = homepage
            self.spacedock = spacedock
            self.curse = curse
            self.repository = repository
            self.bugtracker = bugtracker
            self.discussions = discussions
            self.ci = ci
            self.license = license
            self.manual = manual
            self.metanetkan = metanetkan
            self.remoteAvc = remoteAvc
            self.remoteSwinfo = remoteSwinfo
            self.store = store
            self.steamStore = steamStore
        }
    }

    public enum Kind {
        case package
        case metapackage
        case dlc
    }

    public enum ReleaseStatus: CustomLocalizedStringResourceConvertible {
        case stable
        case testing
        case development

        public var localizedStringResource: LocalizedStringResource {
            return switch self {
            case .stable: "Stable"
            case .testing: "Testing"
            case .development: "Development"
            }
        }
    }

    public struct Relationship {
        public var choiceHelpText: String?
        /// If true, then don't show recommendations and suggestions of this module or its dependencies.
        /// Otherwise recommendations and suggestions of everything in changeset will be included.
        /// This is meant to allow the KSP-RO team to shorten the prompts that appear during their installation.
        public var suppressRecommendations: Bool
        public var type: RelationshipType
    }

    public enum RelationshipType {
        case direct(DirectRelationship)
        case anyOf(allowedModules: [Relationship])
    }

    public struct DirectRelationship {
        public var name: String
        public var maxVersion: String?
        public var minVersion: String?
        public var version: String?
    }

    public init(
        id: String, name: String, version: String, abstract: String,
        description: String? = nil, kind: CkanModule.Kind = .package,
        authors: [String] = [],
        licenses: [String] = [], resources: CkanModule.Resources = .init(),
        localizations: [Locale] = [],
        releaseStatus: CkanModule.ReleaseStatus = .stable,
        replacedBy: CkanModule.Relationship? = nil,
        conflicts: [CkanModule.Relationship] = [],
        depends: [CkanModule.Relationship] = [],
        recommends: [CkanModule.Relationship] = [],
        suggests: [CkanModule.Relationship] = [],
        supports: [CkanModule.Relationship] = [],
        kspVersion: GameVersion? = nil,
        kspVersionMax: GameVersion? = nil, kspVersionMin: GameVersion? = nil,
        downloadUrls: [URL] = [], downloadSizeBytes: UInt = 0,
        installSizeBytes: UInt = 0
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.abstract = abstract
        self.description = description
        self.kind = kind
        self.authors = authors
        self.licenses = licenses
        self.resources = resources
        self.localizations = localizations
        self.releaseStatus = releaseStatus
        self.replacedBy = replacedBy
        self.conflicts = conflicts
        self.depends = depends
        self.recommends = recommends
        self.suggests = suggests
        self.supports = supports
        self.kspVersion = kspVersion
        self.kspVersionMax = kspVersionMax
        self.kspVersionMin = kspVersionMin
        self.downloadUrls = downloadUrls
        self.downloadSizeBytes = downloadSizeBytes
        self.installSizeBytes = installSizeBytes
    }
}
