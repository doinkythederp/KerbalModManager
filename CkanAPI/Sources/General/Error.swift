//
//  Error.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/3/25.
//

public enum CkanError: Error {
    /// The server reported an unexpected error
    case serverFailure(message: String)
    /// The server didn't send an expected message
    case responseNotReceived
    case unknownGameID(id: String)
}
