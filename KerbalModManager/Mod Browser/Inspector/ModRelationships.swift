//
//  ModRelationships.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/28/25.
//

import CkanAPI
import SFSafeSymbols
import SwiftUI

struct ModRelationshipsView: View {
    var module: CkanModule

    @State private var isExpanded = true
    @State private var isProvidesHelpShown = false

    @Environment(ModBrowserState.self) private var state

    var body: some View {
        DisclosureGroup("Relationships", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                ModRelationshipsSection(module.depends) {
                    Label("Dependencies", systemSymbol: .linkCircle)
                } help: {
                    Text(
                        "This mod only functions when the following mods are installed alongside it."
                    )
                }
                ModRelationshipsSection(module.recommends) {
                    Label("Recommendations", systemSymbol: .starCircle)
                } help: {
                    Text(
                        "This mod works best when the following mods are installed alongside it."
                    )
                }
                ModRelationshipsSection(module.suggests) {
                    Label("Suggestions", systemSymbol: .heartCircle)
                } help: {
                    Text(
                        "This mod is enhanced when the following mods are installed, but they might not be for everyone."
                    )
                }
                ModRelationshipsSection(module.conflicts) {
                    Label("Conflicts", systemSymbol: .xmarkCircle)
                } help: {
                    Text(
                        "This mod does not work properly when the following mods are installed."
                    )
                }

                Divider()

                ModRelationshipsSection(dependencyCategories: module.provides) {
                    Label(
                        "Dependency Categories", systemSymbol: .cubeTransparent)
                } help: {
                    Text(
                        """
                            This mod has declared that it fits into the following categories.
                            Other mods may require a mod from one of these categories to be installed in order to function properly.
                        """)
                }

                Button("Find Dependents", systemSymbol: .magnifyingglass) {
                    state.search(tokens: [
                        ModSearchToken(
                            category: .depends, searchTerm: module.name)
                    ])
                }
                .controlSize(.small)
                .help(
                    "Click to search for mods that require this one to be installed to function properly, or Shift-click to add to the current search."
                )
            }
        }
    }
}

private struct ModRelationshipsSection<Header: View, Help: View>: View {
    private enum Data {
        case normal([CkanModule.Relationship])
        case dependencyCategories([String])

        var isEmpty: Bool {
            switch self {
            case .normal(let list): list.isEmpty
            case .dependencyCategories(let list): list.isEmpty
            }
        }
    }

    private var data: Data

    private var header: () -> Header
    private var help: () -> Help

    init(
        _ relationships: [CkanModule.Relationship],
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder help: @escaping () -> Help
    ) {
        self.data = .normal(relationships)
        self.header = header
        self.help = help
    }

    init(
        dependencyCategories: [String],
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder help: @escaping () -> Help
    ) {
        self.data = .dependencyCategories(dependencyCategories)
        self.header = header
        self.help = help
    }

    @State private var helpShown = false
    @Environment(Store.self) private var store
    @Environment(ModBrowserState.self) private var state

    var body: some View {
        Section {
            if data.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
                    .padding(2)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading) {
                    switch data {
                    case .normal(let relationships):
                        ForEach(relationships) { relationship in
                            ModRelationshipView(relationship: relationship)
                        }
                    case .dependencyCategories(let categories):
                        ForEach(categories, id: \.self) { category in
                            ModDependencyCategoryView(name: category)
                        }

                    }
                }
                .padding(.leading)
            }
        } header: {
            HStack {
                header()

                HelpLink {
                    helpShown.toggle()
                }
                .popover(isPresented: $helpShown) {
                    help()
                        .padding()
                        .multilineTextAlignment(.center)
                        .presentationSizing(.page)
                }
                .controlSize(.small)
            }
        }
    }
}

private struct ModRelationshipView: View {
    var relationship: CkanModule.Relationship

    @Environment(Store.self) private var store
    @Environment(ModBrowserState.self) private var state

    var body: some View {
        switch relationship.type {
        case .direct(let direct):
            GroupBox {
                HStack {
                    let name =
                        store.modules[id: direct.name]?.name ?? direct.name

                    let isRealModule = store.modules.ids.contains(direct.name)

                    Label(
                        name,
                        systemSymbol: isRealModule
                            ? .shippingboxFill
                            : .cubeTransparent
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .labelStyle(.titleAndIcon)
                    Spacer()

                    Button {
                        show(direct.name)
                    } label: {
                        if isRealModule {
                            Label("View", systemSymbol: .eye)
                        } else {
                            Label("Search", systemSymbol: .magnifyingglass)
                        }

                    }
                    .controlSize(.small)
                    .labelStyle(.iconOnly)
                    .help(
                        isRealModule
                            ? "Click to view details about this mod."
                            : "Click to search for mods satisfying this requirement, or Shift-click to add to the current search."
                    )
                }
            }
        case .anyOf(allowedModules: let allowed):
            Text("One of:")
                .font(.caption)
                .padding(.top, 1)
            VStack {
                ForEach(allowed) { item in
                    ModRelationshipView(relationship: item)
                }
            }
            .padding(.leading)
            .padding(.bottom, 4)
        }
    }

    func show(_ targetId: String) {
        if let module = store.modules[id: targetId] {
            state.reveal(module: module)
            return
        }

        // Something `provides` this relationship, it's not a real module
        state.search(tokens: [
            ModSearchToken(category: .provides, searchTerm: targetId)
        ])
    }
}

private struct ModDependencyCategoryView: View {
    var name: String

    @Environment(ModBrowserState.self) private var state

    var body: some View {
        GroupBox {
            HStack {
                Label(
                    name,
                    systemSymbol: .cubeTransparentFill
                )

                Spacer()

                Button("Search", systemSymbol: .magnifyingglass) {
                    state.search(tokens: [
                        ModSearchToken(category: .depends, searchTerm: name)
                    ])
                }
                .labelStyle(.iconOnly)
                .controlSize(.small)
                .help(
                    "Click to search for mods that depend on this category, or Shift-click to add to the current search."
                )
            }
        }
    }
}
