//
//  ChangePlan.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 5/2/25.
//

import CkanAPI
import Foundation

struct ModuleChangePlan: Equatable {
    /// A set of module releases that should be installed after the plan has been executed.
    ///
    /// This property also includes planned upgrades.
    private(set) var pendingInstallation = [ModuleId: ReleaseId]()
    /// A set of modules that will be removed when the plan is executed.
    private(set) var pendingRemoval = Set<ModuleId>()
    /// A set of modules whos replacements will be installed after the plan is executed.
    private(set) var pendingReplacement = Set<ModuleId>()

    mutating func removeAll() {
        self = ModuleChangePlan()
    }

    /// Set the specified mod to either be installed or uninstalled
    ///
    /// - Parameters:
    ///   - mod: The mod whose install state will be modified
    ///   - installed: Indicates whether the mod will be installed after this change plan is applied
    ///   - release: Specifies which release of the mod will be used
    mutating func set(
        _ mod: GUIMod, installed: Bool,
        release releaseOverride: ReleaseId? = nil
    ) {
        assert(mod.currentRelease.kind != .dlc, "Cannot install or remove DLCs")

        let alreadyInstalled = mod.isUserInstalled(release: releaseOverride)

        if alreadyInstalled {
            setRemoved(!installed, for: mod.id)
        } else {
            let release =
                installed ? (releaseOverride ?? mod.currentRelease.id) : nil
            setPendingRelease(release, for: mod.id)
        }
    }

    mutating func cancelChanges(to mod: ModuleId) {
        pendingInstallation[mod] = nil
        pendingRemoval.remove(mod)
        pendingReplacement.remove(mod)
    }

    /// Plan or cancel the installation of a module.
    mutating func setPendingRelease(_ release: ReleaseId?, for module: ModuleId)
    {
        pendingRemoval.remove(module)
        pendingInstallation[module] = release
    }

    /// Plan or cancel the removal of a module.
    mutating func setRemoved(_ removed: Bool, for module: ModuleId) {
        pendingInstallation[module] = nil
        if removed {
            pendingRemoval.insert(module)
        } else {
            pendingRemoval.remove(module)
        }
    }

    /// Plan or cancel the replacement of a module.
    mutating func setReplaced(_ replaced: Bool, for module: ModuleId) {
        pendingRemoval.remove(module)
        pendingInstallation[module] = nil
        if replaced {
            pendingReplacement.insert(module)
        } else {
            pendingReplacement.remove(module)
        }
    }

    /// A Boolean value that indicates if no changes are planned
    var isEmpty: Bool {
        pendingInstallation.isEmpty
            && pendingRemoval.isEmpty
            && pendingReplacement.isEmpty
    }

    /// Returns a Boolean value indicating whether the specified mod will be intentionally installed by the user after this plan is executed.
    func isUserInstalled(_ mod: GUIMod) -> Bool {
        if pendingInstallation[mod.id] != nil {
            return true
        }

        if pendingRemoval.contains(mod.id) {
            return false
        }

        return mod.isUserInstalled
    }

    /// Returns a Boolean value indicating whether a certain release of the specified mod will be intentionally
    /// installed by the user after this plan is executed.
    func isUserInstalled(_ mod: GUIMod, release: ReleaseId?) -> Bool {
        guard let release else {
            return isUserInstalled(mod)
        }

        if let pending = pendingInstallation[mod.id] {
            return pending == release
        }

        if pendingRemoval.contains(mod.id) {
            return false
        }

        return mod.isUserInstalled(release: release)
    }

    /// Returns the current status of the given mod in the context of this change plan.
    ///
    /// This may be used to display the state of the module to the user.
    func status(of mod: GUIMod) -> Status {
        if let install = mod.install {
            if pendingRemoval.contains(mod.id) {
                return .removing
            }

            if mod.canBeUpgraded {
                if pendingInstallation[mod.id] == nil {
                    return .upgradable
                } else {
                    return .upgrading
                }
            }

            guard case .managed(_) = install,
                mod.currentRelease.kind != .dlc
            else {
                return .autoDetected
            }

            if pendingReplacement.contains(mod.id) {
                return .replacing
            }

            if mod.installedRelease?.replacedBy != nil {
                return .replaceable
            }

            // At the time of writing, there's not actually a way to represent this because ``GUIMod.currentRelease`` is non-nillable
            if !mod.module.containsRelease(
                stableEnoughFor: mod.instance.ckan.compatabilityOptions)
            {
                return .unavailable
            }
        }

        if pendingInstallation[mod.id] != nil {
            return .installing
        }

        if case .managed(let install) = mod.install,
            install.wasAutoInstalled
        {
            return .autoInstalled
        }

        if mod.install != nil {
            return .installed
        }

        return .notInstalled
    }

    /// The status of a mod in the context of a change plan
    enum Status: CustomLocalizedStringResourceConvertible {
        case removing
        case upgrading
        case upgradable
        case autoDetected
        case replacing
        case replaceable
        case unavailable
        case autoInstalled
        case installed
        case installing
        case notInstalled

        var localizedStringResource: LocalizedStringResource {
            return switch self {
            case .removing: "Removal Pending"
            case .upgrading: "Upgrade Pending"
            case .upgradable: "Upgradable"
            case .autoDetected: "Manually Installed"
            case .replacing: "Replacement Pending"
            case .replaceable: "Replacement Available"
            case .unavailable: "Installed (No Versions Available)"
            case .autoInstalled: "Auto-Installed"
            case .installed: "Installed"
            case .installing: "Install Pending"
            case .notInstalled: "Not Installed"
            }
        }
    }
}
