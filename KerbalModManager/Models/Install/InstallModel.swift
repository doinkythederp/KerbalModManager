//
//  InstallModel.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 5/2/25.
//

import CkanAPI
import Observation
import Foundation

@MainActor
@Observable
final class InstallModel {
    let instance: GUIInstance

    var stage: Stage?

    private var installTask: Task<Void, any Error>?
    private var continuation: CheckedContinuation<Void, Never>?

    func showPendingChanges() {
        stage = .pending
    }

    func performInstall(state: ModBrowserState, store: Store) async {
        do {
            installTask = Task {
                try await run(state: state, store: store)
            }

            try await installTask?.value
        } catch let error as CkanError {
            store.ckanError = error
            store.showCkanError = true
            cancel()
            return
        } catch _ as CancellationError {
            logger.info("Install task cancelled")
        } catch {
            fatalError(error.localizedDescription)
        }

        installTask = nil
        continuation = nil

    }

    func continueInstall() {
        continuation?.resume()
        continuation = nil
    }

    func run(state: ModBrowserState, store: Store) async throws {
        logger.info("Install task: Beginning install plan")
        
        let plan = state.changePlan

        let optionalDeps = try await store.client.resolveOptionalDependencies(
            for: instance.ckan,
            modules: instance.modulesInstalled(by: plan),
            with: EmptyCkanActionDelegate()
        )

        try Task.checkCancellation()

        logger.info(
            "Install task: Discovered optional dependencies for install plan: \(optionalDeps.recommended.count) recommended, \(optionalDeps.suggested.count) suggested, \(optionalDeps.supporters.count) supporters"
        )

        let skipOptionalDeps = UserDefaults.standard.bool(forKey: AppStorageKey.skipOptionalDependencies)
        
        if !optionalDeps.isEmpty && !skipOptionalDeps {
            // Wait for user to pick optional deps
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                stage = .pickOptionalDependencies(optionalDeps)
            }

            try Task.checkCancellation()
        }

        stage = .installing
        
        // TODO: check for cancels inside this method to allow cancels once CKAN starts downloading/installing mods
        try await store.client.performInstall(
            for: instance.ckan,
            installing: Set(plan.pendingInstallation.values),
            removing: plan.pendingRemoval,
            replacing: plan.pendingReplacement,
            with: EmptyCkanActionDelegate())

        logger.info("Install task: Refreshing module state")
        
        state.changePlan.removeAll()

        try await store.refreshModuleStates(for: instance, with: EmptyCkanActionDelegate())

        stage = .done

        logger.info("Install task: Install complete")
    }

    func cancel() {
        if let installTask {
            installTask.cancel()
        }

        if let continuation {
            continuation.resume()
        }

        stage = nil
        continuation = nil
        installTask = nil
    }

    init(instance: GUIInstance) {
        self.instance = instance
    }

    enum Stage: Equatable, Hashable, Identifiable {
        case pending
        case pickOptionalDependencies(OptionalDependencies)
        case installing
        case done

        var id: Self { self }
    }
}
