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

    @Environment(Store.self) private var store
    @Environment(ModBrowserState.self) private var state

    var body: some View {
        if let moduleId = state.selectedModule,
            let module = store.modules[id: moduleId]
        {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {

                    VStack(alignment: .leading) {
                        HStack(alignment: .bottom) {
                            Text(module.name)
                                .font(.title2.bold())

                            Text(module.versionDescription)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .top, spacing: 5) {
                            Text("By:")
                            Text(module.authorsDescription)
                                .textSelection(.enabled)
                        }
                        .foregroundStyle(.secondary)

                        let downloadStyle = if module.downloadCount > 100_000 {
                            Color.green
                        } else if module.downloadCount > 10_000 {
                            Color.orange
                        } else {
                            Color.secondary
                        }

                        Label(
                            "\(module.downloadCount) downloads",
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
                            ForEach(module.licenses, id: \.self) { license in
                                LicenseTagView(license: license)
                            }
                            if module.releaseStatus != .stable {
                                StabilityTagView(
                                    releaseStatus: module.releaseStatus)
                            }
                            ForEach(module.tags, id: \.self) { tag in
                                CustomTagView(name: tag)
                            }
                        }
                    }

                    Text(module.abstract)
                        .textSelection(.enabled)

                    if let description = module.description {
                        Text(description)
                            .textSelection(.enabled)
                    }

                    ModResourcesView(module: module)
                    ModRelationshipsView(module: module)

                    Spacer()
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    DownloadSizeIndicator(module: module)
                    Spacer()
                    Button("Install") {}
                }
                .padding()
                .background()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(moduleId)
        } else {
            ContentUnavailableView(
                "Select a Mod", systemSymbol: .magnifyingglassCircle)
        }
    }
}

private struct DownloadSizeIndicator: View {
    var module: CkanModule

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
                store.modules.append(contentsOf: CkanModule.samples)
                state.selectedModule = CkanModule.samples.first!.id
            }
    }
    .frame(width: 270, height: 500)
    .environment(store)
    .environment(state)

}
