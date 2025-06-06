//
//  Error.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/3/25.
//

import Foundation
import GRPCCore

public enum CkanError: Error {
    /// The server reported an unexpected fault
    case serverFailure(message: String)
    /// The server didn't send an expected message
    case responseNotReceived
    /// An RPC request failed.
    case rpcFailure(RPCError)
    /// The game is not supported.
    case unknownGameID(id: String)
    /// The user must manually resolve a virtual module.
    case unresolvedVirtualModules(VirtualModuleRequest)
    /// The server reported an error
    case server(CkanServerError)

    /// An unknown error.
    case unknownError(source: any Error)
}

extension CkanError: LocalizedError {
    public var errorDescription: String? {
        let resource: LocalizedStringResource

        switch self {
        case .serverFailure(let message):
            resource = "Unexpected server error: \(message)"
        case .responseNotReceived:
            resource = "CKAN ended a request before a response was received."
        case .rpcFailure(let source):
            resource = "RPC failed: \(source.description)"
        case .unknownGameID(let id):
            resource = "The game \"\(id)\" is not supported."
        case .unresolvedVirtualModules(let details):
            resource = "Failed to automatically resolve the virtual module \(details.name) as requested by \(details.source.debugDescription) (\(details.candidates.count) candidates)"
        case .server(let source):
            return source.localizedDescription
        case .unknownError(let source):
            return if let error = source as? LocalizedError {
                error.errorDescription
            } else {
                String(reflecting: source)
            }
        @unknown default:
            resource = "An unknown error occured."
        }

        return String(localized: resource)
    }
}

extension CkanError {
    init(instance reply: Ckan_InstanceOperationReply) {
        precondition(
            reply.result.rawValue != 0,
            "Cannot create an error from an error code indicating success")

        let code = CkanServerError.InstanceCode(rawValue: reply.result.rawValue)
        guard let code else {
            fatalError(
                "The server returned an unknown instance error code (\(reply.result.rawValue))"
            )
        }
        let details: String? =
            if reply.hasErrorDetails { reply.errorDetails } else { nil }
        self = .server(CkanServerError(code: code, details: details))
    }

    init(registry reply: Ckan_RegistryOperationReply) {
        precondition(
            reply.result.rawValue != 0,
            "Cannot create an error from an error code indicating success")

        let code = CkanServerError.RegistryCode(rawValue: reply.result.rawValue)
        guard let code else {
            fatalError(
                "The server returned an unknown registry error code (\(reply.result.rawValue))"
            )
        }
        let details: String? =
            if reply.hasErrorDetails { reply.errorDetails } else { nil }

        if code == .tooManyModsProvide {
            // This code has a special error type to hold extra details and make it more actionable

            let request = reply.tooManyModsProvideError
            self = .unresolvedVirtualModules(
                VirtualModuleRequest(
                    source: ReleaseId(from: request.requestingModule),
                    helpMessage: details,
                    name: request.requestedVirtualModule,
                    candidates: Set(request.candidates.map(ReleaseId.init))
                )
            )
        }

        self = .server(CkanServerError(code: code, details: details))
    }
}

public struct CkanServerError: Error, Sendable, LocalizedError {
    public var code: any Code
    public var details: String?

    public var errorDescription: String? {
        var string = String(localized: code.localizedStringResource)
        if let details {
            string += ": \(details)"
        }
        return string
    }

    public protocol Code: Sendable, CustomLocalizedStringResourceConvertible {}

    public enum InstanceCode: Int, Code {
        case missingData = 1
        case duplicateInstance = 2
        case notAnInstance = 3
        case instanceNotFound = 4
        case cloneFailed = 5
        case newInstanceDirExists = 6
        case fakerUnknownGame = 7
        case fakerUnknownVersion = 8
        case fakerVersionTooOld = 9
        case fakerFailed = 10

        public var localizedStringResource: LocalizedStringResource {
            return switch self {
            case .missingData: "Some required data wasn't specified"
            case .duplicateInstance: "This instance name is already taken"
            case .notAnInstance: "The specified folder is not a game instance"
            case .instanceNotFound: "There is no instance with this name"
            case .cloneFailed: "The clone operation failed"
            case .newInstanceDirExists:
                "The install location must not already exist"
            case .fakerUnknownGame:
                "The requested game is not supported by CKAN"
            case .fakerUnknownVersion:
                "The requested version is not supported by CKAN"
            case .fakerVersionTooOld:
                "The requested version is too old to support one of the specified DLCs"
            case .fakerFailed: "The fake operation failed"
            }
        }
    }

    public enum RegistryCode: Int, Code {
        case registryInUse = 1
        case moduleNotFound = 2
        case tooManyModsProvide = 3

        public var localizedStringResource: LocalizedStringResource {
            return switch self {
            case .registryInUse:
                "The module registry is currently in use by another app"
            case .moduleNotFound: "A requested module could not be resolved"
            case .tooManyModsProvide:
                "Failed to automatically resolve a virtual module"
            }
        }
    }
}

/// A request for a virtual module to be resolved to a concrete module.
///
/// This can be resolved by installing one of the provided ``candidates``.
public struct VirtualModuleRequest: Sendable, Hashable, Equatable {
    /// The module that requires this virtual module to be resolved
    public var source: ReleaseId
    /// A help message provided by the source module
    public var helpMessage: String?

    /// The name of the virtual module
    public var name: String
    /// The modules that implement the requeted virtual module
    public var candidates: Set<ReleaseId>
}
