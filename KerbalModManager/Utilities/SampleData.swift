//
//  SampleData.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/5/25.
//

import CkanAPI
import Foundation
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
                        Release.Relationship(anyOf: ["RealSolarSystem", "JNSQ"]),  // not real, just for visualizing anyOf relationships
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
                )
            ])

    ]
}

extension GUIMod {
    @MainActor
    static let samples = CkanModule.samples.map {
        GUIMod(
            module: $0,
            instance: GUIInstance.samples.first!,
            install: .managed(.init(date: .now, version: $0.releases.first!.version.value))
        )
    }
}
