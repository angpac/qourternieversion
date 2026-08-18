//
//  ManageCourtsView.swift
//  Qourt
//

import SwiftUI

struct ManageCourtsView: View {
    var viewModel: LiveDashboardViewModel

    @State private var sortedCourts: [Court] = []
    @State private var courtToRename: Court?
    @State private var renameText = ""

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    var body: some View {
        List {
            Section {
                ForEach(sortedCourts) { court in
                    Button {
                        courtToRename = court
                        renameText = court.name
                    } label: {
                        courtRow(court)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .onMove(perform: viewModel.canReorderCourts ? move : nil)
            } footer: {
                if !viewModel.canReorderCourts {
                    if viewModel.isKingOfTheCourt {
                        Text("Reordering is only available between rounds, so it can't scramble a ladder that's mid-round.")
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(labelColor)
                    } else {
                        Text("This format's courts can't be manually reordered.")
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(labelColor)
                    }
                } else if viewModel.isKingOfTheCourt {
                    Text("Order matters here: the bottom court is where the ladder starts, the top court is the King's Court.")
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(labelColor)
                }
            }

            Section {
                ForEach(sortedCourts.filter { !$0.isLaneSplit }) { court in
                    HStack {
                        Text(court.name)
                            .font(.custom("DIN-Regular", size: 17))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Menu {
                            Button("Game default (\(viewModel.game.isDoubles ? "Doubles" : "Singles"))") {
                                Task { await viewModel.setCourtFormat(court, singlesOverride: nil) }
                            }
                            Button("Singles") {
                                Task { await viewModel.setCourtFormat(court, singlesOverride: true) }
                            }
                            Button("Doubles") {
                                Task { await viewModel.setCourtFormat(court, singlesOverride: false) }
                            }
                        } label: {
                            Text(formatLabel(for: court))
                                .font(.custom("DIN-Medium", size: 13))
                                .foregroundStyle(Color.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5), in: Capsule())
                        }
                    }
                    .padding()
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            } header: {
                Text("Court format")
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
            } footer: {
                Text("Run a mixed session — most courts doubles, one set aside for singles (or the other way around).")
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Courts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canReorderCourts {
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                        .tint(accentColor)
                }
            }
        }
        .onAppear {
            sortedCourts = viewModel.courts.sorted { $0.position < $1.position }
        }
        .onChange(of: viewModel.courts) { _, newValue in
            sortedCourts = newValue.sorted { $0.position < $1.position }
        }
        .alert("Rename court", isPresented: .constant(courtToRename != nil)) {
            TextField("Court name", text: $renameText)
            Button("Cancel", role: .cancel) { courtToRename = nil }
            Button("Save") {
                if let court = courtToRename {
                    Task { await viewModel.renameCourt(court, to: renameText) }
                }
                courtToRename = nil
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        sortedCourts.move(fromOffsets: source, toOffset: destination)
        Task { await viewModel.reorderCourts(sortedCourts) }
    }

    private func formatLabel(for court: Court) -> String {
        guard let override = court.singlesOverride else { return "Default" }
        return override ? "Singles" : "Doubles"
    }

    @ViewBuilder
    private func courtRow(_ court: Court) -> some View {
        HStack {
            Text(court.name)
                .font(.custom("DIN-Medium", size: 17))
                .foregroundStyle(Color.primary)
            if court.isChallengeCourt {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.custom("DIN-Regular", size: 13))
            }
            Spacer()
            Image(systemName: "pencil")
                .font(.custom("DIN-Regular", size: 13))
                .foregroundStyle(accentColor)
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        ManageCourtsView(viewModel: LiveDashboardViewModel(game: Game(
            id: UUID(),
            name: "Sunday Open Play",
            location: "Community Center",
            startsAt: Date(),
            numCourts: 4,
            isDoubles: true,
            format: .kingOfTheCourt,
            formatSettings: [:],
            joinCode: "7K2P9Q",
            status: "draft"
        )))
    }
}
