//
//  ModTag.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/26/25.
//

import CkanAPI
import SwiftUI

struct LicenseTagView: View {
    var license: String

    var body: some View {
        let restricted = license == "restricted"

        ModTagView {
            Text(license)
                .foregroundStyle(restricted ? .white : .primary)
        } details: {
            Text(
                restricted
                    ? "The mod author has *not* released their work under an open-source license. You might be restricted from distributing or modifying this mod."
                    : "The mod author has released their work under a \(license) license."
            )
            if !restricted {
                Button("Copy License Name") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(license + " license", forType: .string)
                }
            }
        }
        .backgroundStyle(
            restricted
                ? AnyShapeStyle(.red)
                : AnyShapeStyle(.background)
        )

    }
}

struct StabilityTagView: View {
    var releaseStatus: CkanModule.ReleaseStatus

    var body: some View {
        let isUnstable = releaseStatus != .stable

        ModTagView {
            Text(releaseStatus.localizedStringResource)
                .foregroundStyle(isUnstable ? .black : .primary)
        }
        .backgroundStyle(
            isUnstable
                ? AnyShapeStyle(.yellow)
                : AnyShapeStyle(.background)
        )
    }
}

struct ModTagView<Contents: View, PopoverContents: View>: View {
    var contents: () -> Contents
    var details: (() -> PopoverContents)?

    @State private var popoverPresented = false

    init(@ViewBuilder _ contents: @escaping () -> Contents)
    where PopoverContents == Never {
        self.contents = contents
    }

    init(
        @ViewBuilder _ contents: @escaping () -> Contents,
        @ViewBuilder details: @escaping () -> PopoverContents
    ) {
        self.contents = contents
        self.details = details
    }

    var body: some View {
        let view = contents()
            .padding(.horizontal, 3)
            .padding(3)
            .background()
            .clipShape(.capsule)

        if let details {
            view
                .popover(isPresented: $popoverPresented) {
                    details()
                        .padding()
                        .presentationSizing(.page)
                }
                .onTapGesture {
                    popoverPresented.toggle()
                }
                .help("Click to show details")
        } else {
            view
        }
    }
}
