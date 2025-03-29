//
//  ModBrowser.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/5/25.
//

import CkanAPI
import SwiftUI
import WrappingHStack
import SFSafeSymbols

struct ModBrowser: View {
    var instance: GameInstance

    @Environment(Store.self) private var store: Store
    @Environment(\.ckanActionDelegate) private var ckanActionDelegate

    @State private var loadProgress = 0.0
    @State private var showLoading = false

    @SceneStorage("ModBrowserShowInspector")
    var showInspector = true

    @SceneStorage("ModBrowserTableConfig")
    private var columnCustomization: TableColumnCustomization<CkanModule>

    @State private var state = ModBrowserState()

    @FocusState private var tableFocus: Bool

    @ViewBuilder
    func table(modules: [CkanModule]) -> some View {
        Table(
            modules.sorted(using: state.sortOrder),
            selection: $state.selectedModules,
            sortOrder: $state.sortOrder,
            columnCustomization: $columnCustomization
        ) {
            TableColumn("􀁸") { module in
                Toggle("Installed", isOn: .constant(false))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            .width(26)
            .defaultVisibility(.visible)
            .alignment(.center)
            .customizationID("installed")
            .disabledCustomizationBehavior(.all)

            TableColumn("Name", value: \.name) { module in
                Text(module.name)
                    .id(module.id)
            }
            .width(ideal: 200)
            .customizationID("name")
            .disabledCustomizationBehavior(.visibility)

            TableColumn("Author", value: \.authorsDescription) { module in
                Text(module.authorsDescription)
            }
            .width(min: 100, ideal: 100, max: 200)
            .customizationID("author")

            TableColumn("Max KSP", value: \.kspVersionMaxDescription) { module in
                Text(module.kspVersionMaxDescription)
            }
            .width(70)
            .customizationID("maxVersion")

            TableColumn("Download", value: \.downloadSizeBytesDescription) { module in
                Text(module.downloadSizeBytesDescription)
            }
            .width(70)
            .customizationID("downloadSize")

            TableColumn("Description", value: \.abstract) { module in
                Text(module.abstract)
            }
            .width(ideal: 300)
            .customizationID("abstract")
        }
        // prevent content diffing of table when resorting
        // this like means like 10x performance here
        .id(state.sortOrder)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack {
                let modules = instance.compatibleModules.compactMap {
                    store.modules[id: $0]
                }

                table(modules: modules)
            }
            .navigationTitle("Mod Browser")
            .navigationSubtitle(instance.name)
            .focusedSceneValue(\.selectedGameInstance, instance)
            .toolbar {
                ModBrowserToolbar(instance: instance)
                ToolbarItemGroup {
                    Spacer()
                    Menu {
                        Toggle(isOn: .constant(true)) {
                            Label("Compatible", systemSymbol: .bolt)
//                                .labelStyle(.titleAndIcon)
                        }
                        Toggle(isOn: .constant(false)) {
                            Label("Incompatible", systemSymbol: .boltSlash)
//                                .labelStyle(.titleAndIcon)
                        }
                        Toggle(isOn: .constant(false)) {
                            Label("Installed", systemSymbol: .externaldrive)
//                                .labelStyle(.titleAndIcon)
                        }
                        Toggle(isOn: .constant(false)) {
                            Label("Not Installed", systemSymbol: .externaldriveBadgeXmark)
//                                .labelStyle(.titleAndIcon)
                        }
                        Toggle(isOn: .constant(false)) {
                            Label("Upgradable", systemSymbol: .arrowshapeUp)
//                                .labelStyle(.titleAndIcon)
                        }
                    } label: {
                        Label("Filters", systemSymbol: .line3HorizontalDecreaseCircle)
                    }
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
                ModInspector()
            }
            .searchable(
                text: $state.searchText,
                editableTokens: $state.searchTokens
            ) { $token in
                if let searchTerm = token.searchTerm {
                    Picker(selection: $token.category) {
                        Text("Name").tag(ModSearchToken.Category.name)
                        Text("Author").tag(ModSearchToken.Category.author)
                        Text("Abstract").tag(ModSearchToken.Category.author)
                        Text("Depends").tag(ModSearchToken.Category.author)
                    } label: {
                        Text("\(searchTerm)")
                    }
                } else {
                    Text(token.category.localizedStringResource)
                }
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
            .onAppear {
                state.scrollProxy = proxy
            }
            .environment(state)
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

#Preview("Mod Browser") {
    @Previewable @State var store = Store()

    ErrorAlertView {
        ModBrowser(instance: GameInstance.samples.first!)
    }
    .frame(width: 800, height: 450)
    .environment(store)

}

#Preview("Mod Browser (no inspector)") {
    @Previewable @State var store = Store()

    ErrorAlertView {
        ModBrowser(instance: GameInstance.samples.first!, showInspector: false)
    }
    .frame(width: 700, height: 450)
    .environment(store)

}
