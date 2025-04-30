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

    init(instance: GUIInstance) {
        self.instance = instance
        state = ModBrowserState(instance: instance)
    }

    @Environment(Store.self) private var store
    @Environment(\.ckanActionDelegate) private var ckanActionDelegate

    @State private var state: ModBrowserState
    @State private var loadProgress = 0.0
    @State private var showLoading = false

    var body: some View {
        ModBrowserTable(instance: instance)
            .sheet(isPresented: $showLoading) {
                VStack {
                    Text("Loading…")
                    ProgressView(value: Double(loadProgress), total: 100)
                }
                .padding()
                .presentationSizing(.form)
            }
            .task {
                await loadData()
            }
            .environment(state)
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
                for: instance, with: ckanActionDelegate
            ) { progress in
                loadProgress = 50 + progress * 50.0
            }

            state.invalidateSearchResults()

            showLoading = false
        } catch {
            logger.error(
                "Loading mod list failed: \(error.localizedDescription)")
            showLoading = false
            loadProgress = 0
            store.ckanError = error
        }
    }
}
struct ModBrowserTable: View {
    var instance: GUIInstance

    @SceneStorage("ModBrowserShowInspector")
    var showInspector = true

    @Environment(Store.self) private var store
    @Environment(ModBrowserState.self) private var state
    @Environment(\.ckanActionDelegate) private var ckanActionDelegate

    @SceneStorage("ModBrowserTableConfig")
    private var columnCustomization: TableColumnCustomization<GUIMod>

    @FocusState private var tableFocus: Bool

    @ViewBuilder
    func table(modules: [GUIMod]) -> some View {
        @Bindable var state = state

        Table(
            modules.sorted(using: state.sortOrder),
            selection: $state.selectedMod,
            sortOrder: $state.sortOrder,
            columnCustomization: $columnCustomization
        ) {
            let downloadIcon = Image(systemSymbol: .arrowDownCircle)

            TableColumn("\(downloadIcon)") { module in
                let status = state.changePlan.status(of: module)

                Toggle("Installed", isOn: .constant(status == .installed))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            .width(26)
            .defaultVisibility(.visible)
            .alignment(.center)
            .customizationID("installed")
            .disabledCustomizationBehavior(.all)

            TableColumn("Name", value: \.currentRelease.name) { mod in
                let status = state.changePlan.status(of: mod)
                ModNameView(name: mod.currentRelease.name, status: status)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .width(ideal: 200)
            .customizationID("name")
            .disabledCustomizationBehavior(.visibility)

            TableColumn("Author", value: \.currentRelease.authorsDescription) {
                module in
                Text(module.currentRelease.authorsDescription)
            }
            .width(min: 100, ideal: 100, max: 200)
            .customizationID("author")

            TableColumn(
                "Downloads",
                sortUsing: KeyPathComparator(\.currentRelease.downloadCount)
            ) {
                module in
                Text(module.currentRelease.downloadCount.formatted())
            }
            .width(70)
            .customizationID("downloadCount")

            TableColumn(
                "Max KSP",
                sortUsing: KeyPathComparator(\.currentRelease.kspVersionMax)
            ) {
                module in
                Text(module.currentRelease.kspVersionMaxDescription)
            }
            .width(70)
            .customizationID("maxVersion")

            TableColumn(
                "Size",
                sortUsing: KeyPathComparator(\.currentRelease.downloadSizeBytes)
            ) {
                module in
                Text(module.currentRelease.downloadSizeBytesDescription)
            }
            .width(70)
            .customizationID("downloadSize")

            TableColumn("Description", value: \.currentRelease.abstract) {
                module in
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
        @Bindable var state = state

        ScrollViewReader { proxy in
            VStack {
                let searchResults = state.queryModules(
                    state.instance.modules, instance: instance)

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
                            .searchCompletion(
                                ModSearchToken(
                                    category: .name,
                                    searchTerm: state.search.text))
                        Text("Description Contains \"\(state.search.text)\"")
                            .searchCompletion(
                                ModSearchToken(
                                    category: .abstract,
                                    searchTerm: state.search.text))
                        Text("Author Contains \"\(state.search.text)\"")
                            .searchCompletion(
                                ModSearchToken(
                                    category: .author,
                                    searchTerm: state.search.text))
                        Text("Has Tag \"\(state.search.text)\"")
                            .searchCompletion(
                                ModSearchToken(
                                    category: .tags,
                                    searchTerm: state.search.text))
                    }
                    Section("Relationships") {
                        Text("Depends on \"\(state.search.text)\"")
                            .searchCompletion(
                                ModSearchToken(
                                    category: .depends,
                                    searchTerm: state.search.text))
                        Text("Recommends \"\(state.search.text)\"")
                            .searchCompletion(
                                ModSearchToken(
                                    category: .recommends,
                                    searchTerm: state.search.text))
                        Text("Suggests \"\(state.search.text)\"")
                            .searchCompletion(
                                ModSearchToken(
                                    category: .suggests,
                                    searchTerm: state.search.text))
                        Text("Conflicts with \"\(state.search.text)\"")
                            .searchCompletion(
                                ModSearchToken(
                                    category: .conflicts,
                                    searchTerm: state.search.text))
                        Text(
                            "Satisfies Dependencies for \"\(state.search.text)\""
                        )
                        .searchCompletion(
                            ModSearchToken(
                                category: .provides,
                                searchTerm: state.search.text))
                    }
                }
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
}

private struct ModNameView: View {
    var name: String
    var status: ModuleChangePlan.Status

    @Environment(\.backgroundProminence) private var backgroundProminence

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).truncationMode(.tail)

            let color =
                switch status {
                case .installed, .autoDetected, .autoInstalled:
                    Color.green
                default:
                    Color.secondary
                }

            let bold =
                switch status {
                case .removing,
                    .upgrading,
                    .replacing,
                    .installing:
                    true
                default: false
                }

            
            if status != .notInstalled {
                Label {
                    Text(status.localizedStringResource)
                } icon: {
                    Image(systemSymbol: status.symbol)
                }
                .bold(bold)
                .foregroundColor(
                    backgroundProminence == .increased ? .secondary : color
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .lineLimit(1)
        .frame(height: 35)
        .opacity(status == .unavailable ? 0.5 : 1)
        .animation(.bouncy, value: status)
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

#Preview("Mod Browser", traits: .modifier(.sampleData)) {
    ModBrowserTable(instance: GUIInstance.samples.first!)
        .frame(width: 800, height: 450)

}

#Preview("Mod Browser (no inspector)", traits: .modifier(.sampleData)) {
    ModBrowserTable(instance: GUIInstance.samples.first!, showInspector: false)
        .frame(width: 800, height: 450)
}

#Preview("Mod Labels") {
    @Previewable @State var toggleableStatus = ModuleChangePlan.Status.notInstalled

    List {
        ModNameView(name: "Astrogator", status: .removing)
        ModNameView(name: "[x] Science! Continued", status: .upgrading)
        ModNameView(name: "KSP Community Fixes", status: .upgradable)
        ModNameView(name: "Double Tap Brakes", status: .autoDetected)
        ModNameView(name: "[x] Science!", status: .replacing)
        ModNameView(name: "Kemini Research Program", status: .replaceable)
        ModNameView(name: "Docking Port Alignment Indicator", status: .unavailable)
        ModNameView(name: "Module Manager", status: .autoInstalled)
        ModNameView(name: "Parallax", status: .installed)
        ModNameView(name: "Scatterer", status: .installing)
        ModNameView(name: "B9 Part Switch", status: toggleableStatus)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                HStack {
                    Spacer()
                    Button("Toggle") {
                        if toggleableStatus == .notInstalled {
                            toggleableStatus = .installing
                        } else if toggleableStatus == .installing {
                            toggleableStatus = .installed
                        } else {
                            toggleableStatus = .notInstalled
                        }
                    }
                }
            }

    }
    .listStyle(.inset)
    .alternatingRowBackgrounds()
    .frame(width: 230, height: 500)
    .background()
}
