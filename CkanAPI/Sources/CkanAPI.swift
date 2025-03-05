import AsyncAlgorithms
import GRPCCore
import GRPCNIOTransportHTTP2

public actor CKANClient {
    private var grpcClient: GRPCClient<HTTP2ClientTransport.TransportServices>
    private var ckanClient:
        Ckan_CKANServer.Client<HTTP2ClientTransport.TransportServices>
    private var task: Task<Void, Never>?

    public init() throws {
        grpcClient = GRPCClient(
            transport: try .http2NIOTS(
                target: .ipv4(host: "127.0.0.1", port: 31416),
                transportSecurity: .plaintext
            ))
        ckanClient = Ckan_CKANServer.Client(wrapping: grpcClient)
    }

    @discardableResult
    public func openConnection(handleError: @Sendable @escaping (Error) -> Void) -> Task<Void, Never>? {
        guard task == nil else { return nil }
        let client = grpcClient
        let task = Task {
            do {
                try await client.runConnections()
            } catch {
                handleError(error)
            }
        }
        self.task = task
        return task
    }

    func performAction<T: Sendable>(_ message: Ckan_ActionMessage, with delegate: CkanActionDelegate, matcher: @Sendable @escaping (Ckan_ActionReply.OneOf_Status) async throws -> T?) async throws -> T? {
        let pendingMessages = AsyncChannel<Ckan_ActionMessage>()
        let req = StreamingClientRequest { writer in
            try await writer.write(message)
            try await writer.write(contentsOf: pendingMessages)
        }

        print("Making request")
        return try await ckanClient.processAction(request: req) { response in
            for try await replyMsg in response.messages {
                print("Got reply")
                dump(replyMsg)
                
                guard let status = replyMsg.status else { continue }

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
                    if let inner = try await matcher(status) {
                        pendingMessages.finish()
                        return inner
                    }
                }
            }

            return nil
        }
    }

    public func getInstances(with delegate: CkanActionDelegate) async throws -> [GameInstance] {
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

        return try list.instances.map { try GameInstance(from: $0) }
    }

    deinit {
        self.grpcClient.beginGracefulShutdown()
    }
}

public struct ActionProgress {
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

public extension CkanActionDelegate {
    func showError(message: String) async {}
    func showDialog(message: String) async {}
    func handleProgress(_ progress: ActionProgress) async {}
}
