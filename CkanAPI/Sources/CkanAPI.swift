import AsyncAlgorithms
import Collections
import GRPCCore
import GRPCNIOTransportHTTP2TransportServices

public actor CKANClient {
    private var grpcClient: GRPCClient<HTTP2ClientTransport.TransportServices>
    private var ckanClient:
        Ckan_CKANServer.Client<HTTP2ClientTransport.TransportServices>

    public init() {
        grpcClient = GRPCClient(
            transport: try! .http2NIOTS(
                target: .ipv4(host: "127.0.0.1", port: 31416),
                transportSecurity: .plaintext
            ))
        ckanClient = Ckan_CKANServer.Client(wrapping: grpcClient)
        Task {
            await startConnection()
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

    deinit {
        self.grpcClient.beginGracefulShutdown()
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
