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

    @ObservationIgnored lazy var client = CKANClient()

    func loadInstances(with delegate: CkanActionDelegate) async throws(CkanError) {
        logger.info("Fetching instances…")
        instances = IdentifiedArray(uniqueElements: try await client.getInstances(with: delegate))
    }

    init() {}
}
