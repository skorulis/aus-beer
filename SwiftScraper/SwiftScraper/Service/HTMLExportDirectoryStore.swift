//  Created by Alexander Skorulis on 3/4/2026.

import Foundation

enum HTMLExportDirectoryError: Error, LocalizedError {
    case noFolderConfigured
    case bookmarkStale

    var errorDescription: String? {
        switch self {
        case .noFolderConfigured:
            "No export folder selected. Choose your tmp folder in Settings."
        case .bookmarkStale:
            "Saved folder access expired. Choose the folder again in Settings."
        }
    }
}

/// Persists a security-scoped bookmark so the sandboxed app can write HTML exports to a user-chosen directory.
@MainActor
@Observable
final class HTMLExportDirectoryStore {

    private static let bookmarkUserDefaultsKey = "htmlExportDirectorySecurityScopedBookmark"

    private var bookmarkData: Data? {
        didSet {
            if let bookmarkData {
                UserDefaults.standard.set(bookmarkData, forKey: Self.bookmarkUserDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.bookmarkUserDefaultsKey)
            }
        }
    }

    init() {
        bookmarkData = UserDefaults.standard.data(forKey: Self.bookmarkUserDefaultsKey)
    }

    var folderDisplaySummary: String {
        guard let bookmarkData else {
            return "No folder selected"
        }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if stale {
                return "Access expired — choose the folder again"
            }
            return url.path
        } catch {
            return "Could not read saved folder"
        }
    }

    func setBookmark(from url: URL) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        bookmarkData = data
    }

    func clearBookmark() {
        bookmarkData = nil
    }

    func performWithAccess<R>(_ body: (URL) throws -> R) throws -> R {
        guard let bookmarkData else {
            throw HTMLExportDirectoryError.noFolderConfigured
        }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale {
            throw HTMLExportDirectoryError.bookmarkStale
        }
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body(url)
    }
}
