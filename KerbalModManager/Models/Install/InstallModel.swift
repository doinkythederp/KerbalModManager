//
//  InstallModel.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 5/2/25.
//

import CkanAPI
import Observation

@MainActor
@Observable
final class InstallModel {
    let instance: GUIInstance
    
    var stage: Stage?
    
    func showPendingChanges() {
        stage = .pending
    }
    
    func run(plan: ModuleChangePlan, store: Store) async throws(CkanError) {
        logger.info("Running install plan")
        
        let optionalDeps = try await store.client.resolveOptionalDependencies(
            for: instance.ckan,
            modules: instance.modulesInstalled(by: plan),
            with: EmptyCkanActionDelegate()
        )
        
        logger.info("Discovered optional dependencies for install plan: \(optionalDeps.recommended.count) recommended, \(optionalDeps.suggested.count) suggested, \(optionalDeps.supporters.count) supporters")
        
//        if !optionalDeps.isEmpty {
            stage = .pickOptionalDependencies(optionalDeps)
//        }
        
        
        logger.info("Install complete")
    }
    
    func cancel() {
        stage = nil
    }
    
    init(instance: GUIInstance) {
        self.instance = instance
    }
    
    enum Stage: Equatable, Hashable, Identifiable {
        case pending
        case pickOptionalDependencies(OptionalDependencies)

        var id: Self { self }
    }
}
