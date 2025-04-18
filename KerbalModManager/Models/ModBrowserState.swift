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

/// Tracks the state of a mod browser for a certain instance.
@MainActor @Observable final class ModBrowserState {
    var selectedMod: GUIMod.ID?
    var sortOrder = [KeyPathComparator(\GUIMod.currentRelease.name)]
    var scrollProxy: ScrollViewProxy?

    var isSearchPresented = false
    var search = SearchQuery()
    @ObservationIgnored private var searchResults: OrderedSet<GUIMod.ID>?
    @ObservationIgnored private var searchResultsHash: Int?

    /// Whether to prefer adding to the existing search query rather than replacing it.
    ///
    /// If the shift key is pressed, non-destructive searches will always be preferred.
    /// Changes to this value cannot be observed, so it will never trigger a UI update.
    @ObservationIgnored var preferNonDestructiveSearches = false

    /// The module, if any, that should be promptly revealed in the mod browser.
    ///
    /// This value is observed for changes by the mod browser, so setting it to a certain mod will update the UI.
    /// Prefer using ``ModBrowserState/reveal(module:)`` instead of setting this directly, because it
    /// also handles clearing the search box and updating the selected mod.
    var modulePendingReveal: GUIMod.ID?

    /// Filter the given modules to only include results that satisfy the current search query.
    ///
    /// This method handles caching search results. If there is a ``ModBrowserState/modulePendingReveal``
    /// set, the search filters may be relaxed to include it.
    func queryModules(
        _ modules: IdentifiedArrayOf<GUIMod>,
        instance: GUIInstance
    ) -> IdentifiedArrayOf<GUIMod> {
        if search.text.isEmpty && search.filters.isEmpty
            && search.tokens.isEmpty
        {
            return modules
        }

        var hasher = Hasher()
        hasher.combine(modules.ids)
        hasher.combine(search)
        let hash = hasher.finalize()

        let resultIds =
            if let searchResults, searchResultsHash == hash {
                searchResults
            } else {
                search.query(
                    IdentifiedArray(
                        uniqueElements: modules.compactMap {
                            $0.currentRelease
                        },
                        id: \.moduleId
                    ),
                    instance: instance
                ).ids
            }

        let results = modules.filter {
            resultIds.contains($0.id)
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
    func reveal(module: GUIMod) {
        search.clearSearchBox()
        selectedMod = module.id
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

extension FocusedValues {
    /// Tracks which mod browser is currently active in the UI.
    var modBrowserState: ModBrowserState? {
        get { self[ModBrowserState.self] }
        set { self[ModBrowserState.self] = newValue }
    }
}

extension ModBrowserState: FocusedValueKey {
    typealias Value = ModBrowserState
}
