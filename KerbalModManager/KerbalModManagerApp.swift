//
//  KerbalModManagerApp.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/3/25.
//

import SwiftUI
import os

let logger = Logger(
    subsystem: "me.lewismcclelland.KerbalModManager",
    category: "App"
)

@main
struct KerbalModManagerApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            ModManagerView()
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            InstanceCommands()
        }
        .environment(store)
    }
}
