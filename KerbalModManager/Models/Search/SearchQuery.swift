//
//  SearchQuery.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 4/14/25.
//

import CkanAPI
import Collections
import Foundation
import IdentifiedCollections

/// A query for filtering module releases down to a more managable number for easier browsing.
struct SearchQuery: Hashable {
    /// Simple filters which can be represented as boolean toggles
    var filters: Set<SimpleModFilter> = [.compatible]
    /// Freeform text search, for imprecise but simple searches
    var text = ""
    /// Precise key-value searches that can query specific aspects of modules
    var tokens: [ModSearchToken] = []

    init(
        filters: Set<SimpleModFilter> = [.compatible],
        text: String = "",
        tokens: [ModSearchToken] = []
    ) {
        self.filters = filters
        self.text = text
        self.tokens = tokens
    }

    /// Reset this search query to the default values.
    mutating func reset() {
        self = SearchQuery()
    }

    /// Clear the aspects of the search query which are represented in the search box.
    ///
    /// The filters are not modified.
    mutating func clearSearchBox() {
        text = ""
        tokens = []
    }

    /// Enables or disables the specified search filter.
    ///
    /// Some filters have counterparts that cannot be enabled at the same time, so this method handles automatically turning these off.
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

    /// Filters the given set of modules down to only the ones that satisfy this search query.
    func query(
        _ modules: IdentifiedArray<CkanModule.ID, CkanModule.Release>,
        instance: GUIInstance
    ) -> IdentifiedArray<CkanModule.ID, CkanModule.Release> {
        modules
            .filter { module in
                filters.allSatisfy { filter in
                    filter.check(module, instance: instance, modules: modules)
                }
                    && tokens.allSatisfy { token in
                        token.check(
                            module, instance: instance, modules: modules)
                    }
                    && module.containsSearchQuery(text)
            }
    }
}

extension CkanModule.Release {
    /// Returns whether the release's name, authors, tags, or abstract contains the given query.
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
