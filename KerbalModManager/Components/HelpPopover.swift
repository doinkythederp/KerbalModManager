//
//  HelpPopover.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 5/2/25.
//

import SwiftUI

struct HelpPopoverLink<Popover: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder var popover: () -> Popover

    var body: some View {
        HelpLink {
            isPresented.toggle()
        }
        .popover(isPresented: $isPresented) {
            popover()
                .padding()
                .multilineTextAlignment(.center)
                .presentationSizing(.page)
        }
    }
}

#Preview {
    @Previewable @State var shown = false

    HelpPopoverLink(isPresented: $shown) {
        Text("Help Text")
    }
    .padding()
}
