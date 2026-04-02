import ArgumentParser
import Foundation

/// Calls the Node/TS scraper in `../scraper` via `npm run scrape`.
struct ScrapeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scrape",
        abstract: "Scrape beer listings and write the resulting JSON to a file."
    )

    @Argument(help: "Output JSON file path (e.g. `../result.json`).")
    var outputPath: String

    @Flag(name: .customLong("html"), help: "Emit a live DOM HTML snapshot (for fixtures).")
    var emitHtml: Bool = false

    @Flag(name: .customLong("headful"), help: "Run the browser with a visible UI (sets HEADFUL=1).")
    var headful: Bool = false

    @Flag(name: .customLong("dry-run"), help: "Print the npm command that would run, then exit.")
    var dryRun: Bool = false

    mutating func run() async throws {
        guard let scraperDir = findUpwards(from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath), named: "scraper") else {
            throw ValidationError("Could not find a `scraper/` directory by walking up from the current directory.")
        }

        var npmArgs: [String] = ["run", "scrape", "--"]
        if emitHtml {
            npmArgs.append("--html")
        }
        npmArgs.append(outputPath)

        if dryRun {
            print("Would run in \(scraperDir.path):")
            print("  npm \(npmArgs.joined(separator: " "))")
            return
        }

        let env = processEnvironment()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["npm"] + npmArgs
        process.currentDirectoryURL = scraperDir
        process.environment = env
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ExitCodeError(code: Int(process.terminationStatus))
        }
    }

    private func processEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if headful {
            env["HEADFUL"] = "1"
        }
        return env
    }

    private func findUpwards(from startURL: URL, named dirName: String) -> URL? {
        var url = startURL
        for _ in 0..<10 {
            let candidate = url.appendingPathComponent(dirName, isDirectory: true)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            url = url.deletingLastPathComponent()
        }
        return nil
    }
}

private struct ExitCodeError: Error, CustomStringConvertible {
    let code: Int
    var description: String { "scraper exited with code \(code)" }
}

