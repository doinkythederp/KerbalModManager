//
//  InstallView.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 5/2/25.
//

import CkanAPI
import IdentifiedCollections
import SFSafeSymbols
import SwiftUI

struct InstallView: View {
    @Environment(ModBrowserState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading) {
            Text("Pending Changes")
                .font(.title2.bold())
            Text(
                "The following mods will be installed, upgraded, or removed:"
            )

            List(changes) { change in
                InstallListItem(change: change)
            }
            .alternatingRowBackgrounds()
            .environment(\.defaultMinListRowHeight, 40)
            
            HStack {
                Button(role: .destructive) {
                    state.changePlan.removeAll()
                    dismiss()
                } label: {
                    Label("Discard Changes", systemSymbol: .trash)
                        .foregroundStyle(.red)
                }
                
                Spacer()
                
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button("Confirm") {}
                    .keyboardShortcut(.defaultAction)
                    
            }
            .controlSize(.large)
        }
        .padding()
        .presentationSizing(.form)
    }

    var changes: IdentifiedArrayOf<Change> {
        var changes: IdentifiedArrayOf<Change> = []

        for releaseId in state.changePlan.pendingInstallation.values {
            let mod = state.instance.modules[id: releaseId.moduleId]

            if let mod, let install = mod.install {
                changes.append(
                    Change(
                        id: releaseId.moduleId,
                        type: .upgrade(new: releaseId, old: install.release)))
            } else {
                changes.append(
                    Change(
                        id: releaseId.moduleId,
                        type: .install(release: releaseId)))
            }
        }

        for moduleId in state.changePlan.pendingRemoval {
            changes.append(Change(id: moduleId, type: .remove))
        }

        for moduleId in state.changePlan.pendingReplacement {
            changes.append(Change(id: moduleId, type: .replace))
        }

        return changes
    }

    struct Change: Identifiable {
        var id: ModuleId
        var type: ChangeType
    }

    enum ChangeType: Hashable {
        case install(release: ReleaseId)
        case upgrade(new: ReleaseId, old: ReleaseId?)
        case remove
        case replace

        var status: ModuleChangePlan.Status {
            switch self {
            case .install:
                .installing
            case .upgrade(_, _):
                .upgrading
            case .remove:
                .removing
            case .replace:
                .replacing
            }
        }
    }
}

private struct InstallListItem: View {
    var change: InstallView.Change
    
    @Environment(ModBrowserState.self) private var state
    
    var body: some View {
        HStack(spacing: 20) {
            let mod = state.instance.modules[id: change.id]
            let release: CkanModule.Release? = switch change.type {
            case .install(release: let releaseId):
                mod?.module.releases[id: releaseId]
            case .upgrade(_, _):
                nil
            default:
                mod?.installedRelease
            }
            
            Image(systemSymbol: change.type.status.symbol)
                .foregroundStyle(change.type.status.color)
            
            let name = if let release {
                Text("\(release.name) \(release.version)")
                    .bold()
            } else if let mod {
                Text("\(mod.currentRelease.name)")
                    .bold()
            } else {
                Text("\(change.id)")
                    .foregroundStyle(.red)
            }
            

            switch change.type {
            case .install(_):
                Text("\(name) will be installed.")
            case .upgrade(new: let releaseId, _):
                if let release = mod?.module.releases[id: releaseId] {
                    Text("\(name) will be upgraded to **\(release.version.description)**.")
                } else {
                    Text("\(name) will be upgraded.")
                }
            case .remove:
                Text("\(name) will be removed.")
            case .replace:
                if let release,
                   let replacedBy = release.replacedBy?.type,
                   case .direct(let direct) = replacedBy
                {
                    let replacement = if let module = state.instance.modules[id: direct.reference] {
                        module.currentRelease.name
                    } else {
                        direct.reference.value
                    }
                    
                    Text("\(name) will be replaced by **\(replacement)**.")
                } else {
                    Text("\(name) will be replaced.")
                }
            }
        }
        .font(.system(size: 16))
        .padding(.horizontal)
    }
}

#Preview(traits: .modifier(.sampleData)) {
    InstallView()
}
