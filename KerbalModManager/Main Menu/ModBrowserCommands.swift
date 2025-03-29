//
//  ModBrowserCommands.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/28/25.
//

import SwiftUI

struct ModBrowserCommands: Commands {
    @FocusedValue(\.modBrowserState) private var modBrowserState

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Section {
                Button("Search Mods…") {
                    modBrowserState?.isSearchPresented.toggle()
                }
                .keyboardShortcut("F")
            }
            .disabled(modBrowserState == nil)
        }
    }
}
