//
//  GameVersion.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/3/25.
//

public struct GameVersion: Sendable, Hashable {
    public var major: Int?
    public var minor: Int?
    public var patch: Int?
    public var build: Int?

    public init(major: Int? = nil, minor: Int? = nil, patch: Int? = nil, build: Int? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.build = build
    }

    init(from ckan: Ckan_Game.Version) {
        major = ckan.hasMajor ? Int(ckan.major) : nil
        minor = ckan.hasMinor ? Int(ckan.minor) : nil
        patch = ckan.hasPatch ? Int(ckan.patch) : nil
        build = ckan.hasBuild ? Int(ckan.build) : nil
    }
}

extension Ckan_Game.Version {
    init(from version: GameVersion) {
        if let major = version.major {
            self.major = Int32(major)
        }
        if let minor = version.minor {
            self.minor = Int32(minor)
        }
        if let patch = version.patch {
            self.patch = Int32(patch)
        }
        if let build = version.build {
            self.build = Int32(build)
        }
    }
}
