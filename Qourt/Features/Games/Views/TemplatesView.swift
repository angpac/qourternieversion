//
//  TemplatesView.swift
//  Qourt
//

import SwiftUI

struct TemplatesView: View {
    var onUseTemplate: (GameTemplate) -> Void

    @State private var viewModel = TemplatesViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
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
                                        .foregroundStyle(.primary)
                                    Text("\(template.numCourts) courts · \(template.format.title)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                await viewModel.delete(viewModel.templates[index])
                            }
                        }
                    }
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "square.stack")
                .font(.system(size: 140))
                .foregroundStyle(Color(.black))

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

#Preview {
    NavigationStack {
        TemplatesView(onUseTemplate: { _ in })
    }
}
