//
//  KerbalModManagerApp.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/3/25.
//

import SwiftUI
import os
import CkanAPI

let logger = Logger(
    subsystem: "me.lewismcclelland.KerbalModManager",
    category: "App"
)

@main
struct KerbalModManagerApp: App {
    @State private var store = Store()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ModManagerView()
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            InstanceCommands()
            InspectorCommands()
            ModBrowserCommands()
        }
        .environment(store)
        
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        for process in CKANClient.subprocesses {
            logger.info("Terminating subprocess \(process.processIdentifier)")
            process.terminate()
        }
    }
}
