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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .padding()
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Select Instance", systemSymbol: .chevronBackward) {
                        dismiss()
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
            .navigationTitle(instance.name)
    }
}

#Preview {
    ModBrowser(instance: GameInstance.samples.first!)
}
