//
//  SearchFilters.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 4/14/25.
//

import Foundation
import CkanAPI
import Collections
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
        _ module: CkanModule.Release,
        instance: GUIInstance,
        modules: IdentifiedArray<CkanModule.ID, CkanModule.Release>
    ) -> Bool {
        switch self {
        case .compatible:
            instance.compatibleModules.ids.contains(module.moduleId)
        case .installed:
            true  // TODO: once we track installs
        case .upgradable:
            true  // TODO: once we track installs

        default:
            !(counterpart!.check(module, instance: instance, modules: modules))
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
        _ module: CkanModule.Release,
        instance: GUIInstance,
        modules: IdentifiedArray<CkanModule.ID, CkanModule.Release>
    ) -> Bool {
        switch self.category {
        case .name:
            module.name.localizedCaseInsensitiveContains(searchTerm)
        case .author:
            module.authors.containsCaseInsensitiveString(searchTerm)
        case .abstract:
            module.abstract.localizedCaseInsensitiveContains(searchTerm)
        case .depends:
            Self.flattenRelationships(module.depends, modules: modules)
                .containsCaseInsensitiveString(searchTerm)
        case .recommends:
            Self.flattenRelationships(module.recommends, modules: modules)
                .containsCaseInsensitiveString(searchTerm)
        case .suggests:
            Self.flattenRelationships(module.suggests, modules: modules)
                .containsCaseInsensitiveString(searchTerm)
        case .conflicts:
            Self.flattenRelationships(module.conflicts, modules: modules)
                .containsCaseInsensitiveString(searchTerm)
        case .provides:
            module.provides.containsCaseInsensitiveString(searchTerm)
        case .tags:
            module.tags.containsCaseInsensitiveString(searchTerm)
        }
    }

    private static func flattenRelationships(
        _ relationships: [CkanModule.Release.Relationship],
        modules: IdentifiedArray<CkanModule.ID, CkanModule.Release>
    ) -> [String] {
        relationships
            .flatMap {
                switch $0.type {
                case .direct(let direct):
                    [modules[id: direct.name]?.name ?? direct.name]
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
        _ module: CkanModule.Release,
        instance: GUIInstance,
        modules: IdentifiedArray<CkanModule.ID, CkanModule.Release>
    ) -> Bool
}
