//
//  ModBrowserToolbar.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/29/25.
//

import SwiftUI
import CkanAPI

struct ModBrowserToolbar: ToolbarContent {
    var instance: GameInstance

    @State private var isRenamingInstance = false
    @State private var editedInstanceName = ""

    @Environment(Store.self) private var store
    @Environment(ModBrowserState.self) private var state

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Edit Instance", systemSymbol: .pencilLine) {
                store.instanceBeingRenamed = instance
            }
            .help("Edit this game instance")
            .popover(isPresented: $isRenamingInstance, arrowEdge: Edge.bottom) {
                Form {
                    TextField("Instance Name:", text: $editedInstanceName)
                        .onAppear {
                            editedInstanceName = instance.name
                        }
                        .onSubmit {
                            instance.rename(editedInstanceName)
                        }
                    Button("Done") {
                        isRenamingInstance = false
                    }
                }
                .padding()
                .frame(width: 400)
            }
            .onChange(of: store.instanceBeingRenamed) {
                isRenamingInstance = store.instanceBeingRenamed == instance
            }
            .onChange(of: isRenamingInstance) {
                if !isRenamingInstance {
                    instance.rename(editedInstanceName)

                    if store.instanceBeingRenamed == instance {
                        store.instanceBeingRenamed = nil
                    }
                }
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                ForEach(SimpleModFilter.allCases) { filter in
                    let binding = Binding {
                        state.search.filters.contains(filter)
                    } set: { enabled in
                        state.search.setFilter(filter, enabled: enabled)
                    }

                    Toggle(
                        String(localized: filter.localizedStringResource),
                        isOn: binding)
                }
            } label: {
                Label("Filters", systemSymbol: .line3HorizontalDecreaseCircle)
                    .foregroundColor(.red)
            }
        }
    }
}
