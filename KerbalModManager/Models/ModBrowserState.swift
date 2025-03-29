//
//  ModBrowserState.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/28/25.
//

import Foundation
import CkanAPI
import SwiftUI


@MainActor @Observable final class ModBrowserState {
    var selectedModules = Set<CkanModule.ID>()
    var sortOrder = [KeyPathComparator(\CkanModule.name)]
    var scrollProxy: ScrollViewProxy?

    struct Changes {

    }

    init() {}
}
