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
                Section {
                    if isEditingCode {
                        TextField("6-character code", text: $viewModel.joinCode)
                            .font(.custom("DIN-Regular", size: 17))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button {
                            isShowingScanner = true
                        } label: {
                            Label("Scan QR code", systemImage: "qrcode.viewfinder")
                                .font(.custom("DIN-Medium", size: 15))
                                .foregroundStyle(Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255))
                        }
                    } else if let previewError = viewModel.previewError {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(previewError)
                                    .font(.custom("DIN-Medium", size: 15))
                                    .foregroundStyle(.red)
                                Text(viewModel.joinCode)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Try another code") {
                                isEditingCode = true
                            }
                            .font(.custom("DIN-Medium", size: 13))
                        }
                    } else {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Joining")
                                        .font(.custom("DIN-Regular", size: 13))
                                        .foregroundStyle(.secondary)
                                    Text(viewModel.isLoadingPreview ? "…" : (viewModel.previewGameName ?? "game"))
                                        .font(.custom("DIN-Medium", size: 20))
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
                            .font(.custom("DIN-Medium", size: 13))
                        }
                    }
                } header: {
                    Text("Join code")
                        .font(.custom("DIN-Regular", size: 13))
                }

                Section {
                    TextField("Name", text: $viewModel.displayName)
                        .font(.custom("DIN-Regular", size: 17))
                    HStack {
                        Text("Skill level")
                            .font(.custom("DIN-Regular", size: 17))
                        Spacer()
                        Text(viewModel.skillLevel)
                            .font(.custom("DIN-Regular", size: 17))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Your info")
                        .font(.custom("DIN-Regular", size: 13))
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.custom("DIN-Regular", size: 13))
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
                                .font(.custom("DIN-Medium", size: 16))
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
