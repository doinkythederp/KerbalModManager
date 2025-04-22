//
//  ModVersions.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 4/18/25.
//

import CkanAPI
import SwiftUI

struct ModVersionsView: View {
    var mod: GUIMod
    @Binding var releaseOverride: CkanModule.Release?

    @State private var expanded = true

    var body: some View {
        let currentRelease = releaseOverride ?? mod.currentRelease

        DisclosureGroup("Versions", isExpanded: $expanded) {
            VStack {
                ForEach(mod.module.releases) { release in
                    let isViewing = currentRelease.id == release.id
                    let isInstalled =
                    mod.install?.version == release.version.value

                    GroupBox {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(release.versionDescription)

                                Spacer()

                                Group {
                                    Button("View", systemSymbol: .eye) {
                                        releaseOverride = release
                                    }
                                    .labelStyle(.iconOnly)
                                    .disabled(currentRelease.id == release.id)

                                    Button(
                                        isInstalled
                                        ? "Uninstall" : "Install"
                                    ) {
                                        // TODO
                                    }
                                }
                                .controlSize(.small)
                            }

                            if isViewing || isInstalled {
                                HStack {
                                    if isInstalled {
                                        Label(
                                            "Installed",
                                            systemSymbol:
                                                    .checkmarkCircle
                                        )
                                        .foregroundStyle(.green)
                                    }

                                    if isViewing {
                                        Label(
                                            "Viewing",
                                            systemSymbol: .eye)
                                    }
                                }
                                .foregroundStyle(.secondary)
                                .font(.callout)
                            }
                        }
                    }
                }
            }
            .padding(5)
        }
    }
}

#Preview("Mod Versions", traits: .modifier(.sampleData)) {
    @Previewable @Environment(Store.self) var store
    @Previewable @State var releaseOverride: CkanModule.Release?

    ModVersionsView(
        mod: store.instances.first!.modules.first!, releaseOverride: $releaseOverride
    )
    .padding(.horizontal)
    .frame(width: 270, height: 350)

}
