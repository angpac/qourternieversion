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
                        .frame(width: 315, height: 108)
                //Image(systemName: "figure.badminton")
                    //.font(.system(size: 56))
                    //.foregroundStyle(.tint)
                //Text("Qourt")
                    //.font(.largeTitle.bold())
                Text("Track, Queue and Score on the Court")
                    .font(.custom("DIN-Regular", size: 18))
                    //.font(.subheadline)
                    .foregroundStyle(Color(red: 0x5F / 255, green: 0x4C / 255, blue: 0x00 / 255))
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
