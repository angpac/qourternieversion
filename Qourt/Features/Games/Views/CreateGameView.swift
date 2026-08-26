//
//  CreateGameView.swift
//  Qourt
//

import SwiftUI

struct CreateGameView: View {
    @Bindable var viewModel: CreateGameViewModel
    var auth: AuthViewModel
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingTimePicker = false

    var body: some View {
        Form {
            Section("Game details") {
                TextField("Name", text: $viewModel.name)
                TextField("Location", text: $viewModel.location)
                DatePicker("Date", selection: $viewModel.startsAt, displayedComponents: [.date])
                timeRow
            }

            if !viewModel.availableClubs.isEmpty {
                Section {
                    Picker("Club", selection: $viewModel.selectedClubId) {
                        Text("None").tag(UUID?.none)
                        ForEach(viewModel.availableClubs) { club in
                            Text(club.name).tag(Optional(club.id))
                        }
                    }
                } footer: {
                    Text("Linking this game to a club means every club admin can manage it too, and it shares the club's roster going forward.")
                }
            }

            Section {
                Stepper("Number of courts: \(viewModel.numCourts)", value: $viewModel.numCourts, in: 1...20)
                if viewModel.format.isTournament {
                    LabeledContent("Format", value: "Singles")
                } else {
                    Picker("Format", selection: $viewModel.formatMode) {
                        ForEach(GameFormatMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                if viewModel.formatMode == .mixed && !viewModel.format.isTournament {
                    ForEach(0..<viewModel.numCourts, id: \.self) { index in
                        Picker("Court \(index + 1)", selection: courtSinglesBinding(index)) {
                            Text("Doubles").tag(false)
                            Text("Singles").tag(true)
                        }
                    }
                }
            } footer: {
                if viewModel.format.isTournament {
                    Text("Tournament brackets are singles-only for now.")
                } else if viewModel.formatMode == .mixed {
                    Text("Set each court's format below — handy for a session where most courts are doubles but one's set aside for stronger singles players (or the other way around).")
                }
            }

            Section {
                Toggle("Require approval to join", isOn: $viewModel.requiresApproval)
            } footer: {
                Text("New joiners wait for you to approve them from the Roster before they're added to the queue.")
            }

            Section("Rotation format") {
                // A plain, eager VStack/HStack grid rather than LazyVGrid —
                // only 8 fixed cards, no benefit from lazy layout, and
                // LazyVGrid nested inside a Form/List is a known source of
                // blank-render glitches on push navigation (the destination
                // Form would sometimes render with zero rows until the user
                // backed out and re-entered).
                VStack(spacing: 12) {
                    ForEach(Array(RotationFormat.allCases.chunked(into: 2)), id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row) { format in
                                let isSelected = viewModel.format == format
                                Button {
                                    viewModel.format = format
                                    if format.isTournament {
                                        viewModel.isDoubles = false
                                        viewModel.formatMode = .singles
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Image(systemName: format.systemImage)
                                            .font(.subheadline)
                                        Text(format.title)
                                            .font(.subheadline.bold())
                                        Text(format.subtitle)
                                            .font(.caption)
                                    }
                                    .foregroundStyle(isSelected ? .white : Color.appSecondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255))
                                        } else if format == .challengeCourt {
                                            // The only format with a special court once the
                                            // game is live — the same diagonal stripe flags
                                            // it here too, so the picker previews what's
                                            // coming rather than looking identical to the
                                            // other seven formats until you're already in.
                                            ChallengeCourtStripeBackground(
                                                baseColor: .white,
                                                stripeColor: Color(red: 0xB8 / 255, green: 0x8A / 255, blue: 0x2B / 255).opacity(0.18)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        } else {
                                            RoundedRectangle(cornerRadius: 12).fill(Color.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            if row.count < 2 {
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.horizontal)
            }

            Section {
                NavigationLink {
                    RotationFormatSettingsView(viewModel: viewModel, auth: auth, onFinished: onFinished)
                } label: {
                    Text("Continue")
                }
                .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Create a game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .task {
            if let userID = auth.userID {
                await viewModel.loadAvailableClubs(ownerID: userID)
            }
        }
    }

    /// A compact row matching Date's look — tap to reveal the picker,
    /// same as the calendar does — rather than the wheel sitting inline
    /// and always expanded. The popover's own presentation already works
    /// fine with a Magic Keyboard trackpad (same mechanism the Date field
    /// uses); what was actually broken was the compact style's built-in
    /// hour/minute editor, so wheel style — inside a popover we control —
    /// replaces just that.
    private var timeRow: some View {
        Button {
            isShowingTimePicker = true
        } label: {
            HStack {
                Text("Time")
                    .foregroundStyle(Color.primary)
                Spacer()
                Text(viewModel.startsAt, style: .time)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingTimePicker) {
            DatePicker(
                "Time",
                selection: $viewModel.startsAt,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }

    private func courtSinglesBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { viewModel.courtSinglesOverrides[index] ?? !viewModel.isDoubles },
            set: { viewModel.courtSinglesOverrides[index] = $0 }
        )
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    NavigationStack {
        CreateGameView(viewModel: CreateGameViewModel(), auth: AuthViewModel(), onFinished: {})
    }
}
