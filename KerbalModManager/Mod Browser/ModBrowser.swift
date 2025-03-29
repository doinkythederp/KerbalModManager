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
                ModBrowserInspector()
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

private extension CkanModule {
    var versionDescription: String {
        if version.starts(with: "v") {
            version
        } else {
            "v\(version)"
        }
    }
    var authorsDescription: String {
        authors.formatted()
    }

    static func formatVersion(_ version: GameVersion?) -> LocalizedStringResource {
        return if let version {
            "\(version.description)"
        } else {
            "any"
        }
    }

    var kspVersionMaxDescription: String {
        String(localized: Self.formatVersion(kspVersionMax))
    }

    var downloadSizeBytesDescription: String {
        downloadSizeBytes.formatted(.byteCount(style: .file))
    }
}

private struct ModBrowserInspector: View {
    @State private var showRelationships = true

    @Environment(Store.self) private var store
    @Environment(ModBrowserState.self) private var state

    var body: some View {
        if let moduleId = state.selectedModules.first,
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

                        WrappingHStack {
                            ForEach(module.licenses, id: \.self) { license in
                                LicenseTagView(license: license)
                            }
                            if module.releaseStatus != .stable {
                                StabilityTagView(
                                    releaseStatus: module.releaseStatus)
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

private struct DownloadSizeIndicator: View {
    var module: CkanModule

    var body: some View {
        if module.downloadSizeBytes + module.installSizeBytes > 0 {
            HStack(spacing: 5) {
                Image(systemSymbol: .arrowDownCircle)
                WrappingHStack(spacing: .constant(3)) {
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

private struct ModResourcesView: View {
    var module: CkanModule

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup("Details and Links", isExpanded: $isExpanded) {
            Grid(alignment: .leading) {
                let collection = module.resources.collection
                ForEach(collection.elements, id: \.key) { element in
                    GridRow {
                        Text("\(element.key):")
                            .gridColumnAlignment(.trailing)

                        let url = URL(string: element.value)
                        let text = Text(
                            element.value
                                .trimmingPrefix(/https?:\/\//)
                        )
                        .lineLimit(1)

                        Group {
                            if let url {
                                Link(destination: url) {
                                    text
                                }
                                .contextMenu {
                                    Button("Copy Link") {
                                        NSPasteboard.general.copy(url)
                                    }
                                }
                            } else {
                                text
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !module.localizations.isEmpty {
                    GridRow(alignment: .top) {
                        Text("Languages:")
                            .gridColumnAlignment(.trailing)

                        Text(
                            module.localizations
                                .compactMap {
                                    Locale.current
                                        .localizedString(
                                            forLanguageCode: $0.identifier)
                                }
                                .formatted()
                        )
                        .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

private struct ModRelationshipsView: View {
    var module: CkanModule

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup("Relationships", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                ModRelationshipsSection(module.depends) {
                    Label("Dependencies", systemSymbol: .linkCircle)
                } help: {
                    Text(
                        "This mod only functions when the following mods are installed alongside it."
                    )
                }
                ModRelationshipsSection(module.recommends) {
                    Label("Recommendations", systemSymbol: .starCircle)
                } help: {
                    Text(
                        "This mod works best when the following mods are installed alongside it."
                    )
                }
                ModRelationshipsSection(module.suggests) {
                    Label("Suggestions", systemSymbol: .heartCircle)
                } help: {
                    Text(
                        "This mod is enhanced when the following mods are installed, but they might not be for everyone."
                    )
                }
                ModRelationshipsSection(module.conflicts) {
                    Label("Conflicts", systemSymbol: .xmarkCircle)
                } help: {
                    Text(
                        "This mod does not work properly when the following mods are installed."
                    )
                }
            }
        }
    }
}

private struct ModRelationshipsSection<Header: View, Help: View>: View {
    var relationships: [CkanModule.Relationship]

    var header: () -> Header
    var help: () -> Help

    init(
        _ relationships: [CkanModule.Relationship],
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder help: @escaping () -> Help
    ) {
        self.relationships = relationships
        self.header = header
        self.help = help
    }

    @State private var helpShown = false
    @Environment(Store.self) private var store
    @Environment(ModBrowserState.self) private var state

    var body: some View {
        Section {
            if relationships.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
                    .padding(2)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading) {
                    ForEach(relationships) { relationship in
                        self.relationship(relationship)
                    }
                }
                .padding(.leading)
            }
        } header: {
            HStack {
                header()

                HelpLink {
                    helpShown.toggle()
                }
                .popover(isPresented: $helpShown) {
                    help().padding()
                }
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    func relationship(
        _ relationship: CkanModule.Relationship
    ) -> some View {
        switch relationship.type {
        case .direct(let direct):
            GroupBox {
                HStack {
                    let name = store.modules[id: direct.name]?.name ?? direct.name

                    Text(name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Button {
                        viewRelationshipTarget(direct.name)
                    } label: {
                        if store.modules.ids.contains(direct.name) {
                            Label("View", systemSymbol: .eye)
                        } else {
                            Label("Search", systemSymbol: .magnifyingglass)
                        }

                    }
                    .controlSize(.small)
                }
                .labelStyle(.iconOnly)
            }
        case .anyOf(allowedModules: let allowed):
            Text("One of:")
                .font(.caption)
                .padding(.top, 1)
            VStack {
                ForEach(allowed) { item in
                    AnyView(self.relationship(item))
                }
            }
            .padding(.leading)
            .padding(.bottom, 4)
        }
    }

    func viewRelationshipTarget(_ targetId: String) {
        if store.modules.ids.contains(targetId) {
            // This is a real module

            state.selectedModules = [targetId]
            state.scrollProxy?.scrollTo(targetId, anchor: .center)
        } else {
            // Something `satisfies` this relationship, it's not a real module

            // TODO: add this once there is searching
        }
    }
}

#Preview {
    @Previewable @State var store = Store()

    ErrorAlertView {
        ModBrowser(instance: GameInstance.samples.first!)
    }
    .frame(width: 800, height: 450)
    .environment(store)

}

#Preview("Inspector") {
    @Previewable @State var store = Store()
    @Previewable @State var state = ModBrowserState()

    ErrorAlertView {
        ModBrowserInspector()
            .onAppear {
                store.modules.append(contentsOf: CkanModule.samples)
                state.selectedModules = [CkanModule.samples.first!.id]
            }
    }
    .frame(width: 270, height: 500)
    .environment(store)
    .environment(state)

}
