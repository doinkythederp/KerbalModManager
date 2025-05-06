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
    @State private var releaseOverride: CkanModule.Release?

    @Environment(Store.self) private var store
    @Environment(ModBrowserState.self) private var state

    var body: some View {
        if let moduleId = state.selectedMod,
            let module = state.instance.modules[id: moduleId]
        {
            let current = releaseOverride ?? module.currentRelease

            VStack(spacing: 0) {
                if releaseOverride != nil {
                    Button(
                        "Show default version", systemSymbol: .chevronBackward
                    ) {
                        self.releaseOverride = nil
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

                                Text(current.version.description)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(alignment: .top, spacing: 5) {
                                Text("By:")
                                Text(current.authorsDescription)
                                    .textSelection(.enabled)
                            }
                            .foregroundStyle(.secondary)

                            Grid(alignment: .center, verticalSpacing: 5) {
                                let insights = state.instance.insights

                                if insights.top100Downloads.contains(module.id)
                                {
                                    let isTop10 = insights.top10Downloads
                                        .contains(module.id)

                                    GridRow {
                                        Image(systemSymbol: .medalStar)
                                        Text(
                                            "Top \(isTop10 ? 10 : 100) most downloaded"
                                        )
                                        .gridCellAnchor(.topLeading)
                                    }
                                    .bold(isTop10)
                                }

                                let downloadStyle =
                                    if current.downloadCount > 100_000 {
                                        Color.green
                                    } else if current.downloadCount > 10_000 {
                                        Color.orange
                                    } else {
                                        Color.secondary
                                    }

                                GridRow {
                                    Image(systemSymbol: .arrowDownCircleFill)
                                    Text("\(current.downloadCount) downloads")
                                        .gridCellAnchor(.topLeading)
                                }
                                .foregroundStyle(downloadStyle)
                            }
                            .symbolRenderingMode(.hierarchical)
                            .padding(.top, 1)

                            WrappingHStack(
                                alignment: .leading,
                                horizontalSpacing: 3,
                                verticalSpacing: 3
                            ) {
                                ForEach(current.licenses, id: \.self) {
                                    license in
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

                        TabView {
                            Tab {
                                VStack(alignment: .leading, spacing: 15) {
                                    ModResourcesView(module: current)
                                    ModRelationshipsView(module: current)
                                }
                                .padding(.horizontal, 5)
                            } label: {
                                Text("Details")
                            }

                            Tab {
                                ModVersionsView(
                                    mod: module,
                                    releaseOverride: $releaseOverride
                                )
                                .padding(.horizontal, 5)
                            } label: {
                                Text("Versions")
                            }
                        }

                        Spacer()
                    }
                    .padding()
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        DownloadSizeIndicator(module: current)
                        Spacer()
                        
                        ModInstallButton(
                            mod: module,
                            release: releaseOverride?.id
                        )
                        .buttonStyle(.borderedProminent)
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
            HStack(alignment: .firstTextBaseline, spacing: 5) {
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

struct ModInstallButton: View {
    var mod: GUIMod
    var release: ReleaseId?

    @Environment(ModBrowserState.self) private var state

    var isInstalled: Bool {
        state.changePlan.isUserInstalled(mod, release: release)
    }

    var body: some View {
        Button {
            state.changePlan.set(mod, installed: !isInstalled, release: release)
        } label: {
            Text(isInstalled ? "Remove": "Install")
                .frame(minWidth: 50)
        }
        .tint(isInstalled ? .red : .green)
        .disabled(mod.isReadOnly)
    }
}

#Preview("Mod Inspector", traits: .modifier(.sampleData)) {
    ModInspector().frame(width: 270, height: 650)
}
