//
//  Error.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/3/25.
//

import Foundation
import GRPCCore

public enum CkanError: Error {
    /// The server reported an unexpected error
    case serverFailure(message: String)
    /// The server didn't send an expected message
    case responseNotReceived
    /// An RPC request failed.
    case rpcFailure(source: RPCError)
    /// The game is not supported.
    case unknownGameID(id: String)

    /// An unknown error.
    case unknownError(source: any Error)
}

extension CkanError: LocalizedError {
    public var errorDescription: String? {
        return switch self {
        case .serverFailure(let message):
            "Unexpected server error: \(message)"
        case .responseNotReceived:
            "CKAN ended a request before a response was received."
        case .rpcFailure(let source):
            source.description
        case .unknownGameID(let id):
            "The game '\(id)' is not supported."
        case .unknownError(let source):
            if let error = source as? LocalizedError {
                error.errorDescription
            } else {
                String(reflecting: source)
            }
        @unknown default:
            "An unknown error occured."
        }
    }
}
