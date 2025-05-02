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

    @Environment(ModBrowserState.self) private var state

    var body: some View {
        let currentRelease = releaseOverride ?? mod.currentRelease

        VStack {
            ForEach(mod.module.releases) { release in
                let isViewing = currentRelease.id == release.id
                let displayedStatus = displayedStatus(for: release.id)

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

                                ModInstallButton(mod: mod, release: release.id)
                            }
                            .controlSize(.small)
                        }

                        if isViewing || displayedStatus != .notInstalled {
                            HStack {
                                if displayedStatus != .notInstalled {
                                    ModStatusLabel(status: displayedStatus)
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
    }

    func displayedStatus(for releaseId: ReleaseId) -> ModuleChangePlan.Status {
        let isInstalledNow = mod.installedRelease?.id == releaseId
        let willBeInstalled = state.changePlan.isUserInstalled(mod, release: releaseId)

        let displayedStatus: ModuleChangePlan.Status
        if isInstalledNow {
            if willBeInstalled {
                displayedStatus = .installed
            } else {
                displayedStatus = .removing
            }
        } else {
            if willBeInstalled {
                displayedStatus = .installing
            } else {
                displayedStatus = .notInstalled
            }
        }

        return displayedStatus
    }
}

#Preview("Mod Versions", traits: .modifier(.sampleData)) {
    @Previewable @Environment(Store.self) var store
    @Previewable @State var releaseOverride: CkanModule.Release?

    ModVersionsView(
        mod: store.instances.first!.modules.first!,
        releaseOverride: $releaseOverride
    )
    .padding(.horizontal)
    .frame(width: 270, height: 350)

}
