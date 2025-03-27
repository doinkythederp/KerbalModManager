import AsyncAlgorithms
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
            print(error)
        }
    }

    func performAction<T: Sendable>(
        _ initialMessage: Ckan_ActionMessage,
        with delegate: CkanActionDelegate,
        matcher: @Sendable @escaping (Ckan_ActionReply.OneOf_Status)
            async throws -> T?
    ) async throws(CkanError) -> T? {
        let pendingMessages = AsyncChannel<Ckan_ActionMessage>()
        let req = StreamingClientRequest { writer in
            try await writer.write(initialMessage)
            try await writer.write(contentsOf: pendingMessages)
        }

        print("Making request")
        do {
            return try await ckanClient.processAction(request: req) {
                response in
                for try await replyMsg in response.messages {
                    print("Got reply")
//                    dump(replyMsg)

                    var status = replyMsg.status
                    try await self.handleReply(
                        status: &status, pending: pendingMessages,
                        delegate: delegate)

                    // Only run `matcher` if `handleReply` didn't consume the status.
                    if let status, let inner = try await matcher(status) {
                        pendingMessages.finish()
                        return inner
                    }
                }

                return nil
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
            case .instanceOperationReply(let reply): throw CkanError(instance: reply)
            default: nil
            }
        }

        guard let reply else { throw CkanError.responseNotReceived }
        guard reply.result == .rorSuccess else {
            throw CkanError(registry: reply)
        }
        return reply
    }

    func getCkanInstances(with delegate: CkanActionDelegate)
        async throws(CkanError) -> [Ckan_Instance]
    {
        print("Getting instance list")
        let message = Ckan_ActionMessage.with {
            $0.instancesListRequest = Ckan_InstancesListRequest()
        }

        let list = try await performAction(message, with: delegate) { status in
            return if case .instancesListReply(let list) = status {
                list
            } else {
                nil
            }
        }

        guard let list else { throw CkanError.responseNotReceived }

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
        print("Prepopulating registry")

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
        compatibleWith instanceName: String,
        with delegate: CkanActionDelegate
    )
        async throws(CkanError) -> [Ckan_Module]
    {
        print("Getting instance list")
        let message = Ckan_ActionMessage.with {
            $0.registryCompatibleModulesRequest =
            Ckan_RegistryCompatibleModulesRequest.with {
                $0.instanceName = instanceName
            }
        }

        let reply = try await performRegistryAction(message, with: delegate)

        guard case .compatibleModules(let list) = reply.results else {
            throw CkanError.responseNotReceived
        }

        return list.modules
    }

    @MainActor
    public func getModules(
        compatibleWith instance: GameInstance,
        with delegate: CkanActionDelegate
    ) async throws(CkanError) -> [CkanModule] {
        let modules = try await getCkanModules(
            compatibleWith: instance.name, with: delegate)
        return modules.map { CkanModule(from: $0) }
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
