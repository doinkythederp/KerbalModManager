//
//  InstalledModule.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 4/10/25.
//

import Foundation

/// An installed module managed by CKAN.
public struct ManagedInstalledModule: Sendable, Equatable {
    /// The date the install was performed
    public var date: Date
    /// Which module was installed
    public var version: String
    /// Whether the user implicitly requested the module to be installed as a dependency
    public var wasAutoInstalled = false

    public init(
        date: Date,
        version: String,
        wasAutoInstalled: Bool = false
    ) {
        self.date = date
        self.version = version
        self.wasAutoInstalled = wasAutoInstalled
    }
}

/// An installed module managed externally.
///
/// Cannot be uninstalled.
public struct UnmanagedInstalledModule: Sendable, Equatable {
    public var version: String?

    internal init(version: String? = nil) {
        self.version = version
    }
}

public enum InstalledModule: Sendable, Equatable {
    case managed(ManagedInstalledModule)
    case unmanaged(UnmanagedInstalledModule)

    public var version: String? {
        switch self {
        case .managed(let managed):
            managed.version
        case .unmanaged(let unmanaged):
            unmanaged.version
        }
    }
}
