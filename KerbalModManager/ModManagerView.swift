//
//  ContentView.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/3/25.
//

import CkanAPI
import SwiftUI

struct ModManagerView: View, CkanActionDelegate {
    @State private var client: CKANClient?
    @State private var instances: [GameInstance] = []
    @State private var navigationModel = NavigationModel()

    @State private var showErrorAlert = false
    @State private var errorAlert: CkanError?

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack(path: $navigationModel.path) {
            InstanceList(instances: $instances) { instance in
                navigationModel.selectedInstance = instance
                navigationModel.path = [.modBrowser(instance)]
            } onCancel: {
                dismiss()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .modBrowser(let instance):
                    ModBrowser(instance: instance)
                }
            }
        }
        .onAppear {
            if client == nil {
                do {
                    client = try CKANClient()
                    print("Made client")
                } catch {
                    print("ERROR (init) \(error)")
                }

                loadInstances()
            }
        }
        .alert(isPresented: $showErrorAlert, error: errorAlert) {
            Button("OK") {}
        }
        .refreshable {
            await loadInstances()
        }
        .environment(navigationModel)
    }

    func loadInstances() {
        if let client {
            Task {
                do {
                    print("Fetching...")
                    _ = await client.openConnection {
                        error in
                        print(error)
                    }
                    let instances =
                        try await client.getInstances(
                            with: self)
                    self.instances = instances
                } catch let error as CkanError {
                    errorAlert = error
                    showErrorAlert = true
                }
            }
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
