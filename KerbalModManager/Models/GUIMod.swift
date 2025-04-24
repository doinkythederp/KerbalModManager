//
//  GUIMod.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 4/10/25.
//

import CkanAPI
import Collections
import Foundation
import IdentifiedCollections

@Observable final class GUIMod: Identifiable {
    let id: ModuleId
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
        instance: GUIInstance,
        install: InstalledModule? = nil
    ) {
        id = module.id
        self.module = module
        self.instance = instance
        self.install = install
        if let installedVersion = install?.version {
            currentRelease = module.releases.first {
                $0.version.value == installedVersion
            }!
        } else {
            currentRelease = module.releases.first!
        }
    }

    func applyStateUpdate(_ update: ModuleState) {
        install = update.installState
        isCompatible = update.isCompatible
        canBeUpgraded = update.canBeUpgraded
        currentRelease = module.releases.first {
            $0.version.value == update.currentVersion
        }!
        
        instance.index(module: self)

        logger.trace(
            "\(self.module.id, align: .left(columns: 20)): compatible = \(self.isCompatible), status = \(self.canBeUpgraded ? "upgradable" : self.install == nil ? "not installed" : "installed"), version = \(self.currentRelease.version.value)"
        )
    }
}
