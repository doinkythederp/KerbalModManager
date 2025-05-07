//
//  GUIInstance.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 4/14/25.
//

import AppKit
import CkanAPI
import Collections
import Foundation
import IdentifiedCollections
import Observation

@Observable
final class GUIInstance: Identifiable {
    var id: GameInstance.ID { ckan.id }

    var ckan: GameInstance

    var hasPrepopulatedRegistry = false

    var modules = IdentifiedArray<ModuleId, GUIMod>(id: \.module.id)

    private(set) var compatibleModules = IdentifiedArray<ModuleId, GUIMod>()
    private(set) var installedModules = IdentifiedArray<ModuleId, GUIMod>()

    func index(module: GUIMod) {
        assert(modules.contains(module))

        if module.isCompatible {
            compatibleModules.append(module)
        } else {
            compatibleModules.remove(module)
        }

        if module.install != nil {
            installedModules.append(module)
        } else {
            installedModules.remove(module)
        }
    }
    
    /// Returns a set of all the module releases which will be installed by the given plan, including releases which will
    /// be installed due to a module replacement.
    func modulesInstalled(by plan: ModuleChangePlan) -> Set<ReleaseId> {
        let byInstall = plan.pendingInstallation.values
        
        let byReplace = plan.pendingReplacement
            .compactMap { id in modules[id: id] }
            .compactMap(\.currentRelease.replacedBy)
            .compactMap { relationship in modules[id: relationship.reference] }
            .map(\.currentRelease.id)
        
        return Set(byInstall + byReplace)
    }

    /// Returns an estimate of the set of all the dependencies which installing this set of mods will also install.
    ///
    /// Does not handle version compatability.
    func estimateNewDependencies(of mods: some Sequence<ModuleId>) -> Set<ModuleId> {
        var dependencies: Set<ModuleId> = []

        for id in mods {
            visit(id: id, results: &dependencies)
        }

        dependencies.subtract(mods)
        dependencies.subtract(installedModules.ids)

        return dependencies

        func visit(id: ModuleId, results: inout Set<ModuleId>) {
            if results.contains(id) { return }
            guard let mod = modules[id: id] else { return }

            results.insert(mod.id)

            let recursiveDependencies: [ModuleId] = mod.currentRelease.depends
                .compactMap { relationship in
                    guard case .direct(let direct) = relationship.type else { return nil }
                    return direct.reference
                }

            for dependency in recursiveDependencies {
                visit(id: dependency, results: &results)
            }
        }
    }

    private(set) var insights = Insights()

    func copyDirectoryToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ckan.directory.string, forType: .string)
        pasteboard.setString(ckan.fileURL.absoluteString, forType: .fileURL)
    }

    func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([ckan.fileURL])
    }

    func refreshInsights() {
        insights = Insights(for: self)
    }

    init(_ ckanInstance: GameInstance) {
        self.ckan = ckanInstance
    }

    struct Insights {
        var top10Downloads: Set<ModuleId> = []
        var top100Downloads: Set<ModuleId> = []

        init() {}

        init(for instance: GUIInstance) {
            let topDownloads = instance.modules
                .sorted(
                    using:
                        KeyPathComparator(
                            \.currentRelease.downloadCount,
                            order: .reverse)
                )
                .map(\.id)

            top10Downloads = Set(topDownloads.prefix(10))
            top100Downloads = Set(topDownloads.prefix(100))
        }
    }
}

extension GUIInstance: Equatable {
    static func == (lhs: GUIInstance, rhs: GUIInstance) -> Bool {
        lhs.ckan == rhs.ckan
    }
}
