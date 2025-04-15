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

    var modules: IdentifiedArrayOf<GUIMod> = []

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
        for instance: GUIInstance, with delegate: CkanActionDelegate
    ) async throws(CkanError) {
        logger.info("Fetching modules…")
        let modules = try await client.getModules(
            availableTo: instance.ckan, with: delegate)
        self.modules.append(
            contentsOf: modules.map { GUIMod(module: $0, instance: instance) })

        instance.compatibleModules.formUnion(modules.map(\.id))

    }

    init() {}
}
