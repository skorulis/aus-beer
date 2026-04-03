//  Created by Alexander Skorulis on 3/4/2026.

import Foundation
import Knit
import SwiftUI

// MARK: - Memory footprint

@MainActor struct SettingsView {

    @State var viewModel: SettingsViewModel
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

