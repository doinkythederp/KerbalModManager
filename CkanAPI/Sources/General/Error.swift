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
            return source.description
        case .unknownGameID(let id):
            resource = "The game \"\(id)\" is not supported."
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
        let code = CkanServerError.InstanceCode(rawValue: reply.result.rawValue)
        guard let code else { fatalError("The server returned an unknown instance error code (\(reply.result.rawValue)") }
        let details: String? = if reply.hasErrorDetails { reply.errorDetails } else { nil }
        self = .server(CkanServerError(code: code, details: details))
    }

    init(registry reply: Ckan_RegistryOperationReply) {
        let code = CkanServerError.RegistryCode(rawValue: reply.result.rawValue)
        guard let code else { fatalError("The server returned an unknown registry error code (\(reply.result.rawValue)") }
        let details: String? = if reply.hasErrorDetails { reply.errorDetails } else { nil }
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
            case .newInstanceDirExists: "The install location must not already exist"
            case .fakerUnknownGame: "The requested game is not supported by CKAN"
            case .fakerUnknownVersion: "The requested version is not supported by CKAN"
            case .fakerVersionTooOld: "The requested version is too old to support one of the specified DLCs"
            case .fakerFailed: "The fake operation failed"
            }
        }
    }

    public enum RegistryCode: Int, Code {
        case registryInUse = 1

        public var localizedStringResource: LocalizedStringResource {
            return switch self {
            case .registryInUse: "The module registry is currently in use by another app"
            }
        }
    }
}
