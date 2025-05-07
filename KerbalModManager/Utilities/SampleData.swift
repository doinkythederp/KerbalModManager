//
//  SampleData.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/5/25.
//

// This file contains sample data used by previews to help visualize UI during development of the app.
// Sample data using real mods is sourced from NetKAN <https://github.com/KSP-CKAN/NetKAN>, which
// is licensed under CC-0.

import CkanAPI
import Foundation
import SwiftUI
import System

extension GameInstance {
    @MainActor
    static let samples = [
        GameInstance(
            name: "Kerbal Space Program",
            directory: "/Applications/Kerbal Space Program"),
        GameInstance(
            name: "Steam KSP",
            directory: FilePath(
                "\(NSHomeDirectory())/Library/Application Support/Steam/SteamApps/common/Kerbal Space Program"
            )
        ),
    ]
}

extension GUIInstance {
    @MainActor
    static let samples = GameInstance.samples.map { GUIInstance($0) }
}

extension CkanModule {
    @MainActor
    static let samples = [
        CkanModule(
            id: "Parallax",
            releases: [
                Release(
                    id: "Parallax",
                    name: "Parallax",
                    version: .init("1.0.1"),
                    abstract: "A PBR terrain shader for planet surfaces",
                    authors: ["Gameslinx"],
                    licenses: ["CC-BY-NC-ND-4.0"],
                    resources: Release.Resources(
                        homepage:
                            "https://forum.kerbalspaceprogram.com/index.php?/topic/197024-110x-parallax-a-pbr-terrain-shader-100/",
                        spacedock: "https://spacedock.info/mod/2539/Parallax",
                        repository: "https://github.com/Gameslinx/Tessellation"
                    ),
                    tags: ["plugin", "library", "graphics"],
                    releaseDate: Date.now,
                    depends: [
                        Release.Relationship(direct: "Kopernicus"),
                        Release.Relationship(direct: "Parallax-Textures"),
                        // not real, just for visualizing anyOf relationships
                        Release.Relationship(anyOf: ["RealSolarSystem", "JNSQ"]
                        ),
                    ],
                    recommends: [
                        Release.Relationship(direct: "Scatterer")
                    ],
                    downloadUrls: [
                        URL(
                            string:
                                "https://spacedock.info/mod/2539/Parallax/download/1.0.1"
                        )!
                    ],
                    downloadSizeBytes: 445977,
                    downloadCount: 1_568_030
                ),
                Release(
                    id: "Parallax",
                    name: "Parallax",
                    version: .init("1.0.0"),
                    abstract:
                        "A PBR terrain shader for planet surfaces (The old version)",
                    authors: ["Gameslinx"],
                    licenses: ["CC-BY-NC-ND-4.0"],
                    resources: Release.Resources(
                        homepage:
                            "https://forum.kerbalspaceprogram.com/index.php?/topic/197024-110x-parallax-a-pbr-terrain-shader-100/",
                        spacedock: "https://spacedock.info/mod/2539/Parallax",
                        repository: "https://github.com/Gameslinx/Tessellation"
                    ),
                    tags: ["plugin", "library", "graphics"],
                    releaseDate: Date.now - 60,
                    depends: [
                        Release.Relationship(direct: "Kopernicus"),
                        Release.Relationship(direct: "Parallax-Textures"),
                        Release.Relationship(anyOf: ["RealSolarSystem", "JNSQ"]
                        ),
                    ],
                    recommends: [
                        Release.Relationship(direct: "Scatterer")
                    ],
                    downloadUrls: [
                        URL(
                            string:
                                "https://spacedock.info/mod/2539/Parallax/download/1.0.0"
                        )!
                    ],
                    downloadSizeBytes: 445977,
                    downloadCount: 1_568_030
                ),
            ]),
        CkanModule(
            id: "ModuleManager",
            releases: [
                CkanModule.Release(
                    id: "ModuleManager",
                    name: "Module Manager",
                    version: .init("1.0.0"),
                    abstract: "Modify KSP configs without conflict",
                    authors: ["ialdabaoth", "sarbian", "Blowfish"],
                    resources: .init(),
                    releaseDate: .now,
                    downloadSizeBytes: 445977,
                    downloadCount: 1560
                )
            ]),
        CkanModule(
            id: "Astrogator",
            releases: [
                CkanModule.Release(
                    id: "Astrogator",
                    name: "Astrogator",
                    version: .init("1.0.0"),
                    abstract:
                        "A space-navigational aide for Kerbal Space Program",
                    description:
                        "Displays a table of all of the bodies reachable from the current location, along with the time till burn and delta V needed to reach them. These values can be used to time warp or generate maneuver nodes. Supports prograde and retrograde orbits, nested ejection trajectories, transfers to satellites of the current parent body, and transfers to other vessels.",
                    authors: ["HebaruSan"],
                    resources: .init(),
                    releaseDate: .now,
                    downloadSizeBytes: 445977,
                    downloadCount: 213_137
                )
            ]),
        CkanModule(
            id: "xScienceContinued",
            releases: [
                CkanModule.Release(
                    id: "xScienceContinued",
                    name: "[x] Science! Continued",
                    version: .init("1.0.0"),
                    abstract:
                        "The Science Report and Checklist for KSP.  [x] Science! keeps track of the science experiments completed, recovered and held on vehicles and kerbals.",
                    authors: [
                        "Z-Key Aerospace", "Brodrick", "Flupster",
                        "linuxgurugamer",
                    ],
                    licenses: ["CC-BY-NC-SA-4.0"],
                    resources: .init(),
                    releaseDate: .now,
                    downloadSizeBytes: 445977,
                    downloadCount: 344_283
                )
            ]),
        CkanModule(
            id: "KSPCommunityFixes",
            releases: [
                CkanModule.Release(
                    id: "KSPCommunityFixes",
                    name: "KSP Community Fixes",
                    version: .init("1.37.3"),
                    abstract:
                        "Fixes for stock bugs, also provides various QoL/UI improvements",
                    authors: ["Gotmachine"],
                    licenses: ["MIT"],
                    resources: .init(),
                    releaseDate: .now,
                    downloadSizeBytes: 445977,
                    downloadCount: 511_879
                )
            ]),

    ]
}

extension GUIMod {
    @MainActor
    static let samples = CkanModule.samples.enumerated().map {
        (offset, module) in
        GUIMod(
            module: module,
            instance: GUIInstance.samples.first!,
            install: offset == 0
                ? .managed(
                    .init(release: module.releases.first!.id, date: .now))
                : nil
        )
    }
}

struct SampleData: PreviewModifier {
    struct Context {
        var store: Store
        var state: ModBrowserState
    }

    static func makeSharedContext() async throws -> Context {
        let store = Store()
        store.instances.append(contentsOf: GUIInstance.samples)

        let instance = store.instances.first!
        instance.modules.append(contentsOf: GUIMod.samples)
        for module in instance.modules {
            module.isCompatible = true
            instance.index(module: module)
        }

        let state = ModBrowserState(instance: store.instances.first!)

        state.selectedMod = GUIMod.samples.first!.id

        let installingMod = state.instance.modules[id: "ModuleManager"]!
        state.changePlan.set(installingMod, installed: true)

        return Context(store: store, state: state)
    }

    func body(content: Content, context: Context) -> some View {
        ErrorAlertView {
            content
        }
        .environment(context.store)
        .environment(context.state)
    }
}

extension PreviewModifier where Self == SampleData {
    static var sampleData: Self { SampleData() }

}

extension ProcessInfo {
    static var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
 }
