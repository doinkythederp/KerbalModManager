//
//  System.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/27/25.
//

import Foundation
import AppKit

extension NSPasteboard {
    func copy(_ value: String) {
        clearContents()
        setString(value, forType: .string)
    }
    func copy(_ value: URL) {
        clearContents()
        setString(value.absoluteString, forType: .URL)
        setString(value.absoluteString, forType: .string)
    }
}
