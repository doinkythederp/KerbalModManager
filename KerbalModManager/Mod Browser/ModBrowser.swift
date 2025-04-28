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
    var instance: GUIInstance
    
    init(instance: GUIInstance, showInspector: Bool = true) {
        self.instance = instance
        state = ModBrowserState(instance: instance)
        self.showInspector = showInspector
    }

    @Environment(Store.self) private var store: Store
    @Environment(\.ckanActionDelegate) private var ckanActionDelegate

    @State private var loadProgress = 0.0
    @State private var showLoading = false

    @SceneStorage("ModBrowserShowInspector")
    var showInspector = true

    @SceneStorage("ModBrowserTableConfig")
    private var columnCustomization: TableColumnCustomization<GUIMod>

    @State private var state: ModBrowserState

    @FocusState private var tableFocus: Bool

    @ViewBuilder
    func table(modules: [GUIMod]) -> some View {
        Table(
            modules.sorted(using: state.sortOrder),
            selection: $state.selectedMod,
            sortOrder: $state.sortOrder,
            columnCustomization: $columnCustomization
        ) {
            let downloadIcon = Image(systemSymbol: .arrowDownCircle)
            TableColumn("\(downloadIcon)") { module in
                Toggle("Installed", isOn: .constant(false))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            .width(26)
            .defaultVisibility(.visible)
            .alignment(.center)
            .customizationID("installed")
            .disabledCustomizationBehavior(.all)

            TableColumn("Name", value: \.currentRelease.name) { module in
                VStack(alignment: .leading) {
                    Text(module.currentRelease.name)
                        .id(module.id)
                    let state = state.changePlan.status(of: module)
                    Text(String(reflecting: state))
                    switch state {
                    case .removing:
                        Label("Removing", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    case .installed:
                        Label("Installed", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    default:
                        EmptyView()
                    }
                }
            }
            .width(ideal: 200)
            .customizationID("name")
            .disabledCustomizationBehavior(.visibility)

            TableColumn("Author", value: \.currentRelease.authorsDescription) { module in
                Text(module.currentRelease.authorsDescription)
            }
            .width(min: 100, ideal: 100, max: 200)
            .customizationID("author")

            TableColumn("Downloads", sortUsing: KeyPathComparator(\.currentRelease.downloadCount)) {
                module in
                Text(module.currentRelease.downloadCount.formatted())
            }
            .width(70)
            .customizationID("downloadCount")

            TableColumn("Max KSP", sortUsing: KeyPathComparator(\.currentRelease.kspVersionMax)) {
                module in
                Text(module.currentRelease.kspVersionMaxDescription)
            }
            .width(70)
            .customizationID("maxVersion")

            TableColumn("Size", sortUsing: KeyPathComparator(\.currentRelease.downloadSizeBytes)) {
                module in
                Text(module.currentRelease.downloadSizeBytesDescription)
            }
            .width(70)
            .customizationID("downloadSize")

            TableColumn("Description", value: \.currentRelease.abstract) { module in
                Text(module.currentRelease.abstract)
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
                let searchResults = state.queryModules(state.instance.modules, instance: instance)

                table(modules: searchResults.elements)
            }
            .navigationTitle("Mod Browser")
            .navigationSubtitle(instance.ckan.name)
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
                ModInspector().id(state.selectedMod)
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
            // Holding Shift prevents the app from overwriting your current search
            .onModifierKeysChanged(mask: .shift, initial: true) { old, new in
                state.preferNonDestructiveSearches = new.contains(.shift)
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
                    for: instance.ckan, with: self)
            }

            loadProgress = 50

            try await store.loadModules(
                for: instance, with: ckanActionDelegate) { progress in
                    loadProgress = 50 + progress * 50.0
                }
            
            state.invalidateSearchResults()
            
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
        logger.debug(
            "Progress: \(progress.percentCompletion)% \(progress.message ?? "")"
        )
        await MainActor.run {
            showLoading = true
            loadProgress = Double(progress.percentCompletion) / 2.0
        }
    }
}

#Preview("Mod Browser") {
    @Previewable @State var store = Store()

    ErrorAlertView {
        ModBrowser(instance: GUIInstance.samples.first!)
    }
    .frame(width: 800, height: 450)
    .environment(store)

}

#Preview("Mod Browser (no inspector)") {
    @Previewable @State var store = Store()

    ErrorAlertView {
        ModBrowser(instance: GUIInstance.samples.first!, showInspector: false)
    }
    .frame(width: 700, height: 450)
    .environment(store)

}
