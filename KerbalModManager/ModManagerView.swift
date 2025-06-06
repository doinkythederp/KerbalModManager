//
//  ContentView.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/3/25.
//

import CkanAPI
import SwiftUI

struct ModManagerView: View, CkanActionDelegate {
    @Environment(Store.self) private var store

    @State private var navigationModel = NavigationModel()

    @Environment(\.dismiss) var dismiss

    var body: some View {
        @Bindable var store = store

        ErrorAlertView {
            NavigationStack(path: $navigationModel.path) {
                InstanceList { instance in
                    navigationModel.selectedInstance = instance
                    navigationModel.path = [.modBrowser(instance.id)]
                } onCancel: {
                    dismiss()
                }
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .modBrowser(let instanceId):
                        ModBrowser(instance: store.instances[id: instanceId]!)
                    }
                }
            }
        }
        .task {
            if (store.instances.isEmpty) {
                await refresh()
            }
        }
        .refreshable(action: refresh)
        .environment(navigationModel)
    }

    func refresh() async {
        do {
            try await store.loadInstances(with: self)
        } catch {
            store.ckanError = error
        }
    }

    nonisolated func ask(prompt: ActionPrompt) {
        fatalError("Can't handle asking")
    }

    nonisolated func showError(message: String) async {

    }

    nonisolated func showDialog(message: String) async {

    }

    nonisolated func handleProgress(_ progress: CkanAPI.ActionProgress) async {

    }

}

#Preview {
    ModManagerView()
}
