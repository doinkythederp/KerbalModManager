//
//  ModInspector.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/28/25.
//

import CkanAPI
import SwiftUI
import WrappingHStack

struct ModInspector: View {
    @State private var showRelationships = true
    @State private var showVersions = true
    @State private var versionOverride: CkanModule.Release?

    @Environment(Store.self) private var store
    @Environment(ModBrowserState.self) private var state

    var body: some View {
        if let moduleId = state.selectedMod,
            let module = store.modules[id: moduleId]
        {
            let current = versionOverride ?? module.currentRelease
            VStack(spacing: 0) {
                if let versionOverride {
                    Button("Show default version", systemSymbol: .chevronBackward) {
                        self.versionOverride = nil
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(5)
                    .background(.windowBackground)
                    
                    Divider()
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {

                        VStack(alignment: .leading) {
                            HStack(alignment: .bottom) {
                                Text(current.name)
                                    .font(.title2.bold())

                                Text(current.versionDescription)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(alignment: .top, spacing: 5) {
                                Text("By:")
                                Text(current.authorsDescription)
                                    .textSelection(.enabled)
                            }
                            .foregroundStyle(.secondary)

                            let downloadStyle =
                                if current.downloadCount > 100_000 {
                                    Color.green
                                } else if current.downloadCount > 10_000 {
                                    Color.orange
                                } else {
                                    Color.secondary
                                }

                            Label(
                                "\(current.downloadCount) downloads",
                                systemSymbol: .arrowDownCircleFill
                            )
                            .symbolRenderingMode(.hierarchical)
                            .padding(.top, 1)
                            .foregroundStyle(downloadStyle)

                            WrappingHStack(
                                alignment: .leading,
                                horizontalSpacing: 3,
                                verticalSpacing: 3
                            ) {
                                ForEach(current.licenses, id: \.self) { license in
                                    LicenseTagView(license: license)
                                }
                                if current.releaseStatus != .stable {
                                    StabilityTagView(
                                        releaseStatus: current.releaseStatus)
                                }
                                ForEach(current.tags, id: \.self) { tag in
                                    CustomTagView(name: tag)
                                }
                            }
                        }

                        Text(current.abstract)
                            .textSelection(.enabled)

                        if let description = current.description {
                            Text(description)
                                .textSelection(.enabled)
                        }

                        ModResourcesView(module: current)
                        ModRelationshipsView(module: current)

                        DisclosureGroup("Versions", isExpanded: $showVersions) {
                            List(module.module.releases) { release in
                                let isViewing = current.id == release.id
                                let isInstalled =
                                    module.install?.version == release.version.value

                                GroupBox {
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(release.versionDescription)

                                            Spacer()

                                            Group {
                                                Button("View", systemSymbol: .eye) {
                                                    versionOverride = release
                                                }
                                                .labelStyle(.iconOnly)
                                                .disabled(current.id == release.id)

                                                Button(
                                                    isInstalled
                                                        ? "Uninstall" : "Install"
                                                ) {

                                                }
                                            }
                                            .controlSize(.small)
                                        }

                                        if isViewing || isInstalled {
                                            HStack {
                                                if isViewing {
                                                    Label(
                                                        "Viewing",
                                                        systemSymbol: .eye)
                                                }

                                                if isInstalled {
                                                    Label(
                                                        "Installed",
                                                        systemSymbol:
                                                            .checkmarkCircle
                                                    )
                                                    .foregroundStyle(.green)
                                                }
                                            }
                                            .foregroundStyle(.secondary)
                                            .font(.callout)
                                        }
                                    }
                                }

                            }
                            .frame(height: 300)
                        }

                        Spacer()
                    }
                    .padding()
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        DownloadSizeIndicator(module: current)
                        Spacer()
                        Button("Install") {}
                    }
                    .padding()
                    .background()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(current.id)
            }
            
            
        } else {
            ContentUnavailableView(
                "Select a Mod", systemSymbol: .magnifyingglassCircle)
        }
    }
}

private struct DownloadSizeIndicator: View {
    var module: CkanModule.Release

    var body: some View {
        if module.downloadSizeBytes + module.installSizeBytes > 0 {
            HStack(spacing: 5) {
                Image(systemSymbol: .arrowDownCircle)
                WrappingHStack(
                    alignment: .leading,
                    horizontalSpacing: 3,
                    verticalSpacing: 3
                ) {
                    if module.downloadSizeBytes > 0 {
                        Text(
                            module.downloadSizeBytes
                                .formatted(.byteCount(style: .file))
                        )
                    }

                    if module.installSizeBytes > 0 {
                        let value = module.installSizeBytes
                            .formatted(.byteCount(style: .file))

                        if module.downloadSizeBytes > 0 {
                            Text("(\(value) on disk)")
                        } else {
                            Text("\(value) on disk")
                        }
                    }

                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Mod Inspector") {
    @Previewable @State var store = Store()
    @Previewable @State var state = ModBrowserState()

    ErrorAlertView {
        ModInspector()
            .onAppear {
                store.modules.append(contentsOf: GUIMod.samples)
                state.selectedMod = store.modules.first!.id
            }
    }
    .frame(width: 270, height: 650)
    .environment(store)
    .environment(state)

}
