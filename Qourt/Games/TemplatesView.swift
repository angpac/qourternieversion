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
                ContentUnavailableView(
                    "No templates yet",
                    systemImage: "square.stack",
                    description: Text("Save a game's setup from its Game Summary screen after ending it.")
                )
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
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
