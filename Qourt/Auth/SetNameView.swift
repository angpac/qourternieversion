//
//  SetNameView.swift
//  Qourt
//

import SwiftUI

struct SetNameView: View {
    var auth: AuthViewModel

    @State private var name = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("What's your name?")
                    .font(.title2.bold())
                Text("Apple didn't share a name for this sign-in. This is what other players will see.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            TextField("Your name", text: $name)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 32)

            Button {
                Task {
                    isSaving = true
                    await auth.setDisplayName(name)
                    isSaving = false
                }
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    SetNameView(auth: AuthViewModel())
}
