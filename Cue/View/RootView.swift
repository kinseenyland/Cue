//
//  RootView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        if authVM.user == nil {
            AuthView()
        } else {
            WelcomeView()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthViewModel())
}
