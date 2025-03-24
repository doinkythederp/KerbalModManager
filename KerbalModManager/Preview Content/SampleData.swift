//
//  SampleData.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/5/25.
//

import CkanAPI
import System
import Foundation

extension GameInstance {
    @MainActor
    static let samples = [
        GameInstance(
            name: "Global Kerbal Space Program",
            directory: "/Applications/Kerbal Space Program"),
        GameInstance(
            name: "Steam KSP",
            directory: FilePath(
                "\(NSHomeDirectory())/Library/Application Support/Steam/SteamApps/common/Kerbal Space Program"
            )
        ),
    ]
}
