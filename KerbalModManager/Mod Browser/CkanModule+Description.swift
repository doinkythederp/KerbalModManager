//
//  CkanModule+Description.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/28/25.
//
//  Summary: Human-readable representations of CkanModule properties
//

import Foundation
import CkanAPI

extension CkanModule.Release {
    var versionDescription: String {
        String(version.versionComponent)
    }
    var authorsDescription: String {
        authors.formatted()
    }

    private static func formatVersion(_ version: GameVersion?) -> LocalizedStringResource {
        return if let version {
            "\(version.description)"
        } else {
            "any"
        }
    }

    var kspVersionMaxDescription: String {
        String(localized: Self.formatVersion(kspVersionMax))
    }

    var downloadSizeBytesDescription: String {
        downloadSizeBytes.formatted(.byteCount(style: .file))
    }
}
