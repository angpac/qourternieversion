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
                dateAndTimeRow
                if isShowingTimePicker {
                    timeWheel
                }
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

    /// One row, "Date & time", with the date and time pills side by side —
    /// the original look, before this got split into two stacked rows to
    /// chase a trackpad bug. The date pill is the untouched native
    /// DatePicker, which was never the problem. The time pill is a plain
    /// button that expands `timeWheel` as the *next row in the Form*, not
    /// a `.popover` — `.popover`'s arrowEdge turned out to be unreliable
    /// here (verified on-device: neither .top nor .bottom stopped it from
    /// opening upward over Name/Location), where an ordinary Form row can
    /// only ever land below, exactly like the date pill's own calendar
    /// pushes the rows under it down instead of floating over them.
    private var dateAndTimeRow: some View {
        HStack {
            Text("Date & time")
            Spacer()
            DatePicker("", selection: $viewModel.startsAt, displayedComponents: [.date])
                .labelsHidden()
            timePill
        }
    }

    private var timePill: some View {
        Button {
            withAnimation { isShowingTimePicker.toggle() }
        } label: {
            Text(viewModel.startsAt, style: .time)
                // Matches the date pill's own active-state color, which
                // turns its accent green while its calendar is open.
                .foregroundStyle(
                    isShowingTimePicker
                        ? Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)
                        : Color.primary
                )
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Scaled down from the wheel's native size, which otherwise renders
    /// noticeably larger/bolder than the date calendar's own day-number
    /// type — the scale is applied before the frame that then clips to
    /// it, so the row's height shrinks along with the visual rather than
    /// leaving the wheel's original, now-empty space around it.
    private var timeWheel: some View {
        DatePicker(
            "Time",
            selection: $viewModel.startsAt,
            displayedComponents: [.hourAndMinute]
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .scaleEffect(0.82)
        .frame(height: 130)
        .frame(maxWidth: .infinity)
        .clipped()
        .listRowInsets(EdgeInsets())
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
