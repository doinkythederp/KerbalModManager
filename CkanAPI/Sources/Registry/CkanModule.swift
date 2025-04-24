//
//  CkanModule.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/25/25.
//

import Collections
import Foundation
import IdentifiedCollections

/// A module that exists in the CKAN registry.
@Observable public class CkanModule: Identifiable {
    public let id: ModuleId
    public var releases: IdentifiedArrayOf<Release>

    public init(id: String, releases: IdentifiedArrayOf<Release> = []) {
        self.id = ModuleId(id)
        self.releases = releases
    }

    /// A specific version of a module.
    @Observable public class Release: Identifiable {
        public var id: (ModuleId, CkanModule.Version) {
            (moduleId, version)
        }
        
        public let moduleId: ModuleId
        public var name: String
        public var version: CkanModule.Version

        public var abstract: String
        public var description: String?
        public var kind: Kind
        public var authors: [String]
        public var licenses: [String]
        public var resources: Resources
        public var localizations: [Locale]
        public var tags: [String]
        public var releaseDate: Date

        public var releaseStatus: Status
        public var replacedBy: Relationship?

        public var provides: [String]
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
        public var downloadCount: UInt

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

        public enum Kind: Sendable, Equatable {
            case package
            case metapackage
            case dlc
        }

        public enum Status: CustomLocalizedStringResourceConvertible, Sendable, Equatable {
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

        public struct Relationship: Identifiable {
            public var id = UUID()

            public var choiceHelpText: String?
            /// If true, then don't show recommendations and suggestions of this module or its dependencies.
            /// Otherwise recommendations and suggestions of everything in changeset will be included.
            /// This is meant to allow the KSP-RO team to shorten the prompts that appear during their installation.
            public var suppressRecommendations: Bool
            public var type: RelationshipType

            public init(
                _ type: CkanModule.Release.RelationshipType,
                choiceHelpText: String? = nil,
                suppressRecommendations: Bool = false
            ) {
                self.choiceHelpText = choiceHelpText
                self.suppressRecommendations = suppressRecommendations
                self.type = type
            }

            public init(direct module: ModuleId) {
                self.init(.direct(DirectRelationship(referencing: module)))
            }

            public init(anyOf modules: [ModuleId]) {
                self.init(
                    .anyOf(
                        allowedModules: modules.map {
                            Relationship(direct: $0)
                        }))
            }
        }

        public enum RelationshipType {
            case direct(DirectRelationship)
            case anyOf(allowedModules: [Relationship])
        }

        public struct DirectRelationship {
            /// Either references a real, indexed module or a module that provides the specified virtual module.
            public var reference: ModuleId
            public var maxVersion: String?
            public var minVersion: String?
            public var version: String?

            public init(
                referencing reference: ModuleId,
                maxVersion: String? = nil,
                minVersion: String? = nil,
                version: String? = nil
            ) {
                self.reference = reference
                self.maxVersion = maxVersion
                self.minVersion = minVersion
                self.version = version
            }
        }

        public init(
            id: String, name: String, version: CkanModule.Version, abstract: String,
            description: String? = nil, kind: CkanModule.Release.Kind = .package,
            authors: [String] = [],
            licenses: [String] = [], resources: CkanModule.Release.Resources,
            localizations: [Locale] = [], tags: [String] = [], releaseDate: Date,
            releaseStatus: CkanModule.Release.Status = .stable,
            replacedBy: CkanModule.Release.Relationship? = nil, provides: [String] = [],
            conflicts: [CkanModule.Release.Relationship] = [],
            depends: [CkanModule.Release.Relationship] = [],
            recommends: [CkanModule.Release.Relationship] = [],
            suggests: [CkanModule.Release.Relationship] = [],
            supports: [CkanModule.Release.Relationship] = [],
            kspVersion: GameVersion? = nil,
            kspVersionMax: GameVersion? = nil, kspVersionMin: GameVersion? = nil,
            downloadUrls: [URL] = [], downloadSizeBytes: UInt,
            installSizeBytes: UInt = 0,
            downloadCount: UInt
        ) {
            self.moduleId = ModuleId(id)
            self.name = name
            self.version = version
            self.abstract = abstract
            self.description = description
            self.kind = kind
            self.authors = authors
            self.licenses = licenses
            self.resources = resources
            self.localizations = localizations
            self.tags = tags
            self.releaseDate = releaseDate
            self.releaseStatus = releaseStatus
            self.replacedBy = replacedBy
            self.provides = provides
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
            self.downloadCount = downloadCount
        }
    }

    public struct Version: CustomStringConvertible, Equatable, Hashable, Sendable {
        public let value: String

        public let epoch: Int
        public let versionComponent: Substring

        public init(_ value: String) {
            self.value = value

            let pattern = /^(?:(?<epoch>[0-9]+):)?(?<version>.*)$/
            let match = try! pattern.wholeMatch(in: value)
            guard let match else {
                fatalError("Version '\(value)' is malformed")
            }

            if let epoch = match.output.epoch {
                guard let epoch = Int(epoch) else {
                    fatalError("Epoch '\(epoch)' in version '\(value)' is not an integer")
                }

                self.epoch = epoch
            } else {
                self.epoch = 0
            }

            versionComponent = match.output.version

        }

        public var description: String {
            value
        }
    }
}

extension CkanModule.Release.Resources {
    public var collection: OrderedDictionary<String, String> {
        let entries: [(LocalizedStringResource, String?)] = [
            ("Homepage", homepage),
            ("Spacedock", spacedock),
            ("Curse", curse),
            ("Bug Tracker", bugtracker),
            ("Discussions", discussions),
            ("Store", store),
            ("Steam Store", steamStore),
            ("Manual", manual),
            ("Source Code", repository),
            ("License", license),
            ("Build Server", ci),
            ("Netkan File", metanetkan),
            ("Remote AVC", remoteAvc),
            ("Remote swinfo", remoteSwinfo),
        ]

        let compacted: [(String, String)] = entries.compactMap { entry in
            let (key, value) = entry
            guard let value else { return nil }
            return (String(localized: key), value)
        }

        return OrderedDictionary(uniqueKeysWithValues: compacted)
    }
}

/// Represents a state update regarding a specific module as it relates to a specific instance.
public struct ModuleState: Sendable, Equatable, Identifiable {
    public var id: ModuleId { moduleId }
    
    /// The ID of the module this struct describes
    public var moduleId: ModuleId
    
    /// If the module is installed in the instance, this property describes how
    public var installState: InstalledModule?
    
    /// Describes if the module is outdated or is missing files
    public var canBeUpgraded: Bool
    
    /// Describes if the module is compatible with the instance
    public var isCompatible: Bool
    
    /// The version of the module most relevant to the instance
    public var currentVersion: String
}

/// A real or virtual module ID
public struct ModuleId: Sendable, Equatable, Hashable, CustomStringConvertible, ExpressibleByStringLiteral {
    public init(_ value: String) {
        self.value = value
    }
    
    public init(stringLiteral value: String) {
        self.init(value)
    }
    
    public var value: String
    
    public var description: String {
        value
    }
}
