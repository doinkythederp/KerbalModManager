//
//  InstallModel.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 5/2/25.
//

import CkanAPI

enum InstallStage: Equatable, Hashable, Identifiable {
    case pending
    case pickOptionalDependencies(OptionalDependencies)

    var id: Self { self }
}
