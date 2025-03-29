//
//  ModBrowserState.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/28/25.
//

import Foundation
import CkanAPI
import SwiftUI


@MainActor @Observable final class ModBrowserState {
    var selectedModules = Set<CkanModule.ID>()
    var sortOrder = [KeyPathComparator(\CkanModule.name)]
    var scrollProxy: ScrollViewProxy?
    var searchText = "parallax"
    var searchTokens: [ModSearchToken] = [
        ModSearchToken(category: .compatible),
        ModSearchToken(category: .author, searchTerm: "Linx"),
    ]

//    enum SearchToken: Identifiable, Hashable {
//        case keyValue(
//            key: SearchKey,
//            name: String,
//            value: String
//        )
//
//        typealias Target = CkanModule
//
//        static func suggestedTokens(for search: String) -> Set<Self> {
//            [
//                SearchToken(\.name, name: "Name", value: search),
//                SearchToken(\.abstract, name: "Description", value: search),
//                SearchToken(\.authors, name: "Authors", value: search),
//                SearchToken(\.depends, name: "Depends", value: search),
//            ]
//        }
//
//        var id: String {
//            switch self {
//            case .keyValue(key: let key, name: _, value: _):
//                "keyValue: \(key.id)"
//            }
//        }
//
//        init(_ key: KeyPath<Target, String>, name: LocalizedStringResource, value: String) {
//            self = .keyValue(key: .string(key), name: String(localized: name), value: value)
//        }
//
//        init(_ key: KeyPath<Target, [String]>, name: LocalizedStringResource, value: String) {
//            self = .keyValue(key: .array(key), name: String(localized: name), value: value)
//        }
//
//        init(_ key: KeyPath<Target, [CkanModule.Relationship]>, name: LocalizedStringResource, value: String) {
//            self = .keyValue(key: .relationship(key), name: String(localized: name), value: value)
//        }
//
//        enum SearchKey: Identifiable, Hashable {
//            case string(KeyPath<Target, String>)
//            case array(KeyPath<Target, [String]>)
//            case relationship(KeyPath<Target, [CkanModule.Relationship]>)
//
//            var id: String {
//                switch self {
//                case .string(let kp): "String \(kp.hashValue)"
//                case .array(let kp): "[String] \(kp.hashValue)"
//                case .relationship(let kp): "[Relationship] \(kp.hashValue)"
//                }
//            }
//        }
//
//    }

    init() {}
}

struct ModSearchToken: Hashable, Identifiable {
    enum Category: String, Identifiable, Hashable, CustomLocalizedStringResourceConvertible {
        var id: Self { self }

        // Needs search term
        case name
        case author
        case abstract
        case depends

        // No search term
        case compatible
        case incompatible

        case installed
        case notInstalled

        case upgradable

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
    }

    var id: Self { self }

    var category: Category
    var searchTerm: String?
}
