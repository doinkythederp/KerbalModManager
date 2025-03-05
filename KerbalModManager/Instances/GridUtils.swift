//
//  GridUtils.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/4/25.
//

import SwiftUI

// Some content sourced from <https://developer.apple.com/documentation/swiftui/focus-cookbook-sample>

extension MoveCommandDirection {
    /// Flip direction for right-to-left language environments.
    /// Learn more: https://developer.apple.com/design/human-interface-guidelines/right-to-left
    func transform(from layoutDirection: LayoutDirection) -> MoveCommandDirection {
        if layoutDirection == .rightToLeft {
            switch self {
            case .left:     return .right
            case .right:    return .left
            default:        break
            }
        }
        return self
    }
}
