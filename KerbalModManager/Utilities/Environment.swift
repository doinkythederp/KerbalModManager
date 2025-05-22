//
//  Environment.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/26/25.
//

import SwiftUI
import CkanAPI

extension EnvironmentValues {
    @Entry var ckanActionDelegate: CkanActionDelegate = EmptyCkanActionDelegate()
}

enum AppStorageKey {
    static let skipOptionalDependencies = "SkipOptionalDependencies"
}
