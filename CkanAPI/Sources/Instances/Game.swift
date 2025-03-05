//
//  Game.swift
//  CkanAPI
//
//  Created by Lewis McClelland on 3/3/25.
//

public enum Game: Identifiable, CustomStringConvertible, Sendable, Hashable {
    case kerbalSpaceProgram

    init?(id: String) {
        switch id {
        case "KSP":
            self = .kerbalSpaceProgram
        default:
            return nil
        }
    }

    public var id: String {
        switch self {
        case .kerbalSpaceProgram:
            "KSP"
        }
    }

    public var description: String {
        switch self {
        case .kerbalSpaceProgram:
            "Kerbal Space Program"
        }
    }
}
