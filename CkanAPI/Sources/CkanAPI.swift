import AsyncAlgorithms
import Foundation
import Collections
import GRPCCore
import GRPCNIOTransportHTTP2TransportServices
import IdentifiedCollections

public actor CKANClient {
    @MainActor public static var subprocesses: Set<Process> = []
    
    private var grpcClient: GRPCClient<HTTP2ClientTransport.TransportServices>
    private var ckanClient:
        Ckan_CKANServer.Client<HTTP2ClientTransport.TransportServices>
    
    private var subprocess: Process

    public init() {
#if arch(arm64)
        let serverDirUrl = Bundle.main.url(forAuxiliaryExecutable: "CKANServer-osx-arm64")!
#elseif arch(x86_64)
        let serverDirUrl = Bundle.main.url(forAuxiliaryExecutable: "CKANServer-osx-x86_64")!
#else
#error("Unsupoorted architecture")
#endif
        
        let serverUrl = serverDirUrl.appending(path: "CKANServer").absoluteURL
        let socketUrl = URL(filePath: "/tmp").appending(path: "ckan-server-\(UUID()).sock")
        
        subprocess = Process()
        subprocess.executableURL = serverUrl.absoluteURL
        subprocess.arguments = ["--urls", "http://unix:\(socketUrl.path())"]
        subprocess.standardOutput = FileHandle.standardOutput
        subprocess.standardError = FileHandle.standardError
        
        subprocess.environment = ProcessInfo.processInfo.environment
        subprocess.environment?["Kestrel__EndpointDefaults__Protocols"] = "Http2"
        
#if DEBUG
        subprocess.environment?["Logging__LogLevel__Default"] = "Trace"
#endif
        
        try! subprocess.run()
        
        grpcClient = GRPCClient(
            transport: try! .http2NIOTS(
                target: .unixDomainSocket(path: socketUrl.path(), authority: "localhost"),
                transportSecurity: .plaintext
            ))
        ckanClient = Ckan_CKANServer.Client(wrapping: grpcClient)
        
        let subprocess = self.subprocess
        Task { @MainActor in
            CKANClient.subprocesses.insert(subprocess)
        }
        
        Task {
            while !FileManager.default.fileExists(atPath: socketUrl.path()) {
                try! await Task.sleep(for: .milliseconds(100))
            }
            await startConnection()
        }
    }
    
    deinit {
        let subprocess = self.subprocess
        Task { @MainActor in
            CKANClient.subprocesses.remove(subprocess)
        }
    }

    private func startConnection() async {
        do {
            try await grpcClient.runConnections()
        } catch {
            logger.error(
                "Failed to start connection: \(error.localizedDescription)")
        }
    }
    
    public func stop() {
        self.grpcClient.beginGracefulShutdown()
        subprocess.terminate()
        subprocess.waitUntilExit()
    }

    func performAction<T: Sendable>(
        _ initialMessage: Ckan_ActionMessage,
        with delegate: CkanActionDelegate,
        matcher: @Sendable @escaping (Ckan_ActionReply.OneOf_Status)
            async throws -> T?
    ) async throws(CkanError) -> [T] {
        let pendingMessages = AsyncChannel<Ckan_ActionMessage>()
        let req = StreamingClientRequest { writer in
            try await writer.write(initialMessage)
            try await writer.write(contentsOf: pendingMessages)
        }

        logger.trace("Making request")
        do {
            return try await ckanClient.processAction(request: req) {
                response in

                var results: [T] = []

                for try await replyMsg in response.messages {
                    logger.trace("Got reply")

                    var status = replyMsg.status
                    try await self.handleReply(
                        status: &status, pending: pendingMessages,
                        delegate: delegate)

                    // Only run `matcher` if `handleReply` didn't consume the status.
                    if let status,
                        let result = try await matcher(status)
                    {
                        results.append(result)
                    }
                }

                pendingMessages.finish()
                return results
            }
        } catch let error as RPCError {
            throw CkanError.rpcFailure(error)
        } catch let error as CkanError {
            throw error
        } catch {
            throw CkanError.unknownError(source: error)
        }

    }

    /// Attempts to handle a reply's status. If successful, sets the status to `nil`.
    private func handleReply(
        status maybeStatus: inout Ckan_ActionReply.OneOf_Status?,
        pending pendingMessages: AsyncChannel<Ckan_ActionMessage>,
        delegate: CkanActionDelegate
    ) async throws {
        guard let status = maybeStatus else { return }
        maybeStatus = nil

        switch status {
        case .errorMessage(let message):
            try await delegate.showError(message: message)

        case .message(let message):
            try await delegate.showDialog(message: message)

        case .progress(let progress):
            try await delegate.handleProgress(
                ActionProgress(from: progress))

        case .prompt(let prompt):
            var response = Ckan_ContinueRequest()

            // If there is a set of allowed options, use the picker style.
            if prompt.options.isEmpty {
                response.yesOrNo = await withCheckedContinuation {
                    continuation in
                    delegate.ask(
                        prompt: .confirmation(
                            continuation: continuation))
                }
            } else {
                response.index = await withCheckedContinuation {
                    continuation in
                    let choices = ActionPrompt.Choices(
                        defaultIndex: prompt.hasDefaultIndex
                            ? prompt.defaultIndex : nil,
                        choices: prompt.options)
                    delegate.ask(
                        prompt: .picker(
                            choices: choices, continuation: continuation
                        ))
                }
            }

            await pendingMessages.send(
                Ckan_ActionMessage.with { msg in
                    msg.continueRequest = response
                })

        case .failure(let error):
            throw CkanError.serverFailure(message: error.message)

        default:
            maybeStatus = status  // ask caller to handle this status
        }
    }

    private func performRegistryAction(
        _ initialMessage: Ckan_ActionMessage,
        with delegate: CkanActionDelegate
    ) async throws(CkanError) -> Ckan_RegistryOperationReply {
        let reply = try await performAction(initialMessage, with: delegate) {
            status in
            return switch status {
            case .registryOperationReply(let reply): reply
            case .instanceOperationReply(let reply):
                throw CkanError(instance: reply)
            default: nil
            }
        }

        guard let reply = reply.first else {
            throw CkanError.responseNotReceived
        }
        guard reply.result == .rorSuccess else {
            throw CkanError(registry: reply)
        }
        return reply
    }

    func getCkanInstances(with delegate: CkanActionDelegate)
        async throws(CkanError) -> [Ckan_Instance]
    {
        logger.debug("Getting instance list")
        let message = Ckan_ActionMessage.with {
            $0.instancesListRequest = Ckan_InstancesListRequest()
        }

        let reply = try await performAction(message, with: delegate) { status in
            return if case .instancesListReply(let list) = status {
                list
            } else {
                nil
            }
        }

        guard let list = reply.first else {
            throw CkanError.responseNotReceived
        }

        return list.instances
    }

    @MainActor
    public func getInstances(with delegate: CkanActionDelegate)
        async throws(CkanError) -> [GameInstance]
    {
        let instances = try await getCkanInstances(with: delegate)
        do {
            return try instances.map { try GameInstance(from: $0) }
        } catch let error as CkanError {
            throw error
        } catch {
            throw CkanError.unknownError(source: error)
        }
    }
    
    public func addInstance(name: String, url: URL, with delegate: CkanActionDelegate) async throws(CkanError) {
        assert(url.isFileURL)
        
        let path = url.absoluteURL.path()
        let message = Ckan_ActionMessage.with {
            $0.instanceAddRequest = Ckan_InstanceAddRequest.with {
                $0.name = name
                $0.directory = path
            }
        }
        
        let reply = try await performAction(message, with: delegate) { status in
            return if case .instanceOperationReply(let ior) = status {
                ior
            } else {
                nil
            }
        }
        
        guard let reply = reply.first else {
            throw CkanError.responseNotReceived
        }
        
        guard reply.result == .iorSuccess else {
            throw CkanError(instance: reply)
        }
    }

    func prepopulateRegistry(
        forName instanceName: String,
        forceLock: Bool = false,
        with delegate: CkanActionDelegate
    ) async throws(CkanError) {
        logger.debug("Prepopulating registry")

        let message = Ckan_ActionMessage.with {
            $0.registryPrepopulateRequest =
                Ckan_RegistryPrepopulateRequest.with {
                    $0.instanceName = instanceName
                    $0.forceLock = forceLock
                }
        }
        _ = try await performRegistryAction(message, with: delegate)
    }

    @MainActor
    public func prepopulateRegistry(
        for instance: GameInstance, forceLock: Bool = false,
        with delegate: CkanActionDelegate
    ) async throws(CkanError) {
        try await prepopulateRegistry(
            forName: instance.name,
            forceLock: forceLock,
            with: delegate
        )
    }

    func getCkanModules(
        availableTo instanceName: String,
        with delegate: CkanActionDelegate,
        handleChunk: @isolated(any) @Sendable @escaping ([Ckan_Module], UInt32)
            -> Void
    ) async throws(CkanError) {
        logger.debug("Getting available modules")
        let message = Ckan_ActionMessage.with {
            $0.registryAvailableModulesRequest =
                Ckan_RegistryAvailableModulesRequest.with {
                    $0.instanceName = instanceName
                }
        }

        _ = try await performAction(message, with: delegate) { status in
            switch status {
            case .registryOperationReply(let reply):
                await handleChunk(
                    reply.availableModules.modules,
                    reply.availableModules.remaining)

                return Never?.none
            default: return nil
            }
        }
    }

    @MainActor
    public func getModules(
        availableTo instance: GameInstance,
        with delegate: CkanActionDelegate,
        handleChunk: @escaping ([CkanModule], _ percentProgress: Double) -> Void
    ) async throws(CkanError) {
        var totalReceived = 0

        try await getCkanModules(availableTo: instance.name, with: delegate) {
            @MainActor chunk, remaining in
            totalReceived += chunk.count
            let percentProgress =
                Double(totalReceived) / Double(totalReceived + Int(remaining))
            handleChunk(chunk.map(CkanModule.init), percentProgress)
        }
    }

    func getModuleStates(
        forInstance instanceName: String,
        compatOptions: GameInstance.CompatabilityOptions? = nil,
        heldModules: Set<String> = [],
        incompleteModules: Set<String> = [],
        with delegate: CkanActionDelegate
    ) async throws(CkanError) -> [ModuleState] {
        logger.debug("Fetching module states")

        let message = Ckan_ActionMessage.with {
            $0.registryModuleStatesRequest =
                Ckan_RegistryModuleStatesRequest.with {
                    $0.instanceName = instanceName
                    if let compatOptions {
                        $0.compatOptions = Ckan_Instance.CompatOptions(
                            from: compatOptions)
                    }
                    $0.heldModuleIdents = Array(heldModules)
                    $0.incompleteModuleIdents = Array(incompleteModules)
                }
        }

        let reply = try await performRegistryAction(message, with: delegate)

        guard case .moduleStates(let reply) = reply.results else {
            throw CkanError.responseNotReceived
        }

        return reply.states.map(ModuleState.init)
    }

    @MainActor
    public func getModuleStates(
        for instance: GameInstance,
        heldModules: Set<String> = [],
        incompleteModules: Set<String> = [],
        with delegate: CkanActionDelegate
    ) async throws(CkanError) -> [ModuleState] {
        return try await getModuleStates(
            forInstance: instance.name,
            compatOptions: instance.compatabilityOptions,
            heldModules: heldModules,
            incompleteModules: incompleteModules,
            with: delegate
        )
    }

    func resolveOptionalDependencies(
        for instanceName: String,
        modules: Set<ReleaseId>,
        with delegate: CkanActionDelegate
    ) async throws(CkanError) -> OptionalDependencies {
        logger.debug("Resolving optional dependencies")

        let message = Ckan_ActionMessage.with {
            $0.registryOptionalDependenciesRequest =
                Ckan_RegistryOptionalDependenciesRequest.with {
                    $0.instanceName = instanceName
                    $0.modules = modules.map(Ckan_ModuleReleaseRef.init)
                }
        }

        let reply = try await performRegistryAction(message, with: delegate)

        guard case .optionalDependencies(let reply) = reply.results else {
            throw CkanError.responseNotReceived
        }

        return OptionalDependencies(from: reply)
    }

    @MainActor
    public func resolveOptionalDependencies(
        for instance: GameInstance,
        modules: Set<ReleaseId>,
        with delegate: CkanActionDelegate
    ) async throws(CkanError) -> OptionalDependencies {
        return try await resolveOptionalDependencies(
            for: instance.name, modules: modules, with: delegate)
    }

    func performInstall(
        for instanceName: String,
        installing toInstall: Set<ReleaseId>,
        removing toRemove: Set<ModuleId>,
        replacing toReplace: Set<ModuleId>,
        with delegate: CkanActionDelegate
    ) async throws(CkanError) {
        logger.debug("Performing installation")

        let message = Ckan_ActionMessage.with {
            $0.registryPerformInstallRequest =
                Ckan_RegistryPerformInstallRequest.with {
                    $0.instanceName = instanceName
                    $0.modsToInstall = toInstall.map(Ckan_ModuleReleaseRef.init)
                    $0.modsToRemove = toRemove.map(\.value)
                    $0.modsToReplace = toRemove.map(\.value)
                }
        }

        let reply = try await performRegistryAction(message, with: delegate)

        guard case .performInstall(_) = reply.results else {
            throw CkanError.responseNotReceived
        }
    }

    @MainActor
    public func performInstall(
        for instance: GameInstance,
        installing toInstall: Set<ReleaseId>,
        removing toRemove: Set<ModuleId>,
        replacing toReplace: Set<ModuleId>,
        with delegate: CkanActionDelegate
    ) async throws(CkanError) {
        try await performInstall(
            for: instance.name,
            installing: toInstall,
            removing: toRemove,
            replacing: toReplace,
            with: delegate
        )
    }
    
    func updateRegistry(
        for instanceName: String,
        force: Bool,
        with delegate: CkanActionDelegate
    ) async throws(CkanError) {
        logger.debug("Updating registry")
        
        let message = Ckan_ActionMessage.with {
            $0.registryUpdateRequest =
            Ckan_RegistryUpdateRequest.with {
                $0.instanceName = instanceName
            }
        }
        
        let reply = try await performRegistryAction(message, with: delegate)
        
        guard case .update(_) = reply.results else {
            throw CkanError.responseNotReceived
        }
    }
    
    @MainActor
    public func updateRegistry(
        for instance: GameInstance,
        force: Bool = false,
        with delegate: CkanActionDelegate
    ) async throws(CkanError) {
        try await updateRegistry(
            for: instance.name,
            force: force,
            with: delegate
        )
    }
}

public struct ActionProgress: Sendable {
    public let percentCompletion: UInt32
    public let message: String?

    init(from ckan: Ckan_ActionReply.Progress) {
        percentCompletion = ckan.value
        message = ckan.hasMessage ? ckan.message : nil
    }
}

public enum ActionPrompt {
    public struct Choices {
        let defaultIndex: UInt32?
        let choices: [String]
    }

    case confirmation(continuation: CheckedContinuation<Bool, Never>)
    case picker(
        choices: Choices, continuation: CheckedContinuation<UInt32, Never>)
}

public protocol CkanActionDelegate: Sendable {
    func showError(message: String) async throws
    func showDialog(message: String) async throws
    func handleProgress(_ progress: ActionProgress) async throws
    func ask(prompt: ActionPrompt)
}

extension CkanActionDelegate {
    public func showError(message: String) async {}
    public func showDialog(message: String) async {}
    public func handleProgress(_ progress: ActionProgress) async {}
    public func ask(prompt: ActionPrompt) {
        fatalError("Unexpected CKAN prompt")
    }
}

public struct EmptyCkanActionDelegate: CkanActionDelegate {
    public init() {}
}

public struct OptionalDependencies: Sendable, Equatable, Hashable {
    public init(
        recommended: IdentifiedArrayOf<OptionalDependencies.Dependency>,
        suggested: IdentifiedArrayOf<OptionalDependencies.Dependency>,
        supporters: IdentifiedArrayOf<OptionalDependencies.Dependency>,
        installableRecommended: Set<ModuleId>
    ) {
        self.recommended = recommended
        self.suggested = suggested
        self.supporters = supporters
        self.installableRecommended = installableRecommended
    }

    public struct Dependency: Sendable, Equatable, Hashable, Identifiable {
        public init(id: ReleaseId, sources: OrderedSet<ModuleId>) {
            self.id = id
            self.sources = sources
        }

        public var id: ReleaseId
        public var sources: OrderedSet<ModuleId>
    }

    public var recommended: IdentifiedArrayOf<Dependency>
    public var suggested: IdentifiedArrayOf<Dependency>
    public var supporters: IdentifiedArrayOf<Dependency>
    public var installableRecommended: Set<ModuleId>

    public var isEmpty: Bool {
        recommended.isEmpty
            && suggested.isEmpty
            && supporters.isEmpty
            && installableRecommended.isEmpty
    }
}
