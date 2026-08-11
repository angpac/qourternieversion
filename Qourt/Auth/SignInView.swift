//
//  SignInView.swift
//  Qourt
//

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    var auth: AuthViewModel

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(spacing: 20) {
                Image("qourtimage")
                    .resizable()
                        .scaledToFit()
                        .frame(width: 305, height: 108)
                //Image(systemName: "figure.badminton")
                    //.font(.system(size: 56))
                    //.foregroundStyle(.tint)
                //Text("Qourt")
                    //.font(.largeTitle.bold())
                Text("Run the game. Not the whiteboard.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                Task {
                    switch result {
                    case .success(let authorization):
                        await auth.signIn(with: authorization)
                    case .failure(let error):
                        auth.errorMessage = error.localizedDescription
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 32)

            if let errorMessage = auth.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
        .background(Color.appBackground.ignoresSafeArea())
    }
}

#Preview {
    SignInView(auth: AuthViewModel())
}
