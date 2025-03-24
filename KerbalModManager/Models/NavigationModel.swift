//
//  NavigationModel.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/4/25.
//

import SwiftUI
import Observation
import CkanAPI

enum NavigationDestination: Hashable {
    case modBrowser(GameInstance.ID)
}

@Observable final class NavigationModel {
    var selectedInstance: GameInstance? = nil
    var path: [NavigationDestination] = []

    init() {}

//    func jsonData() -> Data? {
//        try? JSONEncoder().encode(self)
//    }
//
//    static func from(jsonData: Data?) -> NavigationModel {
//        guard let jsonData else { return NavigationModel() }
//        return (try? JSONDecoder().decode(NavigationModel.self, from: jsonData)) ?? NavigationModel()
//    }
}
