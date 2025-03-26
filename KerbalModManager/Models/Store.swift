//
//  Store.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/23/25.
//

import Foundation
import CkanAPI
import IdentifiedCollections

@MainActor @Observable final class Store {
    var instances: IdentifiedArrayOf<GameInstance> = []
    var instanceBeingRenamed: GameInstance?

    var modules: IdentifiedArrayOf<CkanModule> = []

    @ObservationIgnored lazy var client = CKANClient()

    func loadInstances(with delegate: CkanActionDelegate) async throws(CkanError) {
        logger.info("Fetching instances…")
        instances = IdentifiedArray(uniqueElements: try await client.getInstances(with: delegate))
    }

    func loadModules(compatibleWith instance: GameInstance, with delegate: CkanActionDelegate) async throws(CkanError) {
        logger.info("Fetching modules…")
        let modules = try await client.getModules(compatibleWith: instance, with: delegate)
        instance.compatibleModules.append(contentsOf: modules)
        self.modules.append(contentsOf: modules)

    }

    init() {}
}
