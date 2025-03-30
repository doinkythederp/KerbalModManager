//
//  ModBrowserState.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/28/25.
//

import CkanAPI
import Collections
import Foundation
import IdentifiedCollections
import SwiftUI

extension FocusedValues {
    var modBrowserState: ModBrowserState? {
        get { self[ModBrowserState.self] }
        set { self[ModBrowserState.self] = newValue }
    }
}

@MainActor @Observable final class ModBrowserState {
    var selectedModule: CkanModule.ID?
    var sortOrder = [KeyPathComparator(\CkanModule.name)]
    var scrollProxy: ScrollViewProxy?

    var isSearchPresented = false
    var search = Search()
    @ObservationIgnored private var searchResults: OrderedSet<CkanModule.ID>?
    @ObservationIgnored private var searchResultsHash: Int?
    @ObservationIgnored var preferNonDestructiveSearches = false

    /// This module will be scrolled to after the next render.
    var modulePendingReveal: CkanModule.ID?

    struct Search: Hashable {
        var filters: Set<SimpleModFilter> = [.compatible]
        var text = ""
        var tokens: [ModSearchToken] = []

        init(filters: Set<SimpleModFilter> = [.compatible], text: String = "", tokens: [ModSearchToken] = []) {
            self.filters = filters
            self.text = text
            self.tokens = tokens
        }

        mutating func reset() {
            self = Search()
        }

        mutating func clearSearchBox() {
            text = ""
            tokens = []
        }

        /// Enables or disables the specified search filter. Some filters
        /// have counterparts that cannot be enabled at the same time,
        /// so this method handles automatically turning these off.
        mutating func setFilter(_ filter: SimpleModFilter, enabled: Bool) {
            if !enabled {
                filters.remove(filter)
                return
            }

            if let counterpart = filter.counterpart {
                filters.remove(counterpart)
            }

            filters.insert(filter)
        }

        fileprivate func query(
            _ modules: IdentifiedArrayOf<CkanModule>,
            instance: GameInstance
        ) -> IdentifiedArrayOf<CkanModule> {
            modules
                .filter { module in
                    filters.allSatisfy { filter in
                        filter.check(module, instance: instance, modules: modules)
                    }
                        && tokens.allSatisfy { token in
                            token.check(module, instance: instance, modules: modules)
                        }
                        && module.containsSearchQuery(text)
                }
        }
    }

    func queryModules(
        _ modules: IdentifiedArrayOf<CkanModule>,
        instance: GameInstance
    ) -> IdentifiedArrayOf<CkanModule> {
        if search.text.isEmpty && search.filters.isEmpty
            && search.tokens.isEmpty
        {
            return modules
        }

        var hasher = Hasher()
        hasher.combine(modules.ids)
        hasher.combine(search)
        let hash = hasher.finalize()

        let results =
            if let searchResults, searchResultsHash == hash {
                modules.filter {
                    searchResults.contains($0.id)
                }
            } else {
                search.query(modules, instance: instance)
            }

        // If the user clicked on the "reveal" button of a dependency and
        // it's not going to be shown given the current filters, then we
        // relax the query to make it appear.

        if let modulePendingReveal,
            !search.filters.isEmpty,
            !results.ids.contains(modulePendingReveal)
        {
            search.filters = []

            // This won't cause an infinite loop because we set `search.filters` to an empty value.
            return queryModules(modules, instance: instance)
        }

        searchResults = results.ids
        searchResultsHash = hash

        return results
    }

    /// Show the given module to the user.
    func reveal(module: CkanModule) {
        search.clearSearchBox()
        selectedModule = module.id
        modulePendingReveal = module.id
    }

    /// Search for the given tokens, choosing to reset the search box based on the users' preference.
    func search(tokens: [ModSearchToken]) {
        if !preferNonDestructiveSearches {
            search.reset()
        }
        
        search.tokens.append(contentsOf: tokens)
    }

    init() {}
}

extension ModBrowserState: FocusedValueKey {
    typealias Value = ModBrowserState
}

extension CkanModule {
    fileprivate func containsSearchQuery(_ query: String) -> Bool {
        if query.isEmpty {
            return true
        }

        return name.localizedCaseInsensitiveContains(query)
            || authors.contains { $0.localizedCaseInsensitiveContains(query) }
            || tags.contains { $0.localizedCaseInsensitiveContains(query) }
            || abstract.localizedCaseInsensitiveContains(query)
    }
}

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
        _ module: CkanModule,
        instance: GameInstance,
        modules: IdentifiedArrayOf<CkanModule>
    ) -> Bool {
        switch self {
        case .compatible:
            instance.compatibleModules.contains(module.id)
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
        _ module: CkanModule,
        instance: GameInstance,
        modules: IdentifiedArrayOf<CkanModule>
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
        _ relationships: [CkanModule.Relationship],
        modules: IdentifiedArrayOf<CkanModule>
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
        _ module: CkanModule,
        instance: GameInstance,
        modules: IdentifiedArrayOf<CkanModule>
    ) -> Bool
}
