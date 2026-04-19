//  Created by Alexander Skorulis on 3/4/2026.

import AppKit
import Foundation
import Knit
import KnitMacros

@MainActor @Observable final class SettingsViewModel {

    private let htmlExportDirectory: HTMLExportDirectoryStore
    private let sqlStore: SQLStore
    private let mainStore: MainStore

    var lastErrorMessage: String?
    var clearDatabaseErrorMessage: String?

    var untappdClientID: String {
        didSet { mainStore.settings.untappdClientID = untappdClientID }
    }

    var untappdSecretID: String {
        didSet { mainStore.settings.untappdSecretID = untappdSecretID }
    }

    var exportFolderDisplayPath: String {
        htmlExportDirectory.folderDisplaySummary
    }

    @Resolvable<Resolver>
    init(
        htmlExportDirectory: HTMLExportDirectoryStore,
        sqlStore: SQLStore,
        mainStore: MainStore,
    ) {
        self.htmlExportDirectory = htmlExportDirectory
        self.sqlStore = sqlStore
        self.mainStore = mainStore
        untappdClientID = mainStore.settings.untappdClientID ?? ""
        untappdSecretID = mainStore.settings.untappdSecretID ?? ""
    }

    func clearAllDatabaseData() {
        clearDatabaseErrorMessage = nil
        do {
            try sqlStore.clearAllUserData()
        } catch {
            clearDatabaseErrorMessage = error.localizedDescription
        }
    }

    func chooseExportFolder() {
        lastErrorMessage = nil
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose the folder where exported HTML should be saved (for example the tmp folder in your aus-beer checkout)."
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try htmlExportDirectory.setBookmark(from: url)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func clearExportFolder() {
        lastErrorMessage = nil
        htmlExportDirectory.clearBookmark()
    }
}
