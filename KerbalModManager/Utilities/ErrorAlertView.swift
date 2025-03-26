//
//  ErrorAlertView.swift
//  KerbalModManager
//
//  Created by Lewis McClelland on 3/26/25.
//

import SwiftUI

struct ErrorAlertView<Contents: View>: View {
    @Environment(Store.self) private var store: Store?

    @ViewBuilder var contents: () -> Contents

    var body: some View {
        if let store {
            @Bindable var store = store
            contents()
                .alert(isPresented: $store.showCkanError, error: store.ckanError) {}
        } else {
            contents()
                .onAppear {
                    logger.fault("Using ErrorAlertView without a Store in the environment means it won't show any errors")
                }
        }
    }
}
