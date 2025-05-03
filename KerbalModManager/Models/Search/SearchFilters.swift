//
//  SearchFilters.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 4/14/25.
//

import CkanAPI
import Collections
import Foundation
import IdentifiedCollections

/// A filter that does not require an associated search term.
enum SimpleModFilter: Hashable, CaseIterable,
    CustomLocalizedStringResourceConvertible, Identifiable, ModSearchFilter
{
    // No search term
    case compatible
    case incompatible

    case installed
    case notInstalled

    case upgradable

    var id: Self { self }

    var counterpart: Self? {
        switch self {
        case .compatible: .incompatible
        case .incompatible: .compatible

        case .installed: .notInstalled
        case .notInstalled: .installed

        case .upgradable: nil
        }
    }

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .compatible:
            "Compatible"
        case .incompatible:
            "Incompatible"
        case .installed:
            "Installed"
        case .notInstalled:
            "Not Installed"
        case .upgradable:
            "Upgradable"
        }
    }

    func check(
        _ mod: GUIMod,
        instance: GUIInstance,
        modules: IdentifiedArray<ModuleId, GUIMod>,
        changePlan: ModuleChangePlan
    ) -> Bool {
        switch self {
        case .compatible:
            instance.compatibleModules.ids.contains(mod.id)
        case .installed:
            changePlan.pendingInstallation[mod.id] != nil
                || instance.installedModules.ids.contains(mod.id)
        case .upgradable:
            mod.canBeUpgraded
        default:
            !(counterpart!.check(
                mod, instance: instance, modules: modules,
                changePlan: changePlan))
        }
    }
}

/// A filter that requires an associated search term and appears in the search bar.
struct ModSearchToken: Hashable, Identifiable, ModSearchFilter {
    enum Category: String, Identifiable, Hashable,
        CustomLocalizedStringResourceConvertible, CaseIterable
    {
        var id: Self { self }

        case name
        case author
        case abstract
        case depends
        case recommends
        case suggests
        case conflicts
        case provides
        case tags

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .name:
                "Name"
            case .author:
                "Author"
            case .abstract:
                "Description"
            case .depends:
                "Depends"
            case .recommends:
                "Recommends"
            case .suggests:
                "Suggests"
            case .conflicts:
                "Conflicts"
            case .provides:
                "Satisfies"
            case .tags:
                "Tag"
            }
        }
    }

    var id: Self { self }

    var category: Category
    var searchTerm: String

    func check(
        _ mod: GUIMod,
        instance: GUIInstance,
        modules: IdentifiedArray<ModuleId, GUIMod>,
        changePlan: ModuleChangePlan
    ) -> Bool {
        let release = mod.currentRelease

        return switch self.category {
        case .name:
            release.name.localizedCaseInsensitiveContains(searchTerm)
        case .author:
            release.authors.containsCaseInsensitiveString(searchTerm)
        case .abstract:
            release.abstract.localizedCaseInsensitiveContains(searchTerm)
        case .depends:
            Self.flattenRelationships(release.depends, modules: modules)
                .containsCaseInsensitiveString(searchTerm)
        case .recommends:
            Self.flattenRelationships(release.recommends, modules: modules)
                .containsCaseInsensitiveString(searchTerm)
        case .suggests:
            Self.flattenRelationships(release.suggests, modules: modules)
                .containsCaseInsensitiveString(searchTerm)
        case .conflicts:
            Self.flattenRelationships(release.conflicts, modules: modules)
                .containsCaseInsensitiveString(searchTerm)
        case .provides:
            release.provides.containsCaseInsensitiveString(searchTerm)
        case .tags:
            release.tags.containsCaseInsensitiveString(searchTerm)
        }
    }

    private static func flattenRelationships(
        _ relationships: [CkanModule.Release.Relationship],
        modules: IdentifiedArray<ModuleId, GUIMod>
    ) -> [String] {
        relationships
            .flatMap {
                switch $0.type {
                case .direct(let direct):
                    [
                        modules[id: direct.reference]?.currentRelease.name
                            ?? direct.reference.value
                    ]
                case .anyOf(allowedModules: let allowed):
                    flattenRelationships(allowed, modules: modules)
                }
            }
    }
}

extension [String] {
    fileprivate func containsCaseInsensitiveString(_ searchTerm: String) -> Bool
    {
        contains {
            $0.localizedCaseInsensitiveCompare(searchTerm)
                == .orderedSame
        }
    }
}

protocol ModSearchFilter {
    func check(
        _ mod: GUIMod,
        instance: GUIInstance,
        modules: IdentifiedArray<ModuleId, GUIMod>,
        changePlan: ModuleChangePlan
    ) -> Bool
}
