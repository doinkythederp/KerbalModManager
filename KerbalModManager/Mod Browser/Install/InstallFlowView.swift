//
//  InstallFlow.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 5/2/25.
//

import SwiftUI

struct InstallFlowView: View {
    var model: InstallModel

    // This stage override parameter is useful for the sheet close animation because the GUI
    // needs to continue to show the same stage even while animating out.
    var stage: InstallModel.Stage?

    @Environment(ModBrowserState.self) private var state

    @AppStorage("ShowOptionalDependencies")
    private var skipOptionalDependencies = false

    var body: some View {
        VStack {
            VStack {
                switch stage ?? model.stage {
                case nil:
                    Label("No install in progress", systemSymbol: .exclamationmarkTriangle).padding()
                    
                case .pending:
                    ConfirmInstallView()
                    
                case .pickOptionalDependencies(let dependencies):
                    OptionalDependenciesPicker(dependencies: dependencies, shouldSkip: $skipOptionalDependencies)
                }
            }
        }
    }
}

#Preview(traits: .modifier(.sampleData)) {
    @Previewable @Environment(ModBrowserState.self) var state

    InstallFlowView(model: state.installModel)
        .frame(width: 480, height: 480)
        .background()
        .onAppear {
            state.installModel.showPendingChanges()
        }
}
