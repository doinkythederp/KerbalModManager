//
//  OptionalDependenciesPicker.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 5/2/25.
//

import CkanAPI
import SwiftUI

struct OptionalDependenciesPicker: View {
    var dependencies: OptionalDependencies
    @Binding var shouldSkip: Bool

    init(dependencies: OptionalDependencies, shouldSkip: Binding<Bool>) {
        self.dependencies = dependencies
        self._shouldSkip = shouldSkip

        selectedMods = dependencies.installableRecommended
    }

    @State private var helpShown = false
    @State private var selectedMods: Set<ModuleId>
    @State private var sortOrder = [KeyPathComparator(\Row.release.name)]

    @Environment(ModBrowserState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review Suggested Mods")
                .font(.title2.bold())

            Text("The authors of the mods you're installing suggest that you also install these mods for the best experience.")
                .foregroundStyle(.secondary)

            Text("Additional mods are recommended or suggested:")

            Table(of: Row.self, sortOrder: $sortOrder) {
                TableColumn(Text("\(Image(systemSymbol: .arrowDownCircle))")) { row in
                    OptionalDependencyInstallCheckbox(
                        mod: row.mod.id,
                        selectedMods: $selectedMods
                    )
                }
                .width(16)

                TableColumn("Name", value: \.release.name)
                TableColumn("Version", value: \.release.version.description)
                TableColumn("Suggestion Source") { row in
                    Text(
                        row.dependency.sources
                            .map(\.value)
                            .formatted(.list(type: .and))
                    )
                }
            } rows: {
                Section("Recommended") {
                    ForEach(
                        dependencies.recommended
                            .map(makeRow)
                            .sorted(using: sortOrder)
                    ) { row in
                        TableRow(row)
                    }
                }

                Section("Suggested") {
                    ForEach(
                        dependencies.suggested
                            .map(makeRow)
                            .sorted(using: sortOrder)
                    ) { row in
                        TableRow(row)
                    }
                }

                Section("Supported") {
                    ForEach(
                        dependencies.supporters
                            .map(makeRow)
                            .sorted(using: sortOrder)
                    ) { row in
                        TableRow(row)
                    }
                }
            }
            .tableStyle(.bordered)

            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }

                Toggle("Do not show suggestions again", isOn: $shouldSkip)
                    .padding(.horizontal)
                    .controlSize(.regular)

                Spacer()

                Button("Skip") {
                    selectedMods.removeAll()
                    confirmInstall()
                }
                Button("Confirm") {
                    confirmInstall()
                }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding()
        .frame(minWidth: 600)
        .presentationSizing(.form)
    }

    func confirmInstall() {
        state.installModel.continueInstall()
    }

    func makeRow(dependency: OptionalDependencies.Dependency) -> Row {
        let mod = state.instance.modules[id: dependency.id.moduleId]!
        return Row(dependency: dependency, mod: mod)
    }

    struct Row: Identifiable {
        var id: ReleaseId { dependency.id }

        var dependency: OptionalDependencies.Dependency
        var mod: GUIMod

        var release: CkanModule.Release {
            mod.module.releases[id: id] ?? mod.currentRelease
        }
    }
}

private struct OptionalDependencyInstallCheckbox: View {
    var mod: ModuleId
    @Binding var selectedMods: Set<ModuleId>

    @State private var checked = false

    var body: some View {
        Toggle("Install", isOn: $checked)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .center)
            .onAppear {
                checked = selectedMods.contains(mod)
            }
            .onChange(of: checked) {
                if checked {
                    selectedMods.insert(mod)
                } else {
                    selectedMods.remove(mod)
                }
            }
    }
}

#Preview(traits: .modifier(.sampleData)) {
    @Previewable @State var shouldSkip = false

    let dependencies = OptionalDependencies(
        recommended: [
            .init(id: .init(moduleId: "ModuleManager", version: "1.0.0"), sources: ["Parallax"]),
            .init(id: .init(moduleId: "Parallax", version: "1.0.0"), sources: ["ModuleManager"]),
        ],
        suggested: [
            .init(id: .init(moduleId: "Astrogator", version: "1.0.0"), sources: ["ModuleManager"]),
            .init(id: .init(moduleId: "xScienceContinued", version: "1.0.0"), sources: ["Astrogator"]),
        ],
        supporters: [
            .init(id: .init(moduleId: "KSPCommunityFixes", version: "1.37.3"), sources: ["xScienceContinued"]),
        ],
        installableRecommended: ["ModuleManager"]
    )

    OptionalDependenciesPicker(dependencies: dependencies, shouldSkip: $shouldSkip)
        .background()
}
