//  Created by Alexander Skorulis on 3/4/2026.

import AppKit
import Foundation
import Knit
import KnitMacros

@MainActor @Observable final class SettingsViewModel {

    private enum UserDefaultsKey {
        static let untappdClientID = "untappdClientID"
        static let untappdSecretID = "untappdSecretID"
    }

    private let htmlExportDirectory: HTMLExportDirectoryStore
    private let sqlStore: SQLStore

    var lastErrorMessage: String?
    var clearDatabaseErrorMessage: String?

    var untappdClientID: String {
        didSet { UserDefaults.standard.set(untappdClientID, forKey: UserDefaultsKey.untappdClientID) }
    }

    var untappdSecretID: String {
        didSet { UserDefaults.standard.set(untappdSecretID, forKey: UserDefaultsKey.untappdSecretID) }
    }

    var exportFolderDisplayPath: String {
        htmlExportDirectory.folderDisplaySummary
    }

    @Resolvable<Resolver>
    init(
        htmlExportDirectory: HTMLExportDirectoryStore,
        sqlStore: SQLStore,
    ) {
        self.htmlExportDirectory = htmlExportDirectory
        self.sqlStore = sqlStore
        untappdClientID = UserDefaults.standard.string(forKey: UserDefaultsKey.untappdClientID) ?? ""
        untappdSecretID = UserDefaults.standard.string(forKey: UserDefaultsKey.untappdSecretID) ?? ""
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
