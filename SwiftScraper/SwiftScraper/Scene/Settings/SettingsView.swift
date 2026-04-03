//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import Knit
import SwiftUI

// MARK: - Memory footprint

@MainActor struct SettingsView {

    @State var viewModel: SettingsViewModel
    @State private var confirmClearDatabase = false
}

// MARK: - Rendering

extension SettingsView: View {

    var body: some View {
        Form {
            Section {
                Text(
                    "The app is sandboxed and can only write to a folder you select here. Pick your repository’s tmp folder (or any folder you want HTML dumps in)."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                LabeledContent("Export folder") {
                    Text(viewModel.exportFolderDisplayPath)
                        .font(.caption)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Button("Choose folder…") {
                        viewModel.chooseExportFolder()
                    }
                    Button("Clear") {
                        viewModel.clearExportFolder()
                    }
                }

                if let message = viewModel.lastErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Text(
                    "Untappd"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                TextField("Client ID", text: $viewModel.untappdClientID)
                    .textContentType(.username)

                SecureField("Secret", text: $viewModel.untappdSecretID)
            } header: {
                Text("Untappd")
            }

            Section {
                Text(
                    "Removes every brewery, beer, price point, and supplier from the local database on this Mac. HTML export settings and files are not affected."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Button("Clear all database data…", role: .destructive) {
                    confirmClearDatabase = true
                }

                if let message = viewModel.clearDatabaseErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog(
            "Clear all database data?",
            isPresented: $confirmClearDatabase,
            titleVisibility: .visible
        ) {
            Button("Clear all data", role: .destructive) {
                viewModel.clearAllDatabaseData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 420, minHeight: 200)
    }
}

// MARK: - Previews

#Preview {
    let assembler = SwiftScraperAssembly.testing()
    SettingsView(viewModel: assembler.resolver.settingsViewModel())
}

