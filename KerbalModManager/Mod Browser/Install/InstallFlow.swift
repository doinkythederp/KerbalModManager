//
//  InstallFlow.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 5/2/25.
//

import SwiftUI

struct InstallFlow: View {
    var stage: InstallStage

    @Environment(ModBrowserState.self) private var state

    @AppStorage("ShowOptionalDependencies")
    private var skipOptionalDependencies = false

    var body: some View {
        VStack {
            VStack {
                switch stage {
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

    VStack {
        if let stage = state.installStage {
            InstallFlow(stage: stage)
                .background()
        }
    }
    .onAppear {
        state.installStage = .pending
    }
}
