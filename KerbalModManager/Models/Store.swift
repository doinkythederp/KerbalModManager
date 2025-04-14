//
//  Store.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/23/25.
//

import Foundation
import CkanAPI
import IdentifiedCollections
import Collections

@MainActor @Observable final class Store {
    var instances: IdentifiedArrayOf<GameInstance> = []
    var instanceBeingRenamed: GameInstance?

    var modules: IdentifiedArrayOf<CkanModule> = []

    @ObservationIgnored lazy var client = CKANClient()

    var showCkanError = false
    var ckanError: CkanError? {
        didSet {
            showCkanError = ckanError != nil
        }
    }

    func loadInstances(with delegate: CkanActionDelegate) async throws(CkanError) {
        logger.info("Fetching instances…")
        instances = IdentifiedArray(uniqueElements: try await client.getInstances(with: delegate))
    }

    func loadModules(for instance: GameInstance, with delegate: CkanActionDelegate) async throws(CkanError) {
        logger.info("Fetching modules…")
        let modules = try await client.getModules(availableTo: instance, with: delegate)
        self.modules.append(contentsOf: modules)

        instance.compatibleModules.formUnion(modules.map(\.id))

    }

    init() {}
}
