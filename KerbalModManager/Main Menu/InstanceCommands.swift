//
//  InstanceCommands.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/23/25.
//

import SwiftUI

struct InstanceCommands: Commands {
    @Environment(Store.self) private var store
    @FocusedValue(\.selectedGameInstance) private var selectedInstance

    var body: some Commands {
        CommandMenu("Instance") {
            Section {
                Button("Rename…") {
                    store.instanceBeingRenamed = selectedInstance
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])
            }
            .disabled(selectedInstance == nil)

            Section {
                Button("Show in Finder") {
                    selectedInstance?.openInFinder()
                }

                let copyLabel: LocalizedStringKey = if let selectedInstance {
                    "Copy \"\(selectedInstance.name)\" as Pathname"
                } else {
                    "Copy as Pathname"
                }

                Button(copyLabel) {
                    selectedInstance?.copyDirectory()
                }
                .keyboardShortcut("C", modifiers: [.command, .option])
            }
            .disabled(selectedInstance == nil)
        }
    }
}
