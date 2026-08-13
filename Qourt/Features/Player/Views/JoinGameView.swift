//
//  JoinGameView.swift
//  Qourt
//

import SwiftUI

struct JoinGameView: View {
    var auth: AuthViewModel
    var initialCode: String = ""
    var onJoined: (Game) -> Void

    @State private var viewModel = JoinGameViewModel()
    @State private var isJoining = false
    @State private var isShowingScanner = false
    // A code that arrived via a tapped link or a QR scan is already
    // correct — show it as a settled confirmation instead of a plain text
    // field, so it's obvious at a glance that this part's already done.
    @State private var isEditingCode = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Join code") {
                    if isEditingCode {
                        TextField("6-character code", text: $viewModel.joinCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button {
                            isShowingScanner = true
                        } label: {
                            Label("Scan QR code", systemImage: "qrcode.viewfinder")
                                .foregroundStyle(Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255))
                        }
                    } else if let previewError = viewModel.previewError {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(previewError)
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                                Text(viewModel.joinCode)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Try another code") {
                                isEditingCode = true
                            }
                            .font(.footnote)
                        }
                    } else {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Joining")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(viewModel.isLoadingPreview ? "…" : (viewModel.previewGameName ?? "game"))
                                        .font(.title3.bold())
                                    Text(viewModel.joinCode)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            Spacer()
                            Button("Not this game?") {
                                isEditingCode = true
                            }
                            .font(.footnote)
                        }
                    }
                }

                Section("Your info") {
                    TextField("Name", text: $viewModel.displayName)
                    HStack {
                        Text("Skill level")
                        Spacer()
                        Text(viewModel.skillLevel)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            isJoining = true
                            let success = await viewModel.joinGame()
                            isJoining = false
                            if success, let game = viewModel.joinedGame {
                                onJoined(game)
                                dismiss()
                            }
                        }
                    } label: {
                        if isJoining {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Join")
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .listRowBackground(Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255))
                    .disabled(isJoining || (!isEditingCode && viewModel.previewError != nil))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Join a game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if viewModel.displayName.isEmpty {
                    viewModel.displayName = auth.displayName ?? ""
                }
                viewModel.skillLevel = auth.defaultSkillLevel
                if viewModel.joinCode.isEmpty {
                    viewModel.joinCode = initialCode
                }
                isEditingCode = viewModel.joinCode.isEmpty
                if !isEditingCode {
                    Task { await viewModel.loadPreview() }
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                QRScannerSheet { code in
                    viewModel.joinCode = code
                    isEditingCode = false
                    Task { await viewModel.loadPreview() }
                }
            }
        }
    }
}

#Preview {
    JoinGameView(auth: AuthViewModel(), onJoined: { _ in })
}
