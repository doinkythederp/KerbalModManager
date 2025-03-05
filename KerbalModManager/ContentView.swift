//
//  ContentView.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/3/25.
//

import SwiftUI
import CkanAPI

struct ContentView: View, CkanActionDelegate {
    @State private var client: CKANClient?
    @State private var instances: [GameInstance] = []
    @State private var navigationModel = NavigationModel()

    var body: some View {
        VStack {
            Button {
                if let client {
                    Task {
                        do {
                            print("Fetching...")
                            _ = await client.openConnection { error in
                                print(error)
                            }
                            let instances = try await client.getInstances(with: self)
                            self.instances = instances
                        } catch {
                            print("ERROR \(error)")
                        }
                    }
                }
            } label: {
                Label("Load Instance List", systemImage: "gamecontroller")
            }

            InstanceList(instances: $instances)
        }
        .padding()
        .onAppear {
            if client == nil {
                do {
                    client = try CKANClient()
                    print("Made client")
                } catch {
                    print("ERROR \(error)")
                }
            }
        }
        .environment(navigationModel)
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
    ContentView()
}
