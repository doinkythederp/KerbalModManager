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
    
    /// A Boolean value indicating whether the mod was intentionally installed by the user.
    ///
    /// Auto-installed or uninstalled mods are not considered intentionally installed.
    var isUserInstalled: Bool {
        switch install {
        case .managed(let install):
            return !install.wasAutoInstalled
        case .unmanaged(_):
            return true
        case nil:
            return false
        }
    }

    func isUserInstalled(release: ReleaseId?) -> Bool {
        guard let release else {
            return isUserInstalled
        }

        if case .managed(let managedInstall) = install {
            return !managedInstall.wasAutoInstalled && managedInstall.release == release
        }

        return false
    }

    /// A property containing the release of the module which is currently installed, if it is known.
    ///
    /// Sometimes a module might be installed without there being a known release (for example, this
    /// happens if the module was installed without using CKAN and thereby isn't managed).
    var installedRelease: CkanModule.Release? {
        guard case .managed(let install) = install,
              let release = module.releases[id: install.release] else {
            return nil
        }
        
        return release
    }

    var isReadOnly: Bool {
        currentRelease.kind == .dlc
    }

    /// The most appropriate release of the mod to show to the user.
    ///
    /// If the mod is installed, it will use the installed release; if it is compatible, the latest compatible release.
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
        if let installedRelease = install?.release {
            currentRelease = module.releases[id: installedRelease]!
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
