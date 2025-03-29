//
//  ModBrowser.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/5/25.
//

import CkanAPI
import IdentifiedCollections
import SFSafeSymbols
import SwiftUI
import WrappingHStack

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

            TableColumn("Downloads", sortUsing: KeyPathComparator(\.downloadCount)) {
                module in
                Text(module.downloadCount.formatted())
            }
            .width(70)
            .customizationID("downloadCount")

            TableColumn("Max KSP", sortUsing: KeyPathComparator(\.kspVersionMax)) {
                module in
                Text(module.kspVersionMaxDescription)
            }
            .width(70)
            .customizationID("maxVersion")

            TableColumn("Size", sortUsing: KeyPathComparator(\.downloadSizeBytes)) {
                module in
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
                let searchResults = state.searchModules(store.modules, instance: instance)

                table(modules: searchResults.elements)
            }
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
                ModInspector()
            }
            .searchable(
                text: $state.search.text,
                editableTokens: $state.search.tokens,
                isPresented: $state.isSearchPresented
            ) { $token in
                Picker(selection: $token.category) {
                    ForEach(ModSearchToken.Category.allCases) { category in
                        Text(category.localizedStringResource)
                    }
                } label: {
                    Text("\(token.searchTerm)")
                }
            }
            .searchSuggestions {
                let text = state.search.text
                if !text.isEmpty {
                    Section("Details") {
                        Text("Name Contains \"\(state.search.text)\"")
                            .searchCompletion(ModSearchToken(
                                category: .name,
                                searchTerm: state.search.text))
                        Text("Description Contains \"\(state.search.text)\"")
                            .searchCompletion(ModSearchToken(
                                category: .abstract,
                                searchTerm: state.search.text))
                        Text("Author Contains \"\(state.search.text)\"")
                            .searchCompletion(ModSearchToken(
                                category: .author,
                                searchTerm: state.search.text))
                        Text("Has Tag \"\(state.search.text)\"")
                            .searchCompletion(ModSearchToken(
                                category: .tags,
                                searchTerm: state.search.text))
                    }
                    Section("Relationships") {
                        Text("Depends on \"\(state.search.text)\"")
                            .searchCompletion(ModSearchToken(
                                category: .depends,
                                searchTerm: state.search.text))
                        Text("Recommends \"\(state.search.text)\"")
                            .searchCompletion(ModSearchToken(
                                category: .recommends,
                                searchTerm: state.search.text))
                        Text("Suggests \"\(state.search.text)\"")
                            .searchCompletion(ModSearchToken(
                                category: .suggests,
                                searchTerm: state.search.text))
                        Text("Conflicts with \"\(state.search.text)\"")
                            .searchCompletion(ModSearchToken(
                                category: .conflicts,
                                searchTerm: state.search.text))
                        Text("Satisfies Dependencies for \"\(state.search.text)\"")
                            .searchCompletion(ModSearchToken(
                                category: .provides,
                                searchTerm: state.search.text))
                    }
                }
            }
            .task {
                await loadData()
            }
            .onAppear {
                state.scrollProxy = proxy
            }
            .onChange(of: state.modulePendingReveal) {
                if let request = state.modulePendingReveal {
                    // Scroll to requested value, and do it after the search has been recalculated.
                    Task {
                        proxy.scrollTo(request, anchor: .leading)
                    }
                    state.modulePendingReveal = nil
                }
            }
            .focusedSceneValue(\.modBrowserState, state)
            .environment(state)
        }
    }

    func loadData() async {
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
            logger.error("Loading mod list failed: \(error.localizedDescription)")
            showLoading = false
            loadProgress = 0
            store.ckanError = error
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
