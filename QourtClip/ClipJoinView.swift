//
//  ClipJoinView.swift
//  QourtClip
//
//  Native twin of web/components/JoinForm.tsx.
//

import SwiftUI

struct ClipJoinView: View {
    @Bindable var viewModel: ClipViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case code, name }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                ClipCard {
                    VStack(alignment: .leading, spacing: 16) {
                        if !viewModel.isEditingCode {
                            Text("You scanned the code, just add your name below to join.")
                                .font(.subheadline)
                                .foregroundStyle(ClipTheme.zinc600)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }

                        codeSection
                        nameSection
                        skillSection

                        if let joinError = viewModel.joinError {
                            Text(joinError)
                                .font(.subheadline)
                                .foregroundStyle(ClipTheme.red600)
                        }

                        joinButton
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ClipTheme.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Qourt")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
            Text("Run the game. Not the whiteboard.")
                .font(.subheadline)
                .foregroundStyle(ClipTheme.emerald100)
        }
    }

    // MARK: - Code

    @ViewBuilder
    private var codeSection: some View {
        if viewModel.isEditingCode {
            VStack(alignment: .leading, spacing: 4) {
                Text("Join code")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ClipTheme.zinc700)
                TextField("6-character code", text: $viewModel.joinCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.title3, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(ClipTheme.zinc900)
                    .focused($focusedField, equals: .code)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ClipTheme.zinc300, lineWidth: 1)
                    )
                    .onChange(of: viewModel.joinCode) { _, new in
                        let upper = new.uppercased()
                        if upper != new { viewModel.joinCode = upper }
                    }
                    .onSubmit {
                        viewModel.isEditingCode = false
                        Task { await viewModel.loadPreview() }
                    }
            }
        } else if let previewError = viewModel.previewError {
            confirmationRow(
                borderColor: ClipTheme.red300,
                background: ClipTheme.red50,
                actionTitle: "Try another code"
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(previewError)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ClipTheme.red700)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(viewModel.joinCode)
                        .font(.system(.caption, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(ClipTheme.red600)
                }
            }
        } else {
            confirmationRow(
                borderColor: ClipTheme.emerald600,
                background: ClipTheme.emerald50,
                actionTitle: "Not this game?"
            ) {
                HStack(spacing: 12) {
                    // Never colour alone: the tick carries the same "this
                    // is settled" meaning as the green.
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(ClipTheme.emerald600, in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Joining")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ClipTheme.emerald700)
                        Text(viewModel.isLoadingPreview ? "…" : (viewModel.preview?.name ?? "game"))
                            .font(.title3.bold())
                            .foregroundStyle(ClipTheme.emerald900)
                        Text(viewModel.joinCode)
                            .font(.system(.caption, design: .monospaced))
                            .tracking(3)
                            .foregroundStyle(ClipTheme.emerald700)
                    }
                }
            }
        }
    }

    private func confirmationRow<Content: View>(
        borderColor: Color,
        background: Color,
        actionTitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            content()
            Spacer(minLength: 0)
            Button(actionTitle) {
                viewModel.isEditingCode = true
                viewModel.preview = nil
                viewModel.previewError = nil
                focusedField = .code
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(borderColor == ClipTheme.red300 ? ClipTheme.red700 : ClipTheme.emerald700)
            .underline()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 2))
    }

    // MARK: - Name and skill

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your name")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ClipTheme.zinc700)
            TextField("Name", text: $viewModel.name)
                .textContentType(.givenName)
                .foregroundStyle(ClipTheme.zinc900)
                .focused($focusedField, equals: .name)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ClipTheme.zinc300, lineWidth: 1)
                )
        }
    }

    private var skillSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Skill level")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ClipTheme.zinc700)
            Picker("Skill level", selection: $viewModel.skillLevel) {
                ForEach(ClipViewModel.skillLevels, id: \.self) { level in
                    Text(level).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var joinButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.join() }
        } label: {
            Text(viewModel.isJoining ? "Joining…" : "Join")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ClipTheme.emerald700, in: RoundedRectangle(cornerRadius: 8))
        }
        .disabled(viewModel.isJoining || (!viewModel.isEditingCode && viewModel.previewError != nil))
        .opacity(viewModel.isJoining || (!viewModel.isEditingCode && viewModel.previewError != nil) ? 0.5 : 1)
        .padding(.top, 4)
    }
}
