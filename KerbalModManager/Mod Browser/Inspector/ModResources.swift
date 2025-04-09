//
//  ModResources.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/28/25.
//

import SwiftUI
import CkanAPI

struct ModResourcesView: View {
    var module: CkanModule.Release

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup("Details and Links", isExpanded: $isExpanded) {
            Grid(alignment: .leading) {
                let collection = module.resources.collection
                ForEach(collection.elements, id: \.key) { element in
                    GridRow {
                        Text("\(element.key):")
                            .gridColumnAlignment(.trailing)

                        let url = URL(string: element.value)
                        let text = Text(
                            element.value
                                .trimmingPrefix(/https?:\/\//)
                        )
                        .lineLimit(1)

                        Group {
                            if let url {
                                Link(destination: url) {
                                    text
                                }
                                .contextMenu {
                                    Button("Copy Link") {
                                        NSPasteboard.general.copy(url)
                                    }
                                }
                            } else {
                                text
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !module.localizations.isEmpty {
                    GridRow(alignment: .top) {
                        Text("Languages:")
                            .gridColumnAlignment(.trailing)

                        Text(
                            module.localizations
                                .compactMap {
                                    Locale.current
                                        .localizedString(
                                            forLanguageCode: $0.identifier)
                                }
                                .formatted()
                        )
                        .textSelection(.enabled)
                    }
                }
            }
        }
    }
}
