//
//  KerbalModManagerApp.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/3/25.
//

import SwiftUI

@main
struct KerbalModManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ModManagerView()
        }
        .defaultSize(width: 800, height: 600)
    }
}
