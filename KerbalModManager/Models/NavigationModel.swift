//
//  NavigationModel.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/4/25.
//

import SwiftUI
import Observation

@Observable final class NavigationModel: Codable {
    var selectedInstanceName: String? = nil

    func jsonData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    init(selectedInstanceName: String? = nil) {
        self.selectedInstanceName = selectedInstanceName
    }

    static func from(jsonData: Data?) -> NavigationModel {
        guard let jsonData else { return NavigationModel() }
        return (try? JSONDecoder().decode(NavigationModel.self, from: jsonData)) ?? NavigationModel()
    }
}
