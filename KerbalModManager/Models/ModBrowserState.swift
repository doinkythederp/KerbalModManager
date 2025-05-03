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
import SFSafeSymbols
import SwiftUI

/// Tracks the state of a mod browser for a certain instance.
@MainActor @Observable final class ModBrowserState {
    let instance: GUIInstance

    var selectedMod: ModuleId?
    var sortOrder = [KeyPathComparator(\GUIMod.currentRelease.name)]
    var scrollProxy: ScrollViewProxy?

    var isSearchPresented = false
    var search = SearchQuery()

    @ObservationIgnored
    private var sortResults: IdentifiedArrayOf<GUIMod>?
    @ObservationIgnored
    private var sortResultsHash: Int?

    @ObservationIgnored
    private var searchResults: IdentifiedArrayOf<GUIMod>?
    @ObservationIgnored
    private var searchResultsHash: Int?

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
    var modulePendingReveal: ModuleId?

    // Install state

    var changePlan = ModuleChangePlan()
    var installStage: InstallStage?

    /// Returns the given modules reordered such that the ``sortOrder`` is satisfied.
    func sortedModules(
        _ modules: IdentifiedArrayOf<GUIMod>
    ) -> IdentifiedArrayOf<GUIMod> {
        var hasher = Hasher()
        hasher.combine(modules.ids.unordered)
        hasher.combine(sortOrder)
        let hash = hasher.finalize()

        if let sortResults, hash == sortResultsHash {
            return sortResults
        }

        logger.trace("Mod Browser: Sort order cache miss")

        let results = IdentifiedArray(
            uncheckedUniqueElements: modules.sorted(using: sortOrder))

        sortResults = results
        sortResultsHash = hash

        return results
    }

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

        let results: IdentifiedArrayOf<GUIMod>
        if let searchResults, searchResultsHash == hash {
            results = searchResults
        } else {
            logger.trace("Mod Browser: Search results cache miss")

            results = IdentifiedArray(
                uncheckedUniqueElements:
                    search.query(
                        IdentifiedArray(uniqueElements: modules),
                        instance: instance,
                        changePlan: changePlan
                    )
                    .sorted(using: sortOrder)
            )

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

        searchResults = results
        searchResultsHash = hash

        return results
    }

    /// Show the given module to the user.
    func reveal(module: GUIMod) {
        reveal(id: module.id)
    }

    /// Show the module with the given ID to the user.
    func reveal(id: ModuleId) {
        search.clearSearchBox()
        selectedMod = id
        modulePendingReveal = id
    }

    /// Search for the given tokens, choosing to reset the search box based on the users' preference.
    func search(tokens: [ModSearchToken]) {
        if !preferNonDestructiveSearches {
            search.reset()
        }

        search.tokens.append(contentsOf: tokens)
        isSearchPresented = true
    }

    /// Force a refresh of the search results.
    ///
    /// This is useful if the metadata of the available modules has updated without the IDs changing.
    func invalidateSearchResults() {
        searchResults = nil
        searchResultsHash = nil
    }

    init(instance: GUIInstance) {
        self.instance = instance
    }
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
