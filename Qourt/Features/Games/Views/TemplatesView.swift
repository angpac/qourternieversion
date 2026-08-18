//
//  TemplatesView.swift
//  Qourt
//

import SwiftUI

struct TemplatesView: View {
    var onUseTemplate: (GameTemplate) -> Void

    @State private var viewModel: TemplatesViewModel
    private let skipsInitialLoad: Bool

    private let labelColor = Color.appSecondaryText

    init(onUseTemplate: @escaping (GameTemplate) -> Void, previewViewModel: TemplatesViewModel? = nil) {
        self.onUseTemplate = onUseTemplate
        _viewModel = State(initialValue: previewViewModel ?? TemplatesViewModel())
        skipsInitialLoad = previewViewModel != nil
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.templates.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.templates) { template in
                        Button {
                            onUseTemplate(template)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.custom("DIN-Medium", size: 17))
                                        .foregroundStyle(Color.primary)
                                    Text("\(template.numCourts) courts · \(template.format.title)")
                                        .font(.custom("DIN-Regular", size: 13))
                                        .foregroundStyle(labelColor)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(labelColor)
                            }
                            .padding()
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(template) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !skipsInitialLoad else { return }
            await viewModel.load()
        }
        .refreshable { await viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "square.stack")
                .font(.system(size: 100))
                .foregroundStyle(Color.primary)

            Text("No templates yet")
                .font(.custom("DIN-Regular", size: 36))
                .fontWeight(.bold)

            Text("Save a game's setup from its Game Summary after ending it.")
                .font(.custom("DIN-Regular", size: 18))
                .foregroundStyle(Color(red: 0x5F / 255, green: 0x4C / 255, blue: 0x00 / 255))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("With templates") {
    let vm = TemplatesViewModel()
    vm.isLoading = false
    vm.templates = [
        GameTemplate(id: UUID(), name: "Wednesday Sesh", numCourts: 4, isDoubles: true, requiresApproval: false, format: .kingOfTheCourt, formatSettings: [:]),
        GameTemplate(id: UUID(), name: "Weekend Ladder", numCourts: 6, isDoubles: false, requiresApproval: true, format: .pegBoard, formatSettings: [:])
    ]
    return NavigationStack {
        TemplatesView(onUseTemplate: { _ in }, previewViewModel: vm)
    }
}

#Preview("Empty") {
    let vm = TemplatesViewModel()
    vm.isLoading = false
    return NavigationStack {
        TemplatesView(onUseTemplate: { _ in }, previewViewModel: vm)
    }
}
