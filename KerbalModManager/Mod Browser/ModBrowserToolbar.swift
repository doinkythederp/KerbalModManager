//
//  ModBrowserToolbar.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/29/25.
//

import CkanAPI
import SwiftUI

struct ModBrowserToolbar: ToolbarContent {
    var instance: GUIInstance

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
                            editedInstanceName = instance.ckan.name
                        }
                        .onSubmit {
                            instance.ckan.rename(editedInstanceName)
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
                    instance.ckan.rename(editedInstanceName)

                    if store.instanceBeingRenamed == instance {
                        store.instanceBeingRenamed = nil
                    }
                }
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Group {
                @Bindable var state = state

                Button("Apply Changes", systemSymbol: .checkmarkRectangleStack) {
                    state.installStage = .pending
                }
                .sheet(item: $state.installStage) { stage in
                    InstallFlow(stage: stage)
                }

                Button(
                    "Discard Changes",
                    image: .customShippingboxSlash,
                    role: .destructive
                ) {
                    state.changePlan = ModuleChangePlan()
                }
                .help("Discard all pending changes")
            }
            .disabled(state.changePlan.isEmpty)

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
                Label(
                    "Filters",
                    systemSymbol: state.search.filters.isEmpty
                        ? .line3HorizontalDecreaseCircle
                        : .line3HorizontalDecreaseCircleFill
                )
                .foregroundColor(.red)
            }
            .help("Filter which mods appears in the browser")
        }
    }
}
