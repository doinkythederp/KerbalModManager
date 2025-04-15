//
//  GUIMod.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 4/10/25.
//

import Foundation
import CkanAPI
import Collections
import IdentifiedCollections

@Observable final class GUIMod: Identifiable {
    var id: CkanModule.ID { module.id }

    let module: CkanModule
    let instance: GUIInstance

    var install: InstalledModule?

    /// The most appropriate release of the mod to show to the user.
    ///
    /// If the mod is installed, it will use the installed release; compatible, the latest compatible release.
    /// Otherwise, it will use the latest release.
    var currentRelease: CkanModule.Release
    var isCompatible = false
    var compatibleReleases: IdentifiedArrayOf<CkanModule.Release> = []

    var canBeUpgraded = false

    init(
        module: CkanModule,
        instance: GUIInstance
    ) {
        self.module = module
        self.instance = instance
        currentRelease = module.releases.first!
    }
}
