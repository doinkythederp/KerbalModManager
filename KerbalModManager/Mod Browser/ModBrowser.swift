//
//  ModBrowser.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/5/25.
//

import SwiftUI
import CkanAPI

struct ModBrowser: View {
    var instance: GameInstance

    @State private var isRenamingInstance = false
    @State private var editedInstanceName = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store: Store?

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .padding()
            .navigationTitle("Mod Browser")
            .navigationSubtitle(instance.name)
            .focusedSceneValue(\.selectedGameInstance, instance)
            .toolbar {
//                ToolbarItemGroup(placement: .navigation) {
//                    Button("Select Instance", systemSymbol: .chevronBackward) {
//                        dismiss()
//                    }
//                    .help("Choose another game instance")
//                }

                ToolbarItemGroup(placement: .navigation) {
                    Button("Rename Instance", systemSymbol: .pencilLine) {
                        store?.instanceBeingRenamed = instance
                    }
                    .help("Rename this game instance")
                    .popover(isPresented: $isRenamingInstance, arrowEdge: Edge.bottom) {
                        Form {
                            TextField("Instance Name:", text: $editedInstanceName)
                                .onAppear {
                                    editedInstanceName = instance.name
                                }
                                .onSubmit {
                                    instance.rename(editedInstanceName)
                                }
                                .padding()
                        }
                        .frame(width: 400)
                    }
                }
            }
            .onChange(of: store?.instanceBeingRenamed) {
                isRenamingInstance = store?.instanceBeingRenamed == instance
            }
            .onChange(of: isRenamingInstance) {
                if !isRenamingInstance {
                    instance.rename(editedInstanceName)

                    if store?.instanceBeingRenamed == instance {
                        store?.instanceBeingRenamed = nil
                    }
                }
            }
    }
}

#Preview {
    @Previewable @State var store = Store()

    ModBrowser(instance: GameInstance.samples.first!)
        .frame(width: 600)
        .environment(store)

}
