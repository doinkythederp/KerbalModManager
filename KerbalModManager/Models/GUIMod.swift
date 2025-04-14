//
//  GUIMod.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 4/10/25.
//

import Foundation
import CkanAPI

@Observable final class GUIMod {
    let module: CkanModule
    let instance: GameInstance

    var install: InstalledModule?

    /// The most appropriate release of the mod to show to the user.
    ///
    /// If the mod is installed, it will use the installed release; compatible, the latest compatible release.
    /// Otherwise, it will use the latest release.
    var currentRelease: CkanModule.Release?
    var isCompatible = false

    
}
