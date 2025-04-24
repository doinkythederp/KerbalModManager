//
//  Store.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/23/25.
//

import CkanAPI
import Collections
import Foundation
import IdentifiedCollections

@MainActor @Observable final class Store {
    var instances: IdentifiedArrayOf<GUIInstance> = []
    var instanceBeingRenamed: GUIInstance?

    @ObservationIgnored lazy var client = CKANClient()

    var showCkanError = false
    var ckanError: CkanError? {
        didSet {
            showCkanError = ckanError != nil
        }
    }

    func loadInstances(with delegate: CkanActionDelegate)
        async throws(CkanError)
    {
        logger.info("Fetching instances…")
        instances = IdentifiedArray(
            uniqueElements:
                try await client.getInstances(with: delegate)
                .map { GUIInstance($0) })
    }

    func loadModules(
        for instance: GUIInstance,
        with delegate: CkanActionDelegate,
        handleProgress: @escaping (Double) -> Void
    ) async throws(CkanError) {
        logger.info("Fetching modules…")
        try await client.getModules(
            availableTo: instance.ckan,
            with: delegate
        ) { chunk, percentProgress in
            instance.modules.append(
                contentsOf: chunk.map {
                    GUIMod(module: $0, instance: instance)
                })
            handleProgress(percentProgress)
        }
        
        try await refreshModuleStates(for: instance, with: delegate)
    }
    
    func refreshModuleStates(
        for instance: GUIInstance,
        with delegate: CkanActionDelegate
    ) async throws(CkanError) {
        let states = try await client.getModuleStates(for: instance.ckan, with: delegate)
        
        for stateUpdate in states {
            instance.modules[id: stateUpdate.moduleId]?.applyStateUpdate(stateUpdate)
        }
        
        instance.refreshInsights()
    }

    init() {}
}
