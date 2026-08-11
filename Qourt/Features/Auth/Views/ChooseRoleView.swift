//
//  ChooseRoleView.swift
//  Qourt
//

import SwiftUI

struct ChooseRoleView: View {
    var auth: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Welcome\(auth.displayName.map { ", \($0)" } ?? "")")
                .font(.title2.bold())

            Text("What are you doing today?")
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                Button {
                    auth.chooseRole(.admin)
                } label: {
                    RoleCard(
                        title: "Admin",
                        subtitle: "Set up and run a game",
                        systemImage: "person.badge.key.fill"
                    )
                }

                Button {
                    auth.chooseRole(.player)
                } label: {
                    RoleCard(
                        title: "Play",
                        subtitle: "Join a game and play",
                        systemImage: "figure.badminton"
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .buttonStyle(.plain)
    }
}

private struct RoleCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: 44)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ChooseRoleView(auth: AuthViewModel())
}
