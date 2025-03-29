//
//  ModRelationships.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/28/25.
//

import SwiftUI
import CkanAPI

struct ModRelationshipsView: View {
    var module: CkanModule

    @State private var isExpanded = true

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
            }
        }
    }
}

private struct ModRelationshipsSection<Header: View, Help: View>: View {
    var relationships: [CkanModule.Relationship]

    var header: () -> Header
    var help: () -> Help

    init(
        _ relationships: [CkanModule.Relationship],
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder help: @escaping () -> Help
    ) {
        self.relationships = relationships
        self.header = header
        self.help = help
    }

    @State private var helpShown = false
    @Environment(Store.self) private var store
    @Environment(ModBrowserState.self) private var state

    var body: some View {
        Section {
            if relationships.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
                    .padding(2)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading) {
                    ForEach(relationships) { relationship in
                        self.relationship(relationship)
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
                    help().padding()
                }
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    func relationship(
        _ relationship: CkanModule.Relationship
    ) -> some View {
        switch relationship.type {
        case .direct(let direct):
            GroupBox {
                HStack {
                    let name = store.modules[id: direct.name]?.name ?? direct.name

                    Text(name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Button {
                        viewRelationshipTarget(direct.name)
                    } label: {
                        if store.modules.ids.contains(direct.name) {
                            Label("View", systemSymbol: .eye)
                        } else {
                            Label("Search", systemSymbol: .magnifyingglass)
                        }

                    }
                    .controlSize(.small)
                }
                .labelStyle(.iconOnly)
            }
        case .anyOf(allowedModules: let allowed):
            Text("One of:")
                .font(.caption)
                .padding(.top, 1)
            VStack {
                ForEach(allowed) { item in
                    AnyView(self.relationship(item))
                }
            }
            .padding(.leading)
            .padding(.bottom, 4)
        }
    }

    func viewRelationshipTarget(_ targetId: String) {
        if store.modules.ids.contains(targetId) {
            // This is a real module

            state.selectedModules = [targetId]
            state.scrollProxy?.scrollTo(targetId, anchor: .leading)
        } else {
            // Something `satisfies` this relationship, it's not a real module

            // TODO: add this once there is searching
        }
    }
}
