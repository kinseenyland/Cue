//
//  WelcomeView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            HStack(spacing: 10) {
                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        Text("CUE")
                            .font(.system(size: 96, weight: .regular))
                            .lineSpacing(22)
                            .foregroundColor(.black)
                        Text("welcome to cue.")
                            .font(.system(size: 13, weight: .thin))
                            .foregroundColor(.black)
                    }
                    .padding(EdgeInsets(top: 5, leading: 12, bottom: 24, trailing: 12))

                    NavigationLink {
                        AuthView()
                    } label: {
                        HStack(spacing: 10) {
                            Text("Sign in")
                                .font(.system(size: 12, weight: .semibold))
                                .lineSpacing(22)
                                .foregroundColor(.white)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(.black)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AccountCreationView()
                    } label: {
                        Text("New here?")
                            .font(.system(size: 12, weight: .semibold))
                            .lineSpacing(22)
                            .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                }
                .padding(EdgeInsets(top: 28, leading: 31, bottom: 28, trailing: 31))
                .frame(maxWidth: .infinity)
                .background(Color(red: 1, green: 1, blue: 1).opacity(0.50))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .inset(by: 0.50)
                        .stroke(.black, lineWidth: 0.50)
                )
            }
            .padding(EdgeInsets(top: 42, leading: 32, bottom: 42, trailing: 32))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthViewModel())
}
