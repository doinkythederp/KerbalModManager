//
//  ModBrowser.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/5/25.
//

import CkanAPI
import SwiftUI
import WrappingHStack

struct ModBrowser: View {
    var instance: GameInstance

    @Environment(Store.self) private var store: Store
    @Environment(\.ckanActionDelegate) private var ckanActionDelegate

    @State private var loadProgress = 0.0
    @State private var showLoading = false

    @SceneStorage("ModBrowserShowInspector")
    private var showInspector = true

    @State var selectedModules: Set<CkanModule.ID> = Set()
    @State private var sortOrder = [KeyPathComparator(\CkanModule.name)]
    @SceneStorage("ModBrowserTableConfig")
    private var columnCustomization: TableColumnCustomization<CkanModule>

    @FocusState private var tableFocus: Bool

    @ViewBuilder
    func table(modules: [CkanModule]) -> some View {
        Table(
            modules.sorted(using: sortOrder),
            selection: $selectedModules,
            sortOrder: $sortOrder,
            columnCustomization: $columnCustomization
        ) {
            TableColumn("Name", value: \.name)
                .customizationID("name")
                .disabledCustomizationBehavior(.visibility)
            TableColumn("Author", value: \.authorsDescription) { module in
                Text(module.authorsDescription)
            }
            .customizationID("author")
        }
        // prevent content diffing of table when resorting
        // this like means like 10x performance here
        .id(sortOrder)
    }

    var body: some View {
        VStack {
            let modules = instance.compatibleModules.compactMap {
                store.modules[id: $0]
            }

            table(modules: modules)
        }
        .padding()
        .navigationTitle("Mod Browser")
        .navigationSubtitle(instance.name)
        .focusedSceneValue(\.selectedGameInstance, instance)
        .toolbar {
            ModBrowserToolbar(instance: instance)
            ToolbarItemGroup {
                Spacer()
                Button("Toggle Inspector", systemSymbol: .sidebarTrailing) {
                    showInspector.toggle()
                }
            }
        }
        .sheet(isPresented: $showLoading) {
            VStack {
                Text("Loading…")
                ProgressView(value: Double(loadProgress), total: 100)
            }
            .padding()
            .presentationSizing(.form)
        }
        .inspector(isPresented: $showInspector) {
            ModBrowserInspector(selectedModules: selectedModules)
        }
        .task {
            do {
                showLoading = true
                loadProgress = 0

                if !instance.hasPrepopulatedRegistry {
                    try await store.client.prepopulateRegistry(
                        for: instance, with: self)
                }

                loadProgress = 100

                try await store.loadModules(
                    compatibleWith: instance, with: ckanActionDelegate)
                showLoading = false
            } catch {
                print(error.localizedDescription)
                showLoading = false
                loadProgress = 0
                store.ckanError = error as? CkanError
            }
        }
    }
}

extension ModBrowser: CkanActionDelegate {
    nonisolated func handleProgress(_ progress: ActionProgress) async throws {
        print(
            "Progress: \(progress.percentCompletion)% \(progress.message ?? "")"
        )
        await MainActor.run {
            showLoading = true
            loadProgress = Double(progress.percentCompletion)
        }
    }
}

extension CkanModule {
    var versionDescription: String {
        if version.starts(with: "v") {
            version
        } else {
            "v\(version)"
        }
    }
    var authorsDescription: String {
        authors.joined(separator: ", ")
    }
}

private struct ModBrowserInspector: View {
    var selectedModules: Set<CkanModule.ID>

    @Environment(Store.self) private var store

    var body: some View {
        if let moduleId = selectedModules.first,
            let module = store.modules[id: moduleId]
        {
            ScrollView {
                VStack(alignment: .leading) {
                    HStack(alignment: .bottom) {
                        Text(module.name)
                            .bold()

                        Text(module.versionDescription)
                            .foregroundStyle(.secondary)
                    }
                    .font(.title2)

                    HStack(alignment: .top, spacing: 5) {
                        Text("By:")
                        Text(module.authorsDescription)
                    }
                    .foregroundStyle(.secondary)

                    WrappingHStack {
                        ForEach(module.licenses, id: \.self) { license in
                            LicenseTagView(license: license)
                        }
                        if module.releaseStatus != .stable {
                            StabilityTagView(releaseStatus: module.releaseStatus)
                        }
                    }

                    Text(module.abstract)
                        .padding(.vertical, 5)

                    if let description = module.description {
                        Text(description)
                    }

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct ModBrowserToolbar: ToolbarContent {
    var instance: GameInstance

    @State private var isRenamingInstance = false
    @State private var editedInstanceName = ""

    @Environment(Store.self) private var store: Store?

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Edit Instance", systemSymbol: .pencilLine) {
                store?.instanceBeingRenamed = instance
            }
            .help("Edit this game instance")
            .popover(isPresented: $isRenamingInstance, arrowEdge: Edge.bottom) {
                Form {
                    TextField("Instance Name:", text: $editedInstanceName)
                        .onAppear {
                            editedInstanceName = instance.name
                        }
                        .onSubmit {
                            instance.rename(editedInstanceName)
                        }
                    Button("Done") {
                        isRenamingInstance = false
                    }
                }
                .padding()
                .frame(width: 400)
            }
            .onChange(of: store?.instanceBeingRenamed) {
                isRenamingInstance = store?.instanceBeingRenamed == instance
            }
            .onChange(of: isRenamingInstance) {
                if !isRenamingInstance {
                    instance.rename(editedInstanceName)

                    if store?.instanceBeingRenamed == instance {
                        store?.instanceBeingRenamed = nil
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var store = Store()

    ErrorAlertView {
        ModBrowser(instance: GameInstance.samples.first!)
    }
    .frame(width: 800)
    .environment(store)

}
